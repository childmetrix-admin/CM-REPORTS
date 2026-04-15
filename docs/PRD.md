# PRODUCT REQUIREMENTS DOCUMENT (PRD)
## ChildMetrix Reports Platform - Monorepo Architecture & Roadmap

**Version**: 2.1
**Date**: 2026-04-03
**Status**: Current Architecture & Future Roadmap

---

## Executive Summary

The ChildMetrix Reports Platform is a **consolidated monorepo** providing multi-state child welfare reporting with interactive Shiny dashboards. The platform was successfully consolidated from two repositories (cfsr-profile + cm-reports) in January 2026 and now operates as a single, unified codebase.

**Current State** (April 2026):
- ✅ Single monorepo with unified deployment
- ✅ CFSR domain fully implemented (8 indicators, 2 states)
- ✅ Design system for consistent UI/UX
- ✅ Standardized data extraction pipeline
- ✅ Self-contained domain architecture
- ⏳ Cloud hosting migration (AWS or Azure -- TBD)
- ⏳ Authentication implementation (Auth0)

**Key Architecture Goals**:
- Domain-based organization (cfsr, cps, in_home, ooh, community)
- Shared utilities internalized (no external dependencies)
- Horizontal scaling from 2 states → 50+ states
- Design system for rapid UI development
- Moderate code reuse without over-engineering

---

## 1. Current Architecture (Post-Consolidation)

### 1.1 Monorepo Structure

**Single Repository** (`D:/repo_childmetrix/cm-reports/`):
```
cm-reports/
├── domains/                   # Self-contained domain modules
│   ├── cfsr/                  # CFSR data type (fully implemented)
│   │   ├── apps/              # Shiny apps (app_measures, app_summary)
│   │   ├── extraction/        # Data extraction pipeline
│   │   ├── functions/         # Domain-specific utilities
│   │   ├── modules/           # Shiny modules
│   │   └── data/rds/          # Extracted RDS files
│   ├── cps/                   # CPS domain (planned)
│   ├── in_home/               # In-Home Services (planned)
│   ├── ooh/                   # Out-of-Home Care (planned)
│   └── community/             # Community Services (planned)
├── shared/                    # Cross-domain utilities
│   ├── css/                   # Design system (design-tokens.css, components.css)
│   └── utils/                 # Shared R utilities (state_utils.R, file_discovery.R)
├── states/                    # State-specific frontend hubs
│   ├── md/                    # Maryland hub
│   └── ky/                    # Kentucky hub
└── index.html                 # Landing page with state selector
```

### 1.2 Current Data Flow

```
Azure Blob raw container ({state}/cfsr/uploads/{period}/)
      |
domains/cfsr/extraction/ (run_profile.R, profile_pdf_*.R)
      |
Azure Blob processed container (RDS paths from build_rds_path())
      |
domains/cfsr/apps/ (Shiny apps load data from blob via global.R / utils.R)
      |
states/{state}/{category}/ (Static HTML embeds apps via iframes)
```

### 1.3 Implemented Features

**CFSR Domain**:
- ✅ Data extraction pipeline (PDFs → RDS)
- ✅ 2 Shiny apps (app_measures, app_summary)
- ✅ 8 statewide data indicators
- ✅ 2 states (Maryland, Kentucky)
- ✅ Design system with standardized UI components
- ✅ Download buttons for PNG export (html2canvas)

**Platform Features**:
- ✅ Static HTML frontend with state-specific hubs
- ✅ Design system (CSS tokens + reusable components)
- ✅ Shared utilities internalized (no external dependencies)
- ✅ Client-side routing for state selection

### 1.4 Active States

**Implemented**: Maryland (MD), Kentucky (KY)
**Placeholder pages**: Additional states ready for data integration

### 1.5 Benefits of Consolidation (Achieved)

- ✅ **Unified deployment**: Single repo to staging/production
- ✅ **Simplified versioning**: All components version together
- ✅ **No coordination overhead**: Extraction + frontend in same codebase
- ✅ **Self-contained domains**: Each data type encapsulated in domains/{type}/
- ✅ **Faster iteration**: Changes deploy atomically

---

## 2. Roadmap & Future Goals

### 2.1 Completed (Q1 2026)

1. ✅ **Complete design system documentation** (Issue #13)
2. ✅ **Consolidate CFSR apps** from 4 to 2 (app_measures, app_summary)

### 2.2 Near-Term Goals (Q2 2026)

1. **Cloud hosting migration** - Deploy to AWS or Azure (TBD)
2. **Authentication** - Auth0 integration with MFA and RBAC
3. **Standardize R script structure** (Issue #14)
4. **Add trend visualizations** (Issue #8) - Sparklines and historical comparisons
5. **Expand state coverage** - Add 2-3 additional states to CFSR domain
6. **Clean up data quality warnings** (Issue #12) - Address 'dq' column handling

### 2.3 Medium-Term Goals (Q3-Q4 2026)

1. **Implement additional domains**:
   - CPS (Child Protective Services)
   - In-Home Services
   - Out-of-Home Care
   - Community Services
2. **PowerPoint generation** (Issue #9) - Automated presentation exports
3. **Enhanced testing** - Increase test coverage to 80%+
4. **Performance optimization** - Sub-second page loads
5. **Secure data upload portal** - HTTPS upload to per-state S3 buckets

### 2.4 Long-Term Goals (2027+)

1. **Horizontal scaling** - Support 10-20 states across multiple domains
2. **Automated data ingestion** - Pipeline from state upload to platform
3. **Historical trending** - Year-over-year comparisons and trend analysis
4. **Advanced visualizations** - Interactive drill-downs, custom filtering
5. **User management** - Role-based access control per state/domain

### 2.4 Success Metrics

**Platform Maturity**:
- ✅ Single monorepo deployment (achieved)
- ✅ Design system standardization (achieved)
- ⏳ 80%+ test coverage (in progress)
- ⏳ < 2 second page load times
- ⏳ 5+ domains implemented
- ⏳ 10+ states supported

**Development Velocity**:
- ✅ New state onboarding: < 1 day (achieved)
- ⏳ New domain implementation: < 2 weeks
- ⏳ New indicator addition: < 1 day
- ⏳ Bug fix deployment: < 1 hour

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
|   |   +-- file_discovery.R        # Azure Blob discovery functions
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
|   |   +-- app_measures/           # Measures + indicators
|   |   +-- app_summary/            # Performance summary
|   |
|   +-- modules/                    # Shiny modules
|   +-- scripts/                    # Utilities (no local Shiny launcher; use Docker / Azure)
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
   - List available states/periods/files from the Azure Blob raw container
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

6. **Output** (Azure Blob processed container and/or domain data folders)
   - Write RDS for Shiny apps (uploaded to blob in CFSR pipeline)
   - Include metadata (extraction date, source file, version)

7. **Consumption** ({data_type}/apps/)
   - Shiny apps load RDS via standardized functions
   - Consistent UI patterns across data types

### 4.3 Shared Utility Functions (Moderate Reuse)

**Files in shared/utils/**:

- `discover_states()` - Discover states from Azure Blob raw uploads
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

**Current Setup**: Development machine with Azure credentials for blob storage

**Workflow**:
1. Edit code in VSCode
2. Run extraction scripts against Azure Blob (raw uploads → processed RDS)
3. Run Shiny via Docker (`infrastructure/docker/shiny/`) or test deployed Container Apps
4. Test in browser using production or staging base URLs (or `?shiny_base=` on static embed pages)

### 7.2 Cloud Hosting (In Progress)

**Target**: AWS or Azure (decision pending)
**Authentication**: Auth0 with MFA, RBAC, and state-based data isolation
**Data storage**: Per-state S3 buckets (or equivalent), AES-256 encryption at rest

**Planned Setup**:
- Cloud-hosted Shiny Server (or ShinyProxy)
- Reverse proxy with SSL
- Per-state data isolation at storage and auth layers
- Automated backups (daily)
- Monitoring (uptime, error logs)

**Authentication Requirements**:
- User login via Auth0 (email + password, MFA)
- State-specific access control (MD users see MD data only)
- Admin panel for user management
- Session management (logout, timeout)
- No shared credentials across state clients

Previous DigitalOcean staging setup has been removed.

---

## 8. Migration Plan (Phased Approach)

### Phase 1: Consolidation Foundation (COMPLETE)

**Goals**: Merge repos, establish structure, migrate CFSR

**Deliverables**:
- Single functional monorepo
- CFSR pipeline working (no regressions)
- Updated deployment script
- cfsr-profile consolidated into cm-reports

### Phase 2: Add In-Home Services

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

### Phase 3: Testing & Quality

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

### Phase 4: Out-of-Home, CPS, Community

**Goals**: Scale to remaining data types

**Tasks**:
1. Repeat Phase 2 pattern for each data type
2. Leverage shared utilities (minimal new code)
3. Maintain consistent UI patterns across apps
4. Comprehensive testing for each new type

**Deliverables**:
- Full platform coverage (5 data types)
- Consistent user experience

### Phase 5: Production Deployment

**Goals**: Deploy to AWS or Azure with authentication

**Deliverables**:
- Production-ready cloud-hosted platform
- Auth0 user authentication with state-based RBAC
- Per-state data isolation (separate storage buckets)
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
- **Deployment**: AWS or Azure (TBD), Auth0 authentication

### Appendix D: Architecture Decision Records

- **ADR-001**: Git subtree merge for consolidation (preserve history)
- **ADR-002**: Moderate code reuse (6-8 shared utilities)
- **ADR-003**: Self-contained CFSR domain (no external utilities-core dependency)
- **ADR-004**: Data stored at cfsr/data/rds/ (domain self-containment)
- **ADR-005**: Internalize utilities-core functions into shared/utils/

---

**END OF PRD**
