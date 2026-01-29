# DEPRECATED

This app has been consolidated into `app_cfsr`.

See: `domains/cfsr/apps/app_cfsr/`

Migration date: January 29, 2026

## New URL

To access the National Comparison view in the unified app:

```
http://localhost:3838/?state=MD&profile=2025_02&view=national
```

## Changes

- Port: 3838 (same)
- Added `view=national` parameter
- All functionality preserved
- Same UI and modules

## Rollback

If you need to use this app temporarily, run:

```r
shiny::runApp("domains/cfsr/apps/app_national", port = 3838)
```
