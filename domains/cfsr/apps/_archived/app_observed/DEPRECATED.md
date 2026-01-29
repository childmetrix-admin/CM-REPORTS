# DEPRECATED

**Status:** This app has been deprecated and consolidated into `app_measures`.

**Date:** 2025-01-29

**Reason:** The CFSR domain has been restructured from 4 separate apps to 2 apps:
- `app_summary` (port 3840) - For Summary tab content
- `app_measures` (port 3838) - Consolidated National, RSP, and Observed performance into one app with built-in sidebar navigation

**Replacement:** Use `app_measures` instead.

**Do not delete:** This app is kept for reference but should not be actively used or maintained.

**Launch new apps:**
```r
source("D:/repo_childmetrix/cm-reports/domains/cfsr/launch_cfsr_apps.R")
```
