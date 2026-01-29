# DEPRECATED

This app has been consolidated into `app_cfsr`.

See: `domains/cfsr/apps/app_cfsr/`

Migration date: January 29, 2026

## New URL

To access the RSP (Risk-Standardized Performance) view in the unified app:

```
http://localhost:3838/?state=MD&profile=2025_02&view=rsp
```

## Changes

- Port: 3839 → 3838
- Added `view=rsp` parameter
- All functionality preserved
- Same KPI cards and CI charts

## Rollback

If you need to use this app temporarily, run:

```r
shiny::runApp("domains/cfsr/apps/app_rsp", port=3839)
```
