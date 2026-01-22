# Child Metrix Project Workflow

## Repository Organization

- Utilities repos: `utilities-core`, `utilities-mdcps`, `utilities-md`, `utilities-cfsr`
- State projects: Under `D:\` with state-specific folders
- Web platform: `cm-reports` repo

## Naming Conventions

- Repo folders: kebab-case (`ms-mdcps-1-3-a`, `md-maryland-5-2-c`)
- R scripts: snake_case (`1_3_a.R`, `5_2_c.R`)
- Functions: snake_case (`load_cfsr_data`, `render_quarterly_memos`)

## Data Pipeline

- Extract CFSR data from PDFs (via `cfsr-profile` repo)
- Save processed RDS files to `cm-reports/shared/cfsr/data/`
- Shiny apps consume RDS files for visualization
- Static HTML embeds Shiny apps via iframes

## Deployment

- Use `deploy-stage.ps1` for staging deployment
- Target: `stage.childmetrix.com`
- Creates timestamped backups before sync
- Use `-MdOnly` flag for faster Maryland-only deploys

## Testing Protocol

- ALWAYS test locally before committing
- Run Shiny apps with `launch_cfsr_dashboard.R`
- Verify iframe integrations in browser
- Check responsive design on mobile/desktop

## cm-reports Architecture

### Directory Structure

```
cm-reports/
├── states/              # State-specific HTML hubs
│   ├── md/             # Maryland (reference implementation)
│   └── ky/             # Kentucky
├── shared/             # Shared Shiny apps and functions
│   └── cfsr/
│       ├── functions/  # Shared R functions
│       ├── modules/    # Shiny modules
│       ├── measures/   # Individual Shiny apps
│       │   ├── app_rsp/        (port 3839)
│       │   ├── app_observed/   (port 3841)
│       │   └── app_national/   (port 3838)
│       └── summary/    # Summary dashboard
│           └── app_summary/    (port 3840)
├── _assets/            # Global assets
└── deploy-stage.ps1    # Deployment script
```

### Multi-App Port Strategy

- **3838**: National comparison app
- **3839**: Risk-Standardized Performance (RSP) app
- **3840**: Summary dashboard
- **3841**: Observed Performance app

### State Routing

- Landing page (`index.html`) routes to state hubs
- State hubs provide navigation to report categories
- Report categories contain dated periods (`YYYY_MM/`)
- `current/` symlinks or copies point to latest period

## Common Operations

### Adding a New State

1. Create `states/{state}/` directory
2. Add state route to `index.html` STATE_ROUTES object
3. Create state hub `states/{state}/index.html`
4. Create category structure: `cfsr/`, `cps/`, `in_home/`, `ooh/`
5. Deploy: `.\deploy-stage.ps1`

### Adding a New CFSR App

1. Create app directory: `shared/cfsr/measures/app_{name}/`
2. Add `app.R` and `global.R` files
3. Choose unused port (e.g., 3842)
4. Add to `launch_cfsr_dashboard.R`
5. Create iframe wrapper HTML in `shared/cfsr/measures/`
6. Test locally, then deploy

### Updating Data

1. Process PDF with cfsr-profile extraction scripts
2. Save RDS to `shared/cfsr/data/{STATE}_cfsr_profile_{TYPE}_{YYYY_MM}.rds`
3. Update Shiny app global.R if data structure changed
4. Test apps locally
5. Deploy to staging

## Code Organization Principles

### When to Extract Functions

- Chart code used in 2+ apps → `chart_builder.R`
- Data transformations used in 2+ apps → `data_prep.R`
- UI patterns repeated 2+ times → Shiny module
- State-agnostic utilities → `utilities-core`
- CFSR-specific utilities → `utilities-cfsr`

### File Naming

- Shiny apps: `app.R`, `global.R` in app directory
- Shared functions: descriptive names (`chart_builder.R`, `data_prep.R`)
- Modules: `{module_name}.R` (e.g., `indicator_detail.R`)
- HTML wrappers: `cfsr_profile_{type}.html`

## Git Workflow

- **NEVER** commit without user approval
- Test locally before committing
- Use conventional commit messages: `feat:`, `fix:`, `refactor:`, `docs:`
- Push with `-u` flag for new branches
