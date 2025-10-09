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

## Notes

- **No JavaScript framework** - Vanilla JS for navigation and UI interactions
- **No server-side code** - Pure static hosting
- **Mobile-first responsive** - Tailwind utilities + custom media queries for sidebar
- **Accessibility**: Form inputs use proper labels, buttons have aria-labels
- **Preview mode**: Current login form is non-functional UI preview; production will integrate real auth
