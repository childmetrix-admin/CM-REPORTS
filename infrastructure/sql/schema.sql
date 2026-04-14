-- ChildMetrix Reports - Azure SQL Database Schema
-- Run against the provisioned Azure SQL Database

-- Users table (supplements Entra External ID)
CREATE TABLE cm_users (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    entra_object_id NVARCHAR(128) NOT NULL UNIQUE,
    email           NVARCHAR(256) NOT NULL UNIQUE,
    display_name    NVARCHAR(256) NOT NULL,
    role            NVARCHAR(50) NOT NULL DEFAULT 'viewer'
                    CHECK (role IN ('viewer', 'manager', 'admin', 'super_admin')),
    is_active       BIT NOT NULL DEFAULT 1,
    created_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    last_login_at   DATETIME2 NULL
);

-- State assignments (which states each user can access)
CREATE TABLE cm_user_states (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES cm_users(id) ON DELETE CASCADE,
    state_code  CHAR(2) NOT NULL,
    granted_by  INT NULL REFERENCES cm_users(id),
    granted_at  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_user_state UNIQUE (user_id, state_code)
);

-- Upload tracking
CREATE TABLE cm_uploads (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES cm_users(id),
    state_code      CHAR(2) NOT NULL,
    domain          NVARCHAR(50) NOT NULL DEFAULT 'cfsr',
    period          NVARCHAR(10) NOT NULL,
    filename        NVARCHAR(512) NOT NULL,
    blob_path       NVARCHAR(1024) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    content_hash    NVARCHAR(64) NULL,
    status          NVARCHAR(50) NOT NULL DEFAULT 'uploaded'
                    CHECK (status IN ('uploaded', 'processing', 'completed', 'failed', 'archived')),
    error_message   NVARCHAR(MAX) NULL,
    uploaded_at     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    processed_at    DATETIME2 NULL
);

-- Extraction run log
CREATE TABLE cm_extractions (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    state_code      CHAR(2) NOT NULL,
    domain          NVARCHAR(50) NOT NULL DEFAULT 'cfsr',
    period          NVARCHAR(10) NOT NULL,
    source_type     NVARCHAR(50) NOT NULL,
    status          NVARCHAR(50) NOT NULL DEFAULT 'started'
                    CHECK (status IN ('started', 'running', 'completed', 'failed')),
    triggered_by    NVARCHAR(50) NOT NULL DEFAULT 'manual'
                    CHECK (triggered_by IN ('manual', 'upload_event', 'scheduled')),
    container_id    NVARCHAR(256) NULL,
    input_blob_path NVARCHAR(1024) NULL,
    output_blob_path NVARCHAR(1024) NULL,
    duration_seconds INT NULL,
    error_message   NVARCHAR(MAX) NULL,
    started_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    completed_at    DATETIME2 NULL
);

-- Report catalog (what reports are available for each state/domain/period)
CREATE TABLE cm_reports (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    state_code      CHAR(2) NOT NULL,
    domain          NVARCHAR(50) NOT NULL,
    period          NVARCHAR(10) NOT NULL,
    report_type     NVARCHAR(50) NOT NULL,
    display_name    NVARCHAR(256) NOT NULL,
    blob_path       NVARCHAR(1024) NULL,
    is_published    BIT NOT NULL DEFAULT 0,
    published_at    DATETIME2 NULL,
    published_by    INT NULL REFERENCES cm_users(id),
    created_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_report UNIQUE (state_code, domain, period, report_type)
);

-- Audit log (captures all significant actions)
CREATE TABLE cm_audit_log (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT NULL REFERENCES cm_users(id),
    action      NVARCHAR(100) NOT NULL,
    entity_type NVARCHAR(50) NULL,
    entity_id   NVARCHAR(256) NULL,
    details     NVARCHAR(MAX) NULL,
    ip_address  NVARCHAR(45) NULL,
    user_agent  NVARCHAR(512) NULL,
    created_at  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- App configuration (feature flags, state settings)
CREATE TABLE cm_config (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    config_key  NVARCHAR(256) NOT NULL,
    config_value NVARCHAR(MAX) NOT NULL,
    state_code  CHAR(2) NULL,
    domain      NVARCHAR(50) NULL,
    description NVARCHAR(512) NULL,
    updated_at  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_config UNIQUE (config_key, state_code, domain)
);

-- Indexes for common query patterns
CREATE INDEX ix_users_email ON cm_users(email);
CREATE INDEX ix_users_role ON cm_users(role) WHERE is_active = 1;
CREATE INDEX ix_user_states_state ON cm_user_states(state_code);
CREATE INDEX ix_uploads_state_period ON cm_uploads(state_code, period);
CREATE INDEX ix_uploads_status ON cm_uploads(status) WHERE status IN ('uploaded', 'processing');
CREATE INDEX ix_extractions_state ON cm_extractions(state_code, domain, period);
CREATE INDEX ix_extractions_status ON cm_extractions(status) WHERE status IN ('started', 'running');
CREATE INDEX ix_reports_state ON cm_reports(state_code, domain) WHERE is_published = 1;
CREATE INDEX ix_audit_user ON cm_audit_log(user_id, created_at DESC);
CREATE INDEX ix_audit_action ON cm_audit_log(action, created_at DESC);
CREATE INDEX ix_config_key ON cm_config(config_key);

GO

-- Seed initial configuration
INSERT INTO cm_config (config_key, config_value, description)
VALUES
    ('platform.name', 'ChildMetrix Reports', 'Platform display name'),
    ('platform.version', '2.1', 'Current platform version'),
    ('auth.session_timeout_minutes', '480', 'Session timeout in minutes (8 hours)'),
    ('auth.mfa_required', 'true', 'Whether MFA is required for all users'),
    ('upload.max_file_size_mb', '100', 'Maximum upload file size in MB'),
    ('upload.allowed_extensions', '.pdf,.xlsx,.xlsm,.xls,.csv', 'Allowed file extensions for upload');

-- Seed domain configuration
INSERT INTO cm_config (config_key, config_value, domain, description)
VALUES
    ('domain.enabled', 'true', 'cfsr', 'CFSR domain is active'),
    ('domain.enabled', 'false', 'cps', 'CPS domain not yet implemented'),
    ('domain.enabled', 'false', 'in_home', 'In-Home domain not yet implemented'),
    ('domain.enabled', 'false', 'ooh', 'Out-of-Home domain not yet implemented'),
    ('domain.enabled', 'false', 'community', 'Community domain not yet implemented');

-- Seed state configuration for active states
INSERT INTO cm_config (config_key, config_value, state_code, description)
VALUES
    ('state.enabled', 'true', 'MD', 'Maryland is active'),
    ('state.enabled', 'true', 'KY', 'Kentucky is active'),
    ('state.enabled', 'false', 'MI', 'Michigan placeholder'),
    ('state.enabled', 'false', 'NC', 'North Carolina placeholder');
GO
