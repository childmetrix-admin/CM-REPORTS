-- ChildMetrix Reports - Seed Data for Development
-- Run after schema.sql

-- Create a super admin user (update entra_object_id after Entra setup)
INSERT INTO cm_users (entra_object_id, email, display_name, role)
VALUES ('placeholder-update-after-entra-setup', 'admin@childmetrix.com', 'Platform Admin', 'super_admin');

DECLARE @adminId INT = SCOPE_IDENTITY();

-- Grant super admin access to all active states
INSERT INTO cm_user_states (user_id, state_code, granted_by)
VALUES
    (@adminId, 'MD', @adminId),
    (@adminId, 'KY', @adminId);

-- Seed report catalog with existing CFSR reports
INSERT INTO cm_reports (state_code, domain, period, report_type, display_name, is_published, published_at)
VALUES
    ('MD', 'cfsr', '2026_02', 'rsp', 'Risk Standardized Performance - Feb 2026', 1, SYSUTCDATETIME()),
    ('MD', 'cfsr', '2026_02', 'observed', 'Observed Performance - Feb 2026', 1, SYSUTCDATETIME()),
    ('MD', 'cfsr', '2026_02', 'national', 'National Comparison - Feb 2026', 1, SYSUTCDATETIME()),
    ('MD', 'cfsr', '2025_08', 'rsp', 'Risk Standardized Performance - Aug 2025', 1, SYSUTCDATETIME()),
    ('MD', 'cfsr', '2025_08', 'observed', 'Observed Performance - Aug 2025', 1, SYSUTCDATETIME()),
    ('KY', 'cfsr', '2025_08', 'rsp', 'Risk Standardized Performance - Aug 2025', 1, SYSUTCDATETIME()),
    ('KY', 'cfsr', '2025_08', 'observed', 'Observed Performance - Aug 2025', 1, SYSUTCDATETIME());
GO
