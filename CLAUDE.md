# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ChildMetrix Reports** is a multi-state child welfare reporting platform deployed as a static website. State agencies access standardized reports (CFSR, CPS, In-Home Services, Out-of-Home) through state-specific hubs.

## Architecture

### Site Structure

```
/                    → Landing page with state selector + login preview
/{state}/            → State hub (e.g., /md/, /ky/)
/{state}/{category}/ → Report category (cfsr, cps, in_home, ooh)
/{state}/{category}/{period}/ → Specific report period
```

### Technology Stack

- **Pure static HTML/CSS/JavaScript** - No build system, no bundler, no package.json
- **Tailwind CSS via CDN** - Loaded from `https://cdn.tailwindcss.com`
- **Client-side routing** - JavaScript state selector in `index.html` routes to state hubs
- **Shared assets** - `/_assets/` contains logo and shared resources

### State Routing

The landing page (`index.html`) uses a `STATE_ROUTES` object to map state codes to their hub directories:

```javascript
const STATE_ROUTES = {
  MD: '/md/',
  KY: '/ky/',
  // Add new states here
};
```

Unknown states fallback to `/{state-lowercase}/` pattern.

### Report Organization Pattern

Each state follows this hierarchical structure:

```
{state}/
├── index.html              # State hub with category navigation
├── _assets/                # State-specific assets (if any)
├── cfsr/
│   ├── index.html         # Redirects to /current/ via meta refresh
│   ├── current/           # Symlink or latest period reports
│   ├── archive/           # Historical reports index
│   └── {YYYY_MM}/         # Dated report folders (e.g., 2025_08/)
├── cps/
├── in_home/
└── ooh/
```

Each category's `index.html` auto-redirects to `current/` using:
```html
<meta http-equiv="refresh" content="0; url=/md/cfsr/current/">
```

### Styling & Branding

**Color Palette** (defined in `index.html` and `style.css`):
- Primary: `#0f4c75` (deep blue)
- Accent: `#0e9ba4` (teal)
- Background: `#f9fafb` (light gray)
- Card surface: `#ffffff`
- Muted text: `#64748b` / `#6b7280`

**Responsive Sidebar** (Maryland hub):
- Desktop: Expands/collapses between 160px (w-40) and 64px (w-16)
- Mobile: Fixed overlay drawer that slides in/out
- JavaScript toggles `.expanded` / `.collapsed` classes

## Deployment

### Deploy to Staging

```powershell
# Full site deploy
.\deploy-stage.ps1

# Maryland only (faster iteration)
.\deploy-stage.ps1 -MdOnly

# Custom server/path
.\deploy-stage.ps1 -Server "other.server.com" -RemotePath "/var/www/html"
```

**What it does:**
1. Creates timestamped backup on server: `~/deploy-backups/html-{timestamp}.tar.gz`
2. Uses `scp` to sync files to `stage.childmetrix.com:/var/www/stage.childmetrix.com/html/`
3. Requires SSH key authentication as `root@stage.childmetrix.com`

### Target Server
- **Staging URL**: `https://stage.childmetrix.com`
- **Auth**: Server-level HTTP auth protects staging; app login is UI preview only

## Development Workflow

### Adding a New State

1. **Create state directory**: `/{state-code}/`
2. **Add to STATE_ROUTES** in `index.html`:
   ```javascript
   const STATE_ROUTES = {
     MD: '/md/',
     KY: '/ky/',
     TX: '/tx/',  // Add here
   };
   ```
3. **Create state hub** `/{state}/index.html` with navigation to report categories
4. **Create report category structure**: `cfsr/`, `cps/`, `in_home/`, `ooh/`
5. **Update deploy script** if state needs special handling

### Adding a New Report Period

1. Create dated folder: `/{state}/{category}/{YYYY_MM}/`
2. Add report content as `index.html` in that folder
3. Update `current/` to point to the new period (symlink or copy)
4. Optionally add old period to `archive/index.html`

### File Naming Conventions

- **Backup files**: `.bak`, `.save`, `.backup.{timestamp}` (gitignored)
- **Active files**: `index.html`, `style.css`
- **Period folders**: `YYYY_MM` format (e.g., `2025_08`)
- **Special folders**: `current/`, `archive/`

### Git Settings

Line endings normalized to LF in repository via `.gitattributes`:
- Text files (HTML, CSS, JS, MD): `eol=lf`
- Windows checkouts may convert to CRLF if `core.autocrlf=true`

## Key Files

- **`index.html`** - Landing page with state selector and routing logic
- **`style.css`** - Shared stylesheet (lightweight ChildMetrix theme)
- **`deploy-stage.ps1`** - Deployment automation script
- **`md/index.html`** - Maryland hub (reference implementation with advanced UI)
- **`ky/index.html`** - Kentucky hub (simpler tile-based navigation)

## CFSR Shiny Apps

The `shared/cfsr/` directory contains interactive R Shiny dashboards that are embedded into state CFSR pages via iframes.

### App Structure

```
shared/cfsr/
├── data/                               # RDS data files from cfsr-profile extraction
│   ├── {STATE}_cfsr_profile_rsp_{YYYY_MM}.rds
│   └── {STATE}_cfsr_profile_observed_{YYYY_MM}.rds
├── measures/
│   ├── app_national/                   # National comparison app (port 3838)
│   ├── app_rsp/                        # Risk-Standardized Performance (port 3839)
│   │   ├── app.R                       # Main app logic
│   │   └── global.R                    # Data loading and global variables
│   ├── app_observed/                   # Observed Performance (port 3841)
│   │   ├── app.R
│   │   └── global.R
│   ├── cfsr_profile_rsp.html           # Iframe wrapper for RSP app
│   └── cfsr_profile_observed.html      # Iframe wrapper for observed app
├── summary/
│   └── app_summary/                    # Performance summary app (port 3840)
└── launch_cfsr_dashboard.R             # Multi-app launcher script
```

### Data Pipeline

**Source**: Data is extracted from CFSR 4 Data Profile PDFs using the `cfsr-profile` repository
**Output**: RDS files are saved to `shared/cfsr/data/` for consumption by Shiny apps
**Format**: Each RDS contains state-specific indicator data with period, performance metrics, and metadata

### Running CFSR Apps Locally

```r
# Launch all CFSR apps simultaneously on different ports
source("D:/repo_childmetrix/cm-reports/shared/cfsr/launch_cfsr_dashboard.R")
```

This starts:
- **National comparison**: http://localhost:3838
- **RSP app**: http://localhost:3839
- **Summary app**: http://localhost:3840
- **Observed Performance**: http://localhost:3841

Apps run in background R processes and can be stopped via the launcher script.

### App Integration

**Embedding pattern**: Static HTML pages embed Shiny apps via iframes
```html
<iframe src="http://localhost:3839/?state=MD&profile=2025_02"
        style="width: 100%; height: calc(100vh - 100px); border: none;">
</iframe>
```

**URL parameters**:
- `state`: State code (e.g., MD, KY)
- `profile`: Profile period in YYYY_MM format (e.g., 2025_02)

### Color Palette (Shiny Apps)

Apps use a consistent blue/teal palette matching the static site:
- **Primary blue**: `#1C7ED6`
- **Teal accent**: `#0e9ba4`
- **Warning (DQ)**: `#f59e0b` (amber)
- **Better than national**: `#16a34a` (green)
- **Worse than national**: `#dc2626` (red)

## Integration with cfsr-profile Repository

The `cfsr-profile` repository (D:\repo_childmetrix\cfsr-profile\) contains extraction scripts that:
1. Parse CFSR 4 Data Profile PDFs (from ShareFile)
2. Extract RSP and observed performance data
3. Save processed RDS files to `cm-reports/shared/cfsr/data/`

**Workflow**: PDF extraction → RDS output → Shiny app consumption → iframe embedding in static pages

## Notes

- **Static + Dynamic Hybrid**: Static HTML site with embedded Shiny apps for interactive dashboards
- **No JavaScript framework** - Vanilla JS for navigation and UI interactions
- **Mobile-first responsive** - Tailwind utilities + custom media queries for sidebar
- **Accessibility**: Form inputs use proper labels, buttons have aria-labels
- **Preview mode**: Current login form is non-functional UI preview; production will integrate real auth
- **Multi-app architecture**: Shiny apps run on separate ports and are embedded via iframes for modularity
