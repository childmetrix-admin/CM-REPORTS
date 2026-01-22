# Changelog

All notable changes to the CFSR Profile project will be documented in this file.

## [Unreleased]

### Changed
- Repository renamed from `r_cfsr_profile` to `cfsr-profile` (kebab-case)
- Updated all path references to new naming convention
- Updated utilities paths to `utilities-core` and `utilities-cfsr`
- Reorganized documentation into `docs/` folder structure

## [2025-10-13] - Phase 1: Multi-State Support

### Added
- Multi-state data organization system
- `state_code` parameter for state-specific processing
- `setup_cfsr_folders()` function for state-specific folder structure
- `find_cfsr_file()` function for flexible file finding
- Period-specific RDS file saving (e.g., `MD_cfsr_indicators_2025_02.rds`)
- File organization utilities in `code/organize_cfsr_uploads.R`

### Changed
- Data structure: `data/{STATE}/{PERIOD}/raw/` and `data/{STATE}/{PERIOD}/processed/`
- Shiny app data loading updated for multi-state support
- `prepare_app_data.R` saves to both dev and prod locations

## [2025-10-09] - Phase 3: Overview Dashboard

### Added
- Overview page with small multiples (8 charts in grid)
- Data dictionary page with searchable, sortable table
- Category organization (Safety, Permanency, Well-Being)

## [2025-10-09] - Phase 2: All Indicators

### Added
- Reusable indicator page module (`modules/indicator_page.R`)
- All 8 indicator detailed pages with charts and tables
- Complete navigation sidebar

## [2025-10-09] - Code Refactoring

### Added
- `process_standard_indicator()` function (handles 5 of 6 indicators)
- `process_entry_rate_indicator()` function (handles Entry Rate)
- Indicator dictionary integration (`cfsr_round4_indicators_dictionary.csv`)
- Support for Maltreatment in Care and Recurrence indicators

### Changed
- Main script reduced from 604 lines to 139 lines (77% reduction)
- Consolidated repeated code into reusable functions

### Fixed
- Period regex pattern to handle maltreatment formats (`20AB,FY20`, `FY20-21`)

## Historical Notes

For detailed development history, see files in `docs/archive/development-history/`:
- Bug fixes and feature additions
- Phase-by-phase implementation summaries
- Refactoring analysis and testing guides
