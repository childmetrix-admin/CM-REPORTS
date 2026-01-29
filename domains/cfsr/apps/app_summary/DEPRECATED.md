# DEPRECATED

This app has been consolidated into `app_cfsr`.

See: `domains/cfsr/apps/app_cfsr/`

Migration date: January 29, 2026

## New URL

To access the Performance Summary view in the unified app:

```
http://localhost:3838/?state=MD&profile=2025_02&view=summary
```

## Changes

- Port: 3840 → 3838
- Added `view=summary` parameter
- All functionality preserved
- Same performance table and download feature

## Rollback

If you need to use this app temporarily, run:

```r
shiny::runApp("domains/cfsr/apps/app_summary", port = 3840)
```
