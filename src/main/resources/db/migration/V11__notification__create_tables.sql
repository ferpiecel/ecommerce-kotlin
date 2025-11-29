-- ========================================
-- Notification Context - Tables Creation
-- ========================================
-- Bounded Context: Notification
-- Aggregates: Notification, NotificationTemplate
-- Purpose: User notifications, alerts, and communication

-- Notification Templates Table
CREATE TABLE notification.notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,

    -- Template content
    notification_type VARCHAR(30) NOT NULL
        CHECK (notification_type IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP')),
    subject VARCHAR(200), -- For email
    body_template TEXT NOT NULL, -- Template with variables like {{user.name}}
    html_template TEXT, -- For email HTML version

    -- Metadata
    category VARCHAR(50) CHECK (category IN ('TRANSACTIONAL', 'MARKETING', 'SYSTEM', 'ALERT')),
    language VARCHAR(5) DEFAULT 'en',
    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Notifications Table (Aggregate Root)
CREATE TABLE notification.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Reference to identity.users
    template_id UUID REFERENCES notification.notification_templates(id),

    -- Notification details
    notification_type VARCHAR(30) NOT NULL
        CHECK (notification_type IN ('EMAIL', 'SMS', 'PUSH', 'IN_APP')),
    channel VARCHAR(30) CHECK (channel IN ('EMAIL', 'SMS', 'PUSH_NOTIFICATION', 'IN_APP_NOTIFICATION', 'WEBHOOK')),

    -- Content (rendered from template)
    subject VARCHAR(200),
    body TEXT NOT NULL,
    html_body TEXT,

    -- Recipient details
    recipient_email VARCHAR(100),
    recipient_phone VARCHAR(20),
    recipient_device_token VARCHAR(500), -- For push notifications

    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED', 'CLICKED', 'OPENED')),
    priority VARCHAR(20) DEFAULT 'NORMAL' CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),

    -- Delivery tracking
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    failed_at TIMESTAMP,
    failure_reason TEXT,

    -- Provider details
    provider VARCHAR(50), -- SendGrid, Twilio, Firebase, etc.
    provider_message_id VARCHAR(200),
    provider_response JSONB,

    -- Metadata
    category VARCHAR(50),
    related_entity_type VARCHAR(50), -- ORDER, SHIPMENT, PAYMENT, etc.
    related_entity_id UUID,
    variables JSONB, -- Variables used in template rendering

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Notification Preferences Table (user preferences)
CREATE TABLE notification.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE, -- Reference to identity.users

    -- Email preferences
    email_enabled BOOLEAN DEFAULT TRUE,
    email_order_updates BOOLEAN DEFAULT TRUE,
    email_shipping_updates BOOLEAN DEFAULT TRUE,
    email_promotional BOOLEAN DEFAULT TRUE,
    email_newsletter BOOLEAN DEFAULT FALSE,

    -- SMS preferences
    sms_enabled BOOLEAN DEFAULT FALSE,
    sms_order_updates BOOLEAN DEFAULT FALSE,
    sms_shipping_updates BOOLEAN DEFAULT FALSE,
    sms_promotional BOOLEAN DEFAULT FALSE,

    -- Push notification preferences
    push_enabled BOOLEAN DEFAULT TRUE,
    push_order_updates BOOLEAN DEFAULT TRUE,
    push_shipping_updates BOOLEAN DEFAULT TRUE,
    push_promotional BOOLEAN DEFAULT FALSE,
    push_cart_abandonment BOOLEAN DEFAULT TRUE,

    -- In-app notification preferences
    in_app_enabled BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- User Devices Table (for push notifications)
CREATE TABLE notification.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Reference to identity.users
    device_token VARCHAR(500) NOT NULL,
    device_type VARCHAR(20) CHECK (device_type IN ('IOS', 'ANDROID', 'WEB')),
    device_name VARCHAR(100),
    app_version VARCHAR(20),
    os_version VARCHAR(20),

    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_device_token UNIQUE (device_token)
);

-- Notification Events Table (tracking user interactions)
CREATE TABLE notification.notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notification.notifications(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN ('SENT', 'DELIVERED', 'OPENED', 'CLICKED', 'BOUNCED', 'COMPLAINED')),
    event_data JSONB,
    ip_address INET,
    user_agent TEXT,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Notification Batches Table (for bulk sending)
CREATE TABLE notification.notification_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_name VARCHAR(150) NOT NULL,
    template_id UUID REFERENCES notification.notification_templates(id),
    notification_type VARCHAR(30) NOT NULL,

    -- Targeting
    user_segment JSONB, -- Criteria for selecting users
    total_recipients INTEGER DEFAULT 0,
    sent_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,

    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),

    -- Scheduling
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,

    created_by UUID, -- Reference to identity.users
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_notification_templates_code ON notification.notification_templates(template_code);
CREATE INDEX idx_notification_templates_type ON notification.notification_templates(notification_type);
CREATE INDEX idx_notification_templates_active ON notification.notification_templates(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_notifications_user ON notification.notifications(user_id);
CREATE INDEX idx_notifications_template ON notification.notifications(template_id);
CREATE INDEX idx_notifications_type ON notification.notifications(notification_type);
CREATE INDEX idx_notifications_status ON notification.notifications(status);
CREATE INDEX idx_notifications_created ON notification.notifications(created_at DESC);
CREATE INDEX idx_notifications_sent ON notification.notifications(sent_at DESC) WHERE sent_at IS NOT NULL;
CREATE INDEX idx_notifications_related_entity ON notification.notifications(related_entity_type, related_entity_id);
CREATE INDEX idx_notifications_pending ON notification.notifications(status, priority) WHERE status = 'PENDING';

CREATE INDEX idx_notification_preferences_user ON notification.notification_preferences(user_id);

CREATE INDEX idx_user_devices_user ON notification.user_devices(user_id);
CREATE INDEX idx_user_devices_token ON notification.user_devices(device_token);
CREATE INDEX idx_user_devices_active ON notification.user_devices(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_notification_events_notification ON notification.notification_events(notification_id);
CREATE INDEX idx_notification_events_type ON notification.notification_events(event_type);
CREATE INDEX idx_notification_events_occurred ON notification.notification_events(occurred_at DESC);

CREATE INDEX idx_notification_batches_status ON notification.notification_batches(status);
CREATE INDEX idx_notification_batches_scheduled ON notification.notification_batches(scheduled_at) WHERE scheduled_at IS NOT NULL;

-- Comments for documentation
COMMENT ON TABLE notification.notification_templates IS 'Notification templates for various communication types';
COMMENT ON TABLE notification.notifications IS 'Notifications sent to users - Aggregate Root';
COMMENT ON TABLE notification.notification_preferences IS 'User notification preferences';
COMMENT ON TABLE notification.user_devices IS 'User devices for push notifications';
COMMENT ON TABLE notification.notification_events IS 'Notification delivery and interaction events';
COMMENT ON TABLE notification.notification_batches IS 'Batch notification campaigns';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION notification.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_notification_templates_updated_at
    BEFORE UPDATE ON notification.notification_templates
    FOR EACH ROW
    EXECUTE FUNCTION notification.update_updated_at_column();

CREATE TRIGGER update_notifications_updated_at
    BEFORE UPDATE ON notification.notifications
    FOR EACH ROW
    EXECUTE FUNCTION notification.update_updated_at_column();

CREATE TRIGGER update_notification_preferences_updated_at
    BEFORE UPDATE ON notification.notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION notification.update_updated_at_column();

CREATE TRIGGER update_user_devices_updated_at
    BEFORE UPDATE ON notification.user_devices
    FOR EACH ROW
    EXECUTE FUNCTION notification.update_updated_at_column();

-- Function to track notification status changes
CREATE OR REPLACE FUNCTION notification.track_notification_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
        -- Update timestamp fields based on new status
        IF NEW.status = 'SENT' THEN
            NEW.sent_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'DELIVERED' THEN
            NEW.delivered_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'OPENED' THEN
            NEW.opened_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'CLICKED' THEN
            NEW.clicked_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'FAILED' OR NEW.status = 'BOUNCED' THEN
            NEW.failed_at = CURRENT_TIMESTAMP;
        END IF;

        -- Create an event for the status change
        INSERT INTO notification.notification_events (
            notification_id,
            event_type,
            occurred_at
        ) VALUES (
            NEW.id,
            NEW.status,
            CURRENT_TIMESTAMP
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track status changes
CREATE TRIGGER track_notification_status_change_trigger
    BEFORE UPDATE ON notification.notifications
    FOR EACH ROW
    EXECUTE FUNCTION notification.track_notification_status_change();

-- Function to create default notification preferences for new users
CREATE OR REPLACE FUNCTION notification.create_default_preferences(p_user_id UUID)
RETURNS void AS $$
BEGIN
    INSERT INTO notification.notification_preferences (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;
