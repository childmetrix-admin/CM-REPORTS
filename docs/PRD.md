# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## ChildMetrix Reports Platform - Monorepo Consolidation & Architecture Refactor

**Version**: 1.0
**Date**: 2026-01-22
**Author**: Kurt Heisler, Child Metrix
**Status**: Draft for Architectural Review

---

## Executive Summary

The ChildMetrix Reports Platform currently operates across two repositories (cfsr-profile and cm-reports) with tight coupling but complex deployment coordination. This PRD outlines the consolidation into a single monorepo with scalable, DRY architecture to support multiple child welfare data types (CFSR, In-Home Services, Out-of-Home Care, CPS, Community Services) across 2-50 states.

**Key Goals**:
- Consolidate cfsr-profile and cm-reports into single monorepo
- Establish reusable data processing patterns for new data types
- Architect for horizontal scaling (2 states -> 50+ states)
- Simplify deployment coordination
- Maintain moderate code reuse without over-engineering

---

## 1. Current State Analysis

### 1.1 Existing Architecture

**Two Repositories**:
1. **cfsr-profile** (D:/repo_childmetrix/cfsr-profile/)
   - Purpose: Extract CFSR data from PDFs and Excel files
   - Inputs: ShareFile PDFs (S:/Shared Folders/{state}/cfsr/uploads/)
   - Outputs: RDS files -> cm-reports/shared/cfsr/data/
   - Key scripts: run_profile.R, profile_pdf_rsp.R, profile_pdf_observed.R, profile_excel_national.R

2. **cm-reports** (d:/repo_childmetrix/cm-reports/)
   - Purpose: Frontend platform + Shiny dashboards
   - Components: Static HTML pages + 4 Shiny apps (ports 3838-3841)
   - Data consumption: Loads RDS files from shared/cfsr/data/
   - Multi-state support: MD, KY (with placeholders for in_home, ooh, cps, community)

### 1.2 Current Data Flow

```
ShareFile PDFs/Excel
      |
cfsr-profile (extraction scripts)
      |
RDS files -> cm-reports/shared/cfsr/data/
      |
Shiny Apps (global.R loads data)
      |
Static HTML (iframes embed apps)
```

### 1.3 Pain Points

- **Complex deployment coordination**: Must deploy both repos in correct order
- **Version synchronization**: Changes in one repo may break the other
- **Code duplication emerging**: Similar patterns across extraction scripts
- **Unclear boundaries**: Tight coupling despite separate repos

### 1.4 Current Data Type Coverage

**Implemented**: CFSR (8 indicators, 2 states, 4 Shiny apps)
**Planned**: In-Home Services, Out-of-Home Care, CPS, Community Services (placeholder pages exist)

---

## 2. Project Goals & Success Criteria

### 2.1 Primary Goals

1. **Consolidate repositories** into single monorepo for simplified deployment
2. **Establish scalable patterns** for adding new data types (in-home, out-of-home, community, CPS)
3. **Implement DRY principles** with shared utilities and consistent patterns
4. **Design for growth** from 2-3 states to 50+ states without architectural changes
5. **Maintain code quality** with automated testing (data validation, unit tests, integration tests)

### 2.2 Success Criteria

**Must Have**:
- Single repository with unified versioning
- Add new data types with minimal code duplication
- Consistent Shiny app UI patterns across data types
- Single source of truth for data schemas
- Automated data validation (schema checks, range validation)
- Simplified deployment (one repo -> staging/production)

**Should Have**:
- Configuration-driven state onboarding (add state without code changes)
- Comprehensive testing suite (unit + integration)
- Documentation for adding new data types

**Nice to Have**:
- Automated data ingestion pipelines
- Real-time monitoring and alerting
- Historical data versioning and rollback

---

## 3. Data Types & File Formats

### 3.1 CFSR (Current)

**Data Sources**:
- CFSR 4 Data Profile PDFs (biannual: February, August)
- National Supplemental Context Data (Excel)
- State Supplemental Context Data (Excel)

**Extraction Method**: Coordinate-based PDF parsing (pdftools) + readxl

**Output Format**: RDS files (4 types: national, rsp, observed, state)

**Indicators**: 8 (Safety: 2, Permanency: 4, Well-Being: 2)

### 3.2 In-Home Services (Priority #1)

**Data Sources**: Excel/CSV files (format TBD by state data providers)

**Extraction Method**: readxl / readr with column mapping

**Output Format**: RDS files (structure to mirror CFSR pattern)

**Indicators**: TBD (will follow state-specific in-home services metrics)

### 3.3 Out-of-Home Care (Priority #2)

**Data Sources**: Excel/CSV files

**Extraction Method**: Similar to In-Home

**Output Format**: RDS files

**Indicators**: Foster care placement, permanency outcomes, re-entry rates

### 3.4 CPS (Child Protective Services)

**Data Sources**: Excel/CSV files

**Extraction Method**: Similar pattern

**Output Format**: RDS files

**Indicators**: Investigation timelines, substantiation rates, safety outcomes

### 3.5 Community Services

**Data Sources**: Excel/CSV files

**Extraction Method**: Similar pattern

**Output Format**: RDS files

**Indicators**: Community resource utilization, referral outcomes

---

## 4. Technical Architecture

### 4.1 Monorepo Structure (Implemented)

```
cm-reports/  (consolidated monorepo)
|
+-- _assets/
|   +-- css/                        # Platform CSS
|   +-- logo.png                    # Platform branding
|
+-- shared/
|   +-- utils/                      # Shared R utilities
|   |   +-- file_discovery.R        # ShareFile discovery functions
|   |   +-- file_utils.R            # File handling utilities
|   |   +-- state_utils.R           # State code mapping
|   |
|   +-- visualization/              # Cross-domain chart builders
|   +-- schemas/                    # Data schema definitions
|   +-- tests/                      # Shared test fixtures
|
+-- cfsr/                           # CFSR data pipeline (self-contained)
|   +-- extraction/
|   |   +-- run_profile.R           # Orchestrator
|   |   +-- config.R                # Discovery + validation
|   |   +-- paths.R                 # Centralized path configuration
|   |   +-- profile_pdf_rsp.R
|   |   +-- profile_pdf_observed.R
|   |   +-- profile_excel_national.R
|   |   +-- profile_excel_state.R
|   |
|   +-- functions/                  # CFSR-specific utilities
|   |   +-- functions_cfsr_profile_shared.R
|   |   +-- functions_cfsr_profile_pdf_rsp.R
|   |   +-- functions_cfsr_profile_excel.R
|   |   +-- period_utils.R          # Period format conversion
|   |   +-- utils.R                 # Shiny data loading
|   |
|   +-- data/                       # Data outputs
|   |   +-- csv/                    # CSV archive
|   |   +-- rds/                    # RDS for Shiny apps
|   |
|   +-- apps/                       # CFSR Shiny apps
|   |   +-- app_national/
|   |   +-- app_rsp/
|   |   +-- app_observed/
|   |   +-- app_summary/
|   |
|   +-- modules/                    # Shiny modules
|   +-- scripts/                    # Utilities (launch_cfsr_dashboard.R)
|   +-- tests/
|
+-- in_home/                        # In-Home Services (Future - Phase 2)
+-- ooh/                            # Out-of-Home Care (Future - Phase 3)
+-- cps/                            # CPS (Future - Phase 4)
+-- community/                      # Community Services (Future - Phase 5)
|
+-- states/                         # State-specific sites
|   +-- md/
|   +-- ky/
|
+-- docs/                           # Documentation
|   +-- PRD.md                      # This document
|
+-- index.html                      # Landing page
+-- app.html                        # Main app shell
+-- README.md
+-- CLAUDE.md
```

### 4.2 Data Processing Pattern (Reusable)

**Standard Pipeline for All Data Types**:

1. **Discovery** (shared/utils/file_discovery.R)
   - Scan ShareFile for available states/periods/files
   - Return structured list of available data

2. **Validation** (cfsr/extraction/config.R)
   - Check file existence and readability
   - Validate state codes and period formats

3. **Extraction** ({data_type}/extraction/run_{type}.R)
   - Data-type-specific parsing logic
   - Use shared utilities where possible

4. **Transformation** ({data_type}/functions/)
   - Clean, reshape, enrich data
   - Apply consistent column naming

5. **Schema Validation** (shared/schemas/{type}_schema.R)
   - Validate against expected schema
   - Check data types, required columns, value ranges

6. **Output** ({data_type}/data/rds/)
   - Write RDS files for Shiny apps
   - Include metadata (extraction date, source file, version)

7. **Consumption** ({data_type}/apps/)
   - Shiny apps load RDS via standardized functions
   - Consistent UI patterns across data types

### 4.3 Shared Utility Functions (Moderate Reuse)

**Files in shared/utils/**:

- `discover_states()` - Scan ShareFile for available states
- `discover_periods(state)` - Find available periods for a state
- `validate_state(state_code)` - Check state code validity
- `state_code_to_name()` - Convert code to full name
- `state_name_to_code()` - Convert name to code

**Example Usage**:
```r
# In cfsr/extraction/run_profile.R
source("../../../shared/utils/file_discovery.R")
source("../../../shared/utils/state_utils.R")

states <- discover_states()  # Reusable across all data types
validate_state("MD")          # Reusable
```

---

## 5. Scalability Requirements

### 5.1 State Scaling

**Current**: 2 states (MD, KY)
**Target**: 2-50 states (design for horizontal scaling)

**Requirements**:
- Configuration-driven state onboarding (add state code + data files)
- No hardcoded state lists in core logic (use discovery functions)
- State-specific customizations via config files (not code changes)

### 5.2 Data Volume Scaling

**Current**: ~100 MB total (CFSR RDS files)
**Projected**: 1-10 GB with 5 data types x 50 states x multiple periods

**Requirements**:
- Efficient RDS compression
- Lazy loading in Shiny apps (load only requested data)
- Archive old periods (move to cold storage after 2 years)

### 5.3 Performance Requirements

**Shiny App Load Time**: < 3 seconds for initial page load
**Data Extraction**: < 10 minutes per state/period/data type
**Concurrent Users**: Support 10-50 simultaneous Shiny app users

---

## 6. Testing Strategy

### 6.1 Data Validation (Automated)

**Location**: cfsr/extraction/config.R

**Checks**:
- Schema compliance (all required columns present)
- Data type correctness (numeric where expected, character where expected)
- Value range validation (e.g., percentages 0-100, rates non-negative)
- Missing data detection (flag critical missing values)

**Implementation**: Run after every extraction script

### 6.2 Unit Tests

**Framework**: testthat

**Coverage**:
- Extraction functions (PDF parsing, Excel reading)
- Transformation functions (cleaning, reshaping)
- Shared utilities (state conversion, period formatting)

**Target**: 80%+ code coverage for shared/utils/ and {data_type}/functions/

**Example**:
```r
# tests/testthat/test-file_discovery.R
test_that("discover_states returns valid state codes", {
  states <- discover_states()
  expect_type(states, "character")
  expect_true(all(nchar(states) == 2))
  expect_true(all(states %in% VALID_STATE_CODES))
})
```

### 6.3 Integration Tests (Shiny Apps)

**Framework**: shinytest2

**Coverage**:
- App loads without errors
- URL parameters work (?state=MD&profile=2025_02)
- Filters update outputs correctly
- Charts render successfully

### 6.4 Manual Testing Checklist

**Before Each Deployment**:
- [ ] Extract sample data for 2 states
- [ ] Launch all Shiny apps
- [ ] Test state/period selection in each app
- [ ] Verify charts render correctly
- [ ] Check data table sorting/filtering
- [ ] Test responsive design (mobile, tablet, desktop)
- [ ] Verify static HTML pages load correctly

---

## 7. Deployment Strategy

### 7.1 Development Environment

**Current Setup**: Local Windows machine (D:/repo_childmetrix/)

**Workflow**:
1. Edit code in VSCode
2. Run extraction scripts locally (data from S:/Shared Folders/)
3. Launch Shiny apps on localhost ports
4. Test in browser (http://localhost:3838-3841)

### 7.2 Staging Environment

**Server**: stage.childmetrix.com
**Deploy Script**: deploy-stage.ps1 (already exists)
**Purpose**: Client preview before production

**Deployment Steps**:
1. Commit changes to git
2. Run `.\deploy-stage.ps1` (syncs via scp)
3. Creates timestamped backup on server
4. Syncs files to /var/www/stage.childmetrix.com/html/

### 7.3 Production Environment (Future)

**Target**: DigitalOcean Droplet
**Stack**: Ubuntu + Shiny Server (or ShinyProxy) + nginx
**Authentication**: Server-level HTTP auth (staging) -> User authentication (production)

**Planned Setup**:
- Single droplet running Shiny Server
- nginx reverse proxy (ports 3838-3841 -> subdomains or paths)
- SSL certificates (Let's Encrypt)
- Automated backups (daily)
- Monitoring (uptime, error logs)

**Authentication Requirements** (Production):
- User login system (email + password)
- State-specific access control (MD users see MD data only)
- Admin panel for user management
- Session management (logout, timeout)

---

## 8. Migration Plan (Phased Approach)

### Phase 1: Consolidation Foundation (COMPLETE)

**Goals**: Merge repos, establish structure, migrate CFSR

**Deliverables**:
- Single functional monorepo
- CFSR pipeline working (no regressions)
- Updated deployment script
- cfsr-profile consolidated into cm-reports

### Phase 2: Add In-Home Services (Week 3-4)

**Goals**: Implement first new data type using established patterns

**Tasks**:
1. Create in_home/ directory structure
2. Develop extraction script (run_in_home.R)
3. Define in_home_schema.R
4. Implement data validation
5. Create Shiny app (app_in_home/)
6. Write unit tests + integration tests
7. Update frontend HTML pages

**Deliverables**:
- Functional In-Home Services pipeline
- Demonstration of reusable patterns

### Phase 3: Testing & Quality (Week 5-6)

**Goals**: Establish comprehensive testing suite

**Tasks**:
1. Write unit tests for shared/utils/
2. Write unit tests for cfsr/functions/
3. Write integration tests for CFSR apps
4. Write integration tests for In-Home app
5. Set up automated test runs (CI/CD if applicable)
6. Document testing standards

**Deliverables**:
- 80%+ test coverage for shared utilities
- Integration tests for all apps
- Testing documentation

### Phase 4: Out-of-Home, CPS, Community (Week 7+)

**Goals**: Scale to remaining data types

**Tasks**:
1. Repeat Phase 2 pattern for each data type
2. Leverage shared utilities (minimal new code)
3. Maintain consistent UI patterns across apps
4. Comprehensive testing for each new type

**Deliverables**:
- Full platform coverage (5 data types)
- Consistent user experience

### Phase 5: Production Deployment (Future)

**Goals**: Deploy to DigitalOcean with authentication

**Deliverables**:
- Production-ready platform
- User authentication
- Monitoring and backups

---

## 9. Risks & Mitigation

### 9.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Path breakages during consolidation | High | Medium | Comprehensive testing after move, maintain git history |
| PDF parsing fragility (coordinate changes) | High | Medium | Add validation checks, test with multiple profile versions |
| Performance degradation with scale | Medium | Low | Implement lazy loading, optimize RDS compression |
| Shiny app instability under load | Medium | Medium | Load testing, consider ShinyProxy for production |

### 9.2 Organizational Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Data provider format changes | High | High | Flexible extraction logic, version-specific parsers |
| State onboarding delays | Low | High | Automate state setup, clear documentation |
| Resource constraints (single developer) | Medium | Medium | Phased approach, prioritize ruthlessly |

---

## 10. Success Metrics

**Immediate (End of Phase 1)**:
- Single monorepo with functional CFSR pipeline
- Zero regressions in CFSR functionality
- Simplified deployment (one repo -> staging)

**Short-Term (End of Phase 2)**:
- In-Home Services implemented with <30% new code (70% reuse)
- Consistent UI patterns across CFSR + In-Home apps
- Documented process for adding new data types

**Medium-Term (End of Phase 4)**:
- All 5 data types implemented
- 80%+ test coverage for shared utilities
- 3+ states actively using platform

**Long-Term (Production)**:
- 10+ states deployed
- User authentication and access control
- <5 bugs per month in production
- App load time <3 seconds

---

## 11. Open Questions

1. **In-Home data format**: What is the exact Excel/CSV structure? (Need sample files)
2. **State-specific customizations**: How much variability between states? (e.g., MD indicators vs. KY indicators)
3. **Historical data migration**: Should we backfill older periods for new data types?
4. **User roles**: What access control levels needed? (State-level? Agency-level? Public?)
5. **API requirements**: Will external systems need programmatic access to data?

---

## 12. Appendices

### Appendix A: State Codes (CFSR)

50 states + DC + PR = 52 jurisdictions

### Appendix B: Period Formats

- **AFCARS**: `20A20B` (Oct '19 - Sep '20), `20B21A` (Apr '20 - Mar '21)
- **Maltreatment**: `20AB_FY20` (combo AFCARS + FY), `FY20-21` (recurrence)
- **Standard**: `YYYY_MM` (2025_02 = February 2025 profile)

### Appendix C: Technology Stack

- **Language**: R (tidyverse, shiny)
- **PDF Parsing**: pdftools
- **Excel Reading**: readxl, openxlsx
- **Data Format**: RDS (R Data Serialization)
- **Frontend**: Static HTML + Tailwind CSS
- **Deployment**: PowerShell (scp sync to staging), Future: Docker + nginx

### Appendix D: Architecture Decision Records

- **ADR-001**: Git subtree merge for consolidation (preserve history)
- **ADR-002**: Moderate code reuse (6-8 shared utilities)
- **ADR-003**: Self-contained CFSR domain (no external utilities-core dependency)
- **ADR-004**: Data stored at cfsr/data/rds/ (domain self-containment)
- **ADR-005**: Internalize utilities-core functions into shared/utils/

---

**END OF PRD**
