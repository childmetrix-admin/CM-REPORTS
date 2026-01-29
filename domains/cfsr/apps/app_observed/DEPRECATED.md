# DEPRECATED

This app has been consolidated into `app_cfsr`.

See: `domains/cfsr/apps/app_cfsr/`

Migration date: January 29, 2026

## New URL

To access the Observed Performance view in the unified app:

```
http://localhost:3838/?state=MD&profile=2025_02&view=observed&indicator=overview
```

## Changes

- Port: 3841 → 3838
- Added `view=observed` parameter
- Internal routing: `?view=` renamed to `?indicator=` to avoid conflict
- All functionality preserved
- Same KPI cards and indicator detail tabs

## URL Parameter Change

**Old (app_observed standalone):**
```
http://localhost:3841/?state=MD&view=overview
http://localhost:3841/?state=MD&view=entry_rate
```

**New (unified app):**
```
http://localhost:3838/?state=MD&view=observed&indicator=overview
http://localhost:3838/?state=MD&view=observed&indicator=entry_rate
```

## Rollback

If you need to use this app temporarily, run:

```r
shiny::runApp("domains/cfsr/apps/app_observed", port = 3841)
```
