-- ========================================
-- Event Store - Tables Creation
-- ========================================
-- Purpose: Store domain events for event sourcing and audit trail
-- All bounded contexts publish events here

-- Domain Events Table
CREATE TABLE events.domain_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(255) NOT NULL,           -- e.g., 'ProductCreated', 'OrderPlaced'
    event_version VARCHAR(10) NOT NULL DEFAULT '1.0',
    aggregate_id UUID NOT NULL,                 -- ID of the aggregate that generated the event
    aggregate_type VARCHAR(100) NOT NULL,       -- e.g., 'Product', 'Order', 'User'
    aggregate_version INTEGER NOT NULL DEFAULT 1, -- Version of the aggregate
    event_data JSONB NOT NULL,                  -- Event payload in JSON format
    metadata JSONB,                             -- Additional metadata (user_id, correlation_id, etc.)
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,                     -- When the event was published to message broker
    published BOOLEAN DEFAULT FALSE,
    sequence_number BIGSERIAL,                  -- Global ordering of events
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Event Subscriptions (for tracking which contexts have processed which events)
CREATE TABLE events.event_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_name VARCHAR(100) NOT NULL,      -- e.g., 'order-context', 'notification-context'
    event_type VARCHAR(255) NOT NULL,
    last_processed_sequence BIGINT NOT NULL DEFAULT 0,
    last_processed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_subscription_subscriber_event UNIQUE (subscriber_name, event_type)
);

-- Event Processing Log (for idempotency and error tracking)
CREATE TABLE events.event_processing_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events.domain_events(id),
    subscriber_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PROCESSING', 'COMPLETED', 'FAILED', 'RETRY')),
    attempts INTEGER DEFAULT 1,
    error_message TEXT,
    processed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_event_processing UNIQUE (event_id, subscriber_name)
);

-- Snapshots Table (for event sourcing optimization)
CREATE TABLE events.aggregate_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_version INTEGER NOT NULL,
    snapshot_data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_snapshot_aggregate_version UNIQUE (aggregate_id, aggregate_type, aggregate_version)
);

-- Indexes for performance
CREATE INDEX idx_domain_events_aggregate ON events.domain_events(aggregate_id, aggregate_type);
CREATE INDEX idx_domain_events_type ON events.domain_events(event_type);
CREATE INDEX idx_domain_events_occurred ON events.domain_events(occurred_at DESC);
CREATE INDEX idx_domain_events_sequence ON events.domain_events(sequence_number);
CREATE INDEX idx_domain_events_unpublished ON events.domain_events(published) WHERE published = FALSE;
CREATE INDEX idx_domain_events_aggregate_version ON events.domain_events(aggregate_id, aggregate_type, aggregate_version);

CREATE INDEX idx_event_subscriptions_subscriber ON events.event_subscriptions(subscriber_name);
CREATE INDEX idx_event_processing_log_event ON events.event_processing_log(event_id);
CREATE INDEX idx_event_processing_log_subscriber ON events.event_processing_log(subscriber_name);
CREATE INDEX idx_event_processing_log_status ON events.event_processing_log(status) WHERE status IN ('PROCESSING', 'FAILED', 'RETRY');

CREATE INDEX idx_snapshots_aggregate ON events.aggregate_snapshots(aggregate_id, aggregate_type);
CREATE INDEX idx_snapshots_version ON events.aggregate_snapshots(aggregate_id, aggregate_type, aggregate_version DESC);

-- Full-text search on event data
CREATE INDEX idx_domain_events_data_search ON events.domain_events USING gin(event_data);

-- Comments for documentation
COMMENT ON TABLE events.domain_events IS 'Domain events from all bounded contexts - Event Store';
COMMENT ON TABLE events.event_subscriptions IS 'Tracks which subscribers have processed which events';
COMMENT ON TABLE events.event_processing_log IS 'Log of event processing attempts for debugging and idempotency';
COMMENT ON TABLE events.aggregate_snapshots IS 'Snapshots of aggregate state for event sourcing optimization';

COMMENT ON COLUMN events.domain_events.event_type IS 'Type of event (e.g., ProductCreated, OrderPlaced)';
COMMENT ON COLUMN events.domain_events.event_data IS 'Event payload in JSON format';
COMMENT ON COLUMN events.domain_events.metadata IS 'Additional context (user_id, correlation_id, causation_id, etc.)';
COMMENT ON COLUMN events.domain_events.sequence_number IS 'Global ordering of all events';
COMMENT ON COLUMN events.event_subscriptions.last_processed_sequence IS 'Last sequence number processed by this subscriber';

-- Trigger for updated_at
CREATE TRIGGER update_event_subscriptions_updated_at
    BEFORE UPDATE ON events.event_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

CREATE TRIGGER update_event_processing_log_updated_at
    BEFORE UPDATE ON events.event_processing_log
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

-- Function to get events for an aggregate (for event sourcing)
CREATE OR REPLACE FUNCTION events.get_aggregate_events(
    p_aggregate_id UUID,
    p_aggregate_type VARCHAR(100),
    p_from_version INTEGER DEFAULT 0
)
RETURNS SETOF events.domain_events AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM events.domain_events
    WHERE aggregate_id = p_aggregate_id
      AND aggregate_type = p_aggregate_type
      AND aggregate_version > p_from_version
    ORDER BY aggregate_version ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get latest snapshot for an aggregate
CREATE OR REPLACE FUNCTION events.get_latest_snapshot(
    p_aggregate_id UUID,
    p_aggregate_type VARCHAR(100)
)
RETURNS events.aggregate_snapshots AS $$
DECLARE
    snapshot events.aggregate_snapshots;
BEGIN
    SELECT *
    INTO snapshot
    FROM events.aggregate_snapshots
    WHERE aggregate_id = p_aggregate_id
      AND aggregate_type = p_aggregate_type
    ORDER BY aggregate_version DESC
    LIMIT 1;

    RETURN snapshot;
END;
$$ LANGUAGE plpgsql;

-- Function to mark events as published
CREATE OR REPLACE FUNCTION events.mark_events_as_published(event_ids UUID[])
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE events.domain_events
    SET published = TRUE,
        published_at = CURRENT_TIMESTAMP
    WHERE id = ANY(event_ids)
      AND published = FALSE;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get new events for a subscriber
CREATE OR REPLACE FUNCTION events.get_new_events_for_subscriber(
    p_subscriber_name VARCHAR(100),
    p_event_type VARCHAR(255),
    p_limit INTEGER DEFAULT 100
)
RETURNS SETOF events.domain_events AS $$
DECLARE
    last_processed_seq BIGINT;
BEGIN
    -- Get last processed sequence for this subscriber and event type
    SELECT last_processed_sequence
    INTO last_processed_seq
    FROM events.event_subscriptions
    WHERE subscriber_name = p_subscriber_name
      AND event_type = p_event_type;

    -- If no subscription exists, start from the beginning
    IF NOT FOUND THEN
        last_processed_seq := 0;
    END IF;

    -- Return new events
    RETURN QUERY
    SELECT *
    FROM events.domain_events
    WHERE event_type = p_event_type
      AND sequence_number > last_processed_seq
    ORDER BY sequence_number ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to update subscription progress
CREATE OR REPLACE FUNCTION events.update_subscription_progress(
    p_subscriber_name VARCHAR(100),
    p_event_type VARCHAR(255),
    p_sequence_number BIGINT
)
RETURNS void AS $$
BEGIN
    INSERT INTO events.event_subscriptions (subscriber_name, event_type, last_processed_sequence, last_processed_at)
    VALUES (p_subscriber_name, p_event_type, p_sequence_number, CURRENT_TIMESTAMP)
    ON CONFLICT (subscriber_name, event_type)
    DO UPDATE SET
        last_processed_sequence = EXCLUDED.last_processed_sequence,
        last_processed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to clean old events (for data retention)
CREATE OR REPLACE FUNCTION events.archive_old_events(
    p_retention_days INTEGER DEFAULT 90
)
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- Move old events to archive table (if you want to keep them)
    -- Or simply delete them if not needed

    DELETE FROM events.domain_events
    WHERE occurred_at < CURRENT_TIMESTAMP - (p_retention_days || ' days')::INTERVAL
      AND published = TRUE;

    GET DIAGNOSTICS archived_count = ROW_COUNT;
    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;
