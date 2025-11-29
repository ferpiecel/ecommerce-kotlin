-- ========================================
-- Audit Context - Tables Creation
-- ========================================
-- Bounded Context: Audit
-- Aggregates: AuditLog
-- Purpose: Audit logging and activity tracking across all contexts

-- Audit Logs Table (Aggregate Root)
CREATE TABLE audit.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Entity information
    entity_type VARCHAR(100) NOT NULL, -- ORDER, PRODUCT, USER, PAYMENT, etc.
    entity_id UUID NOT NULL,
    aggregate_type VARCHAR(100), -- Bounded context name

    -- Action details
    action VARCHAR(50) NOT NULL, -- CREATE, UPDATE, DELETE, LOGIN, LOGOUT, etc.
    action_category VARCHAR(30) CHECK (action_category IN ('DATA_CHANGE', 'SECURITY', 'SYSTEM', 'BUSINESS')),

    -- Actor information
    actor_id UUID, -- Reference to identity.users
    actor_type VARCHAR(30) CHECK (actor_type IN ('USER', 'ADMIN', 'SYSTEM', 'API', 'SERVICE')),
    actor_name VARCHAR(100),
    actor_email VARCHAR(100),

    -- Change details
    old_values JSONB, -- Previous state
    new_values JSONB, -- New state
    changes JSONB, -- Specific fields that changed with before/after

    -- Context
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100), -- Correlation ID for distributed tracing
    session_id VARCHAR(100),

    -- Metadata
    reason TEXT, -- Why the action was taken
    description TEXT,
    tags VARCHAR(50)[], -- Array of tags for categorization
    severity VARCHAR(20) CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),

    -- Timestamps
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Security Audit Logs Table (specific for security events)
CREATE TABLE audit.security_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    event_type VARCHAR(50) NOT NULL
        CHECK (event_type IN (
            'LOGIN_SUCCESS', 'LOGIN_FAILED', 'LOGOUT',
            'PASSWORD_CHANGE', 'PASSWORD_RESET', 'EMAIL_VERIFICATION',
            'MFA_ENABLED', 'MFA_DISABLED', 'MFA_VERIFIED',
            'PERMISSION_CHANGE', 'ROLE_CHANGE',
            'ACCOUNT_LOCKED', 'ACCOUNT_UNLOCKED',
            'SUSPICIOUS_ACTIVITY', 'FRAUD_DETECTED'
        )),

    -- User information
    user_id UUID, -- Reference to identity.users
    username VARCHAR(100),
    email VARCHAR(100),

    -- Security details
    ip_address INET,
    user_agent TEXT,
    location_country VARCHAR(2),
    location_city VARCHAR(100),
    is_suspicious BOOLEAN DEFAULT FALSE,
    risk_score NUMERIC(5, 2) CHECK (risk_score >= 0 AND risk_score <= 100),

    -- Authentication details
    auth_method VARCHAR(30), -- PASSWORD, OAUTH, MFA, API_KEY, etc.
    auth_provider VARCHAR(50), -- GOOGLE, FACEBOOK, INTERNAL, etc.

    -- Session information
    session_id VARCHAR(100),
    device_fingerprint VARCHAR(200),

    -- Metadata
    failure_reason TEXT,
    details JSONB,

    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Data Access Logs Table (for GDPR compliance and privacy)
CREATE TABLE audit.data_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Data access details
    access_type VARCHAR(30) NOT NULL CHECK (access_type IN ('READ', 'EXPORT', 'DELETE', 'ANONYMIZE')),
    data_type VARCHAR(50) NOT NULL, -- PERSONAL_DATA, FINANCIAL_DATA, HEALTH_DATA, etc.
    data_classification VARCHAR(20) CHECK (data_classification IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED')),

    -- Subject information (whose data was accessed)
    subject_user_id UUID NOT NULL, -- Reference to identity.users
    subject_email VARCHAR(100),

    -- Actor information (who accessed the data)
    accessor_user_id UUID, -- Reference to identity.users
    accessor_type VARCHAR(30) CHECK (accessor_type IN ('USER', 'ADMIN', 'SYSTEM', 'API', 'SUPPORT')),
    accessor_email VARCHAR(100),

    -- Access context
    purpose TEXT, -- Why the data was accessed
    legal_basis VARCHAR(50), -- CONSENT, CONTRACT, LEGAL_OBLIGATION, LEGITIMATE_INTEREST, etc.
    retention_period VARCHAR(50),

    -- Technical details
    query_details JSONB,
    records_count INTEGER,
    ip_address INET,

    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- System Activity Logs Table (for system events and monitoring)
CREATE TABLE audit.system_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Event details
    event_type VARCHAR(50) NOT NULL, -- SERVICE_START, SERVICE_STOP, DEPLOYMENT, MIGRATION, etc.
    service_name VARCHAR(100),
    component VARCHAR(100),

    -- Severity and status
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    status VARCHAR(20) CHECK (status IN ('SUCCESS', 'FAILURE', 'IN_PROGRESS')),

    -- Event details
    message TEXT,
    error_message TEXT,
    stack_trace TEXT,
    event_data JSONB,

    -- Metrics
    duration_ms INTEGER, -- Execution time in milliseconds
    memory_usage_mb INTEGER,
    cpu_usage_percent NUMERIC(5, 2),

    -- Context
    request_id VARCHAR(100),
    correlation_id VARCHAR(100),
    trace_id VARCHAR(100),

    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Compliance Audit Trail Table (for regulatory compliance)
CREATE TABLE audit.compliance_audit_trail (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Compliance requirement
    regulation VARCHAR(50) NOT NULL, -- GDPR, PCI_DSS, HIPAA, SOX, etc.
    requirement_id VARCHAR(100),
    requirement_description TEXT,

    -- Action details
    action_type VARCHAR(50) NOT NULL, -- DATA_RETENTION, DATA_DELETION, CONSENT_COLLECTED, etc.
    entity_type VARCHAR(100),
    entity_id UUID,

    -- Compliance status
    compliance_status VARCHAR(30) CHECK (compliance_status IN ('COMPLIANT', 'NON_COMPLIANT', 'UNDER_REVIEW', 'REMEDIATED')),

    -- Evidence
    evidence_data JSONB,
    evidence_url VARCHAR(500),

    -- Review information
    reviewed_by UUID, -- Reference to identity.users
    reviewed_at TIMESTAMP,
    review_notes TEXT,

    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_audit_logs_entity ON audit.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_actor ON audit.audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action ON audit.audit_logs(action);
CREATE INDEX idx_audit_logs_occurred ON audit.audit_logs(occurred_at DESC);
CREATE INDEX idx_audit_logs_aggregate ON audit.audit_logs(aggregate_type);
CREATE INDEX idx_audit_logs_request ON audit.audit_logs(request_id) WHERE request_id IS NOT NULL;
CREATE INDEX idx_audit_logs_severity ON audit.audit_logs(severity);

CREATE INDEX idx_security_audit_logs_user ON audit.security_audit_logs(user_id);
CREATE INDEX idx_security_audit_logs_event_type ON audit.security_audit_logs(event_type);
CREATE INDEX idx_security_audit_logs_occurred ON audit.security_audit_logs(occurred_at DESC);
CREATE INDEX idx_security_audit_logs_suspicious ON audit.security_audit_logs(is_suspicious) WHERE is_suspicious = TRUE;
CREATE INDEX idx_security_audit_logs_ip ON audit.security_audit_logs(ip_address);

CREATE INDEX idx_data_access_logs_subject ON audit.data_access_logs(subject_user_id);
CREATE INDEX idx_data_access_logs_accessor ON audit.data_access_logs(accessor_user_id);
CREATE INDEX idx_data_access_logs_access_type ON audit.data_access_logs(access_type);
CREATE INDEX idx_data_access_logs_occurred ON audit.data_access_logs(occurred_at DESC);
CREATE INDEX idx_data_access_logs_data_type ON audit.data_access_logs(data_type);

CREATE INDEX idx_system_activity_logs_service ON audit.system_activity_logs(service_name);
CREATE INDEX idx_system_activity_logs_severity ON audit.system_activity_logs(severity);
CREATE INDEX idx_system_activity_logs_occurred ON audit.system_activity_logs(occurred_at DESC);
CREATE INDEX idx_system_activity_logs_request ON audit.system_activity_logs(request_id) WHERE request_id IS NOT NULL;

CREATE INDEX idx_compliance_audit_trail_regulation ON audit.compliance_audit_trail(regulation);
CREATE INDEX idx_compliance_audit_trail_entity ON audit.compliance_audit_trail(entity_type, entity_id);
CREATE INDEX idx_compliance_audit_trail_status ON audit.compliance_audit_trail(compliance_status);
CREATE INDEX idx_compliance_audit_trail_occurred ON audit.compliance_audit_trail(occurred_at DESC);

-- GIN indexes for JSONB columns
CREATE INDEX idx_audit_logs_old_values ON audit.audit_logs USING gin(old_values);
CREATE INDEX idx_audit_logs_new_values ON audit.audit_logs USING gin(new_values);
CREATE INDEX idx_audit_logs_changes ON audit.audit_logs USING gin(changes);
CREATE INDEX idx_security_audit_logs_details ON audit.security_audit_logs USING gin(details);
CREATE INDEX idx_system_activity_logs_event_data ON audit.system_activity_logs USING gin(event_data);

-- Comments for documentation
COMMENT ON TABLE audit.audit_logs IS 'General audit logs for all entity changes - Aggregate Root';
COMMENT ON TABLE audit.security_audit_logs IS 'Security-specific audit events (authentication, authorization)';
COMMENT ON TABLE audit.data_access_logs IS 'Data access logs for privacy compliance (GDPR, etc.)';
COMMENT ON TABLE audit.system_activity_logs IS 'System-level events and monitoring';
COMMENT ON TABLE audit.compliance_audit_trail IS 'Compliance-specific audit trail for regulations';

-- Function to log entity changes (can be called from other contexts)
CREATE OR REPLACE FUNCTION audit.log_entity_change(
    p_entity_type VARCHAR(100),
    p_entity_id UUID,
    p_aggregate_type VARCHAR(100),
    p_action VARCHAR(50),
    p_actor_id UUID,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_request_id VARCHAR(100) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    audit_log_id UUID;
BEGIN
    INSERT INTO audit.audit_logs (
        entity_type,
        entity_id,
        aggregate_type,
        action,
        actor_id,
        old_values,
        new_values,
        ip_address,
        request_id
    ) VALUES (
        p_entity_type,
        p_entity_id,
        p_aggregate_type,
        p_action,
        p_actor_id,
        p_old_values,
        p_new_values,
        p_ip_address,
        p_request_id
    )
    RETURNING id INTO audit_log_id;

    RETURN audit_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to clean old audit logs (data retention policy)
CREATE OR REPLACE FUNCTION audit.archive_old_audit_logs(
    p_retention_days INTEGER DEFAULT 365
)
RETURNS INTEGER AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- In production, you might move these to an archive table instead of deleting
    DELETE FROM audit.audit_logs
    WHERE occurred_at < CURRENT_TIMESTAMP - (p_retention_days || ' days')::INTERVAL
      AND severity IN ('INFO', 'DEBUG');

    GET DIAGNOSTICS archived_count = ROW_COUNT;
    RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- Function to detect suspicious activity patterns
CREATE OR REPLACE FUNCTION audit.detect_suspicious_activity(p_user_id UUID, p_time_window_minutes INTEGER DEFAULT 5)
RETURNS BOOLEAN AS $$
DECLARE
    failed_login_count INTEGER;
    is_suspicious BOOLEAN;
BEGIN
    -- Count failed login attempts in time window
    SELECT COUNT(*)
    INTO failed_login_count
    FROM audit.security_audit_logs
    WHERE user_id = p_user_id
      AND event_type = 'LOGIN_FAILED'
      AND occurred_at > CURRENT_TIMESTAMP - (p_time_window_minutes || ' minutes')::INTERVAL;

    is_suspicious := failed_login_count >= 3;

    RETURN is_suspicious;
END;
$$ LANGUAGE plpgsql;
