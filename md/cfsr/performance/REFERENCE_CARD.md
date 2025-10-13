# CFSR Dashboard - Reference Card

## Start Dashboard (Every Time)

**Open R or RStudio, then run:**
```r
shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 3838)
```

**Or use the launcher script:**
```r
source("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/launch_cfsr_dashboard.R")
```

**Keep R running!** Don't close the window.

---

## Access Dashboard

**Via Platform (Recommended):**
```
file:///D:/repo_childmetrix/r_cm_reports/md/index.html#/cfsr
```

**Direct Access:**
```
http://localhost:3838/?state=MD
```

---

## Stop Dashboard

**In R console:** Press `Ctrl+C`

**Or:** Close R/RStudio

---

## First Time Only

**Install required packages:**
```r
install.packages(c("shiny", "shinydashboard", "plotly", "DT", "dplyr", "tidyr", "ggplot2"))
```

---

## Update Data

**When new CFSR data is released:**

1. Save Excel file to:
   ```
   D:/repo_childmetrix/r_cfsr_profile/data/2025_02/raw/
   ```

2. Edit `r_cfsr_profile.R` line 51:
   ```r
   profile_period <- "2025_02"
   ```

3. Run in R:
   ```r
   source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
   ```

4. Restart dashboard (Ctrl+C, then run `shiny::runApp(...)` again)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "package 'shiny' not found" | Run: `install.packages("shiny")` |
| Directory listing shown | R is not running. Start it with command above |
| Port 3838 in use | Use different port: `port = 4848` |
| Dashboard shows old data | Update data (see above), then restart |
| No data file error | Run `r_cfsr_profile.R` to generate data |

---

## Common Tasks

### Change State
Add `?state=CA` to URL:
```
http://localhost:3838/?state=CA
```

### Download Data
Click "Download CSV" button on any indicator page

### Switch Profile Period
Use dropdown in dashboard: "February 2025", "August 2025", etc.

---

## File Locations

| What | Where |
|------|-------|
| **Dashboard app** | `D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app/` |
| **Launcher script** | `D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/launch_cfsr_dashboard.R` |
| **Data file** | `D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds` |
| **Data processing** | `D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R` |
| **Platform entry** | `D:/repo_childmetrix/r_cm_reports/md/index.html` |

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Stop dashboard | `Ctrl+C` (in R console) |
| Run script in RStudio | `Ctrl+Shift+S` |
| Reload browser page | `F5` or `Ctrl+R` |

---

## Quick Start (Complete Workflow)

```
1. Open RStudio
   ↓
2. Run: shiny::runApp("D:/repo_childmetrix/.../app", port = 3838)
   ↓
3. See: "Listening on http://127.0.0.1:3838"
   ↓
4. Open browser: file:///D:/repo_childmetrix/r_cm_reports/md/index.html#/cfsr
   ↓
5. Click: "CFSR Data Profile" in sidebar
   ↓
6. Dashboard loads!
```

---

## Support

**Documentation:**
- Quick Start: `QUICK_START.md`
- Full Guide: `README.md`
- Deployment: `DEPLOYMENT.md`

**Questions?**
Check the backlog: `r_cfsr_profile/shiny_app/BACKLOG.md`

---

**Print this card and keep it handy!** 📋
