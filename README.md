# ChildMetrix Reporting Platform

Web-based reporting platform for child welfare data visualization and analysis across multiple states.

## Overview

This repository contains the ChildMetrix reporting platform - a multi-state web application that provides interactive dashboards, data visualizations, and reports for child welfare agencies.

## Directory Structure

```
cm-reports/
├── _assets/              # Shared platform assets (logos, CSS, icons)
│   └── cfsr/            # CFSR-specific shared assets
├── scripts/              # Development utilities and one-time scripts
│   └── move_period_selector.py
├── states/               # State-specific reporting sites
│   ├── ky/              # Kentucky
│   │   ├── _assets/     # State-specific assets
│   │   ├── cfsr/        # CFSR data profile
│   │   ├── cps/         # CPS reports
│   │   ├── in_home/     # In-home services
│   │   ├── ooh/         # Out-of-home care
│   │   └── index.html   # State landing page
│   └── md/              # Maryland (primary development state)
│       ├── _assets/
│       ├── cfsr/
│       │   ├── data_dictionary/
│       │   ├── notes/
│       │   ├── performance/
│       │   │   ├── app/          # Shiny dashboard application
│       │   │   └── index_static.html
│       │   └── presentations/
│       ├── cps/
│       ├── home/
│       ├── in_home/
│       ├── ooh/
│       ├── index.html   # Maryland hub
│       └── README.md    # Maryland-specific notes
├── index.html            # Main landing page (state selector)
└── README.md             # This file
```

## Features

### Multi-State Support
- Each state has its own folder under `states/`
- Shared infrastructure and assets at platform level
- State-specific branding and customization

### CFSR Data Profile Dashboard
- Interactive Shiny application for CFSR statewide data indicators
- 8 indicators across Safety, Permanency, and Well-Being domains
- State-by-state rankings and comparisons
- Data dictionary and presentations

### Domain-Specific Reports
Each state site includes:
- **CFSR**: Child and Family Services Review data profiles
- **CPS**: Child Protective Services reports
- **In-Home**: In-home services tracking
- **OOH**: Out-of-home care (foster care) reports

## Data Integration

The platform integrates with data processing pipelines:

**CFSR Data Pipeline:**
1. Raw data uploaded to ShareFile: `S:/Shared Folders/{state}/cfsr/uploads/{period}/`
2. Processed by `cfsr-profile` R project
3. RDS files saved to: `states/{state}/cfsr/performance/app/data/`
4. Shiny dashboard loads data and renders visualizations

See [cfsr-profile repository](https://github.com/childmetrix/cfsr-profile) for data processing details.

## Running the Platform

### Local Development

**Option 1: Static HTML (no Shiny)**
```bash
# Open in browser
file:///D:/repo_childmetrix/cm-reports/index.html
```

**Option 2: With Shiny Server**
1. Start Shiny Server
2. Configure app location in `/etc/shiny-server/shiny-server.conf`
3. Navigate to platform via file:// or http://localhost

### Production Deployment

Requirements:
- Web server for static HTML (Apache, Nginx, or file://)
- Shiny Server for interactive dashboards
- Access to data processing repositories

## Adding a New State

1. **Create state folder:**
   ```bash
   mkdir -p states/{state_code}
   ```

2. **Copy template structure from existing state:**
   ```bash
   cp -r states/md/* states/{state_code}/
   ```

3. **Update state-specific content:**
   - `states/{state_code}/index.html` - Update branding, navigation
   - `states/{state_code}/_assets/` - Add state logo, letterhead

4. **Update landing page:**
   - Add state to dropdown in root `index.html`

5. **Set up data pipeline:**
   - Create ShareFile folder: `S:/Shared Folders/{state_code}/`
   - Configure data processing scripts for new state

## Development

### Scripts Folder

The `scripts/` folder contains development utilities:
- `move_period_selector.py` - Utility for HTML manipulation
- Add other one-time migration or utility scripts here

### State-Specific Development

Primary development occurs in `states/md/` (Maryland):
- Test new features in MD first
- Migrate successful patterns to other states
- Keep state-specific customizations in respective folders

## Related Repositories

- **[cfsr-profile](https://github.com/childmetrix/cfsr-profile)** - CFSR data processing
- **[utilities-core](D:/repo_childmetrix/utilities-core/)** - Generic R utilities
- **[utilities-cfsr](D:/repo_childmetrix/utilities-cfsr/)** - CFSR-specific functions

## Technology Stack

- **Frontend**: HTML5, Tailwind CSS, JavaScript
- **Interactive Dashboards**: R Shiny, Plotly
- **Data Processing**: R, tidyverse
- **Storage**: Local files, ShareFile cloud storage

## Naming Conventions

Following ChildMetrix standards:
- **State codes**: Lowercase 2-letter codes (`md`, `ky`, `mi`)
- **Folder names**: kebab-case (`cfsr-profile`, `data-dictionary`)
- **File names**: snake_case for scripts, lowercase for HTML

## Recent Changes

**November 2025**
- Reorganized into `states/` folder structure for scalability
- Created `scripts/` folder for development utilities
- Removed backup files (now using git history)
- Removed obsolete implementation documentation
- Updated paths throughout platform

**October 2025**
- Integrated CFSR interactive Shiny dashboard
- Added tertiary navigation for CFSR performance section
- Created multi-state architecture

## Documentation

- **Main Platform**: This README
- **Maryland State**: [states/md/README.md](states/md/README.md)
- **CFSR Integration**: [states/md/cfsr/performance/README.md](states/md/cfsr/performance/README.md)

---

**Organization**: [ChildMetrix](https://github.com/childmetrix)
**Last Updated**: November 2025
