# CFSR Dashboard - Quick Start Guide

## 🚀 Getting Started in 3 Steps

### Step 1: Open R or RStudio

### Step 2: Run the Shiny App
Copy and paste this command into R:
```r
shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 3838)
```

You should see:
```
Listening on http://127.0.0.1:3838
```

**Keep R running!** Don't close this window.

### Step 3: Access the Dashboard

**Option A: Via ChildMetrix Platform (Recommended)**
1. Open your browser to: `file:///D:/repo_childmetrix/r_cm_reports/md/index.html#/cfsr`
2. The dashboard will load automatically!

**Option B: Direct Access**
1. Open your browser to: `http://localhost:3838/?state=MD`

---

## 💡 What You'll See

When you load the platform, the wrapper page will:
1. Check if localhost:3838 is running
2. If **YES**: Automatically load the dashboard ✅
3. If **NO**: Show helpful instructions with a "Start Shiny" button ⚠️

---

## 🔧 Troubleshooting

### "Shiny Server Not Running" Message

This means R isn't running the app. Go back to Step 2 above.

### Dashboard Shows Directory Listing

The old version (`index_static.html`) tried to use `file://` protocol which doesn't work.
The new version (`index_auto.html`) detects localhost:3838 and shows instructions if not running.

### Port 3838 Already in Use

Someone else is using that port. Try a different port:
```r
shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 4848)
```

Then access at: `http://localhost:4848/?state=MD`

### Missing Packages Error

Install required packages:
```r
install.packages(c("shiny", "shinydashboard", "plotly", "DT", "dplyr", "tidyr", "ggplot2"))
```

---

## 📊 Features

### Navigation
- **Sidebar:** Click "CFSR Data Profile"
- **Secondary Nav:** Click "Performance" to view dashboard
- **Profile Selector:** Choose August 2025, February 2025, or August 2024

### State Selection
The dashboard automatically shows Maryland's data by default.
To see a different state, add `?state=CA` to the URL.

### Data Download
Every indicator page has a "Download CSV" button to export the data.

---

## 🔄 Updating Data

When new CFSR data is released:

1. **Place raw file:**
   ```
   D:/repo_childmetrix/r_cfsr_profile/data/2025_02/raw/
   National - Supplemental Context Date - February 2025.xlsx
   ```

2. **Edit profile period:**
   ```r
   # In r_cfsr_profile.R line 51
   profile_period <- "2025_02"
   ```

3. **Run data processing:**
   ```r
   source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
   ```

4. **Restart the Shiny app** (Ctrl+C in R, then run again)

5. **Refresh browser** to see new data

---

## 📁 File Reference

| File | Purpose |
|------|---------|
| `index_auto.html` | **Main wrapper** - Auto-detects localhost, shows instructions if needed |
| `index_static.html` | Old version - Requires Shiny Server |
| `index.html` | Alternative - For localhost dev |
| `launch_local.html` | Detailed instructions page |
| `app/` | The Shiny application directory |

---

## ❓ Need More Help?

- **Full Documentation:** See [README.md](README.md)
- **Deployment Guide:** See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Integration Details:** See [INTEGRATION_SUMMARY.md](INTEGRATION_SUMMARY.md)
- **Issues/Features:** See `r_cfsr_profile/shiny_app/BACKLOG.md`

---

## ✨ Tips

### Keep R Running
The Shiny app must stay running for the dashboard to work. If you close R, the dashboard will stop working.

### Use RStudio
RStudio makes it easy to run the app and see console output.

### Test State Parameter
Try different states:
- `http://localhost:3838/?state=CA` (California)
- `http://localhost:3838/?state=TX` (Texas)
- `http://localhost:3838/?state=NY` (New York)

### Access from Other Computers
If you want to access the dashboard from another computer on your network:
1. Find your IP address: `ipconfig` (Windows) or `ifconfig` (Mac/Linux)
2. Use `http://YOUR-IP:3838/?state=MD` from other computer
3. Make sure firewall allows port 3838

---

## 🎯 Common Workflows

### Daily Use
```
1. Open R/RStudio
2. Run: shiny::runApp("...", port = 3838)
3. Open browser to platform URL
4. Dashboard loads automatically!
```

### Update Data
```
1. Get new Excel file from Children's Bureau
2. Save to r_cfsr_profile/data/[period]/raw/
3. Update profile_period in r_cfsr_profile.R
4. Run: source("r_cfsr_profile.R")
5. Restart Shiny app
6. Refresh browser
```

### Share with Colleagues
```
Option 1: Share your screen while app is running
Option 2: Set up Shiny Server for multi-user access
Option 3: Deploy to RStudio Connect (enterprise)
```

---

**That's it! You're ready to use the CFSR Dashboard.** 🎉
