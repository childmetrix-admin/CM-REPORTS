# CFSR Dashboard Deployment Checklist

## Pre-Deployment Checklist

### ✅ Files in Place

- [ ] Shiny app files copied to `r_cm_reports/md/cfsr/performance/app/`
- [ ] Wrapper HTML exists: `r_cm_reports/md/cfsr/performance/index_static.html`
- [ ] Main navigation updated in `r_cm_reports/md/index.html`
- [ ] Data file exists: `r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`

### ✅ Data Processing Setup

- [ ] Profile period set in `r_cfsr_profile.R`: `profile_period <- "2025_02"`
- [ ] Raw data file in place: `r_cfsr_profile/data/2025_02/raw/National - Supplemental Context Date - February 2025.xlsx`
- [ ] Run `r_cfsr_profile.R` successfully
- [ ] Verify RDS saved to BOTH locations:
  - `r_cfsr_profile/shiny_app/data/cfsr_indicators_latest.rds`
  - `r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`

### ✅ Shiny App Configuration

- [ ] `app.R` reads state from URL parameter
- [ ] `global.R` sets correct data path
- [ ] All required packages installed:
  - shiny
  - shinydashboard
  - plotly
  - DT
  - dplyr
  - tidyr
  - ggplot2

## Deployment Options

### Option A: Local Development (No Server)

**Best for:** Testing, development, quick demos

**Steps:**
1. Open R/RStudio
2. Run:
   ```r
   shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 3838)
   ```
3. Open browser to `file:///D:/repo_childmetrix/r_cm_reports/md/index.html`
4. Click "CFSR Data Profile"

**Limitations:**
- Must keep R session running
- Not suitable for production
- Single user only

---

### Option B: Shiny Server (Recommended)

**Best for:** Production deployment, multiple users

**Installation:**

**Windows:**
1. Download Shiny Server from RStudio: https://www.rstudio.com/products/shiny/download-server/
2. Or use Docker (easier on Windows):
   ```bash
   docker run --rm -p 3838:3838 \
     -v D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app:/srv/shiny-server/cfsr \
     rocker/shiny:latest
   ```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install gdebi-core
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
sudo gdebi shiny-server-1.5.20.1002-amd64.deb

# Install R packages system-wide
sudo su - -c "R -e \"install.packages(c('shiny','shinydashboard','plotly','DT','dplyr','tidyr','ggplot2'), repos='https://cran.rstudio.com/')\""
```

**Configuration (`/etc/shiny-server/shiny-server.conf`):**
```
# Define server
server {
  listen 3838 0.0.0.0;

  # Define location for CFSR app
  location /cfsr {
    site_dir /path/to/r_cm_reports/md/cfsr/performance/app;
    log_dir /var/log/shiny-server;
    directory_index on;
  }
}
```

**Start Shiny Server:**
```bash
# Linux
sudo systemctl start shiny-server
sudo systemctl enable shiny-server  # Auto-start on boot

# Windows (Docker)
docker-compose up -d
```

**Access:**
- Shiny app directly: `http://localhost:3838/cfsr/?state=MD`
- Via platform: Open `r_cm_reports/md/index.html` and click "CFSR Data Profile"

---

### Option C: RStudio Connect (Enterprise)

**Best for:** Enterprise deployments with authentication, scheduling, and monitoring

**Requirements:**
- RStudio Connect license
- Server infrastructure

**Deployment:**
1. Install RStudio Connect
2. Deploy app via `rsconnect` package:
   ```r
   rsconnect::deployApp(
     appDir = "D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app",
     appName = "cfsr-performance",
     account = "your-account"
   )
   ```
3. Configure access controls
4. Update `index_static.html` to point to Connect URL

---

### Option D: ShinyProxy (Docker-based)

**Best for:** Containerized deployments, Kubernetes

**Setup:**
1. Create `Dockerfile` in app directory:
   ```dockerfile
   FROM rocker/shiny:latest

   # Install R packages
   RUN R -e "install.packages(c('shiny','shinydashboard','plotly','DT','dplyr','tidyr','ggplot2'))"

   # Copy app files
   COPY . /srv/shiny-server/cfsr

   # Expose port
   EXPOSE 3838

   # Run app
   CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/cfsr', port=3838, host='0.0.0.0')"]
   ```

2. Build and run:
   ```bash
   docker build -t cfsr-dashboard .
   docker run -p 3838:3838 cfsr-dashboard
   ```

## Post-Deployment Testing

### ✅ Functionality Tests

- [ ] App loads without errors
- [ ] Overview page displays state performance table
- [ ] Overview page displays rankings table
- [ ] All 8 indicator pages load
- [ ] Bar charts render correctly
- [ ] Charts show correct state highlighted
- [ ] Data tables display all states
- [ ] CSV download works
- [ ] Navigation between indicators works
- [ ] Data Dictionary tab shows correct information

### ✅ State Parameter Tests

- [ ] Test with `?state=MD` → Shows "Maryland's Performance"
- [ ] Test with `?state=CA` → Shows "California's Performance"
- [ ] Test with no state parameter → Defaults to Maryland
- [ ] Test with invalid state → Falls back to Maryland

### ✅ Profile Period Tests

- [ ] Profile selector shows correct periods
- [ ] Changing period updates URL parameter
- [ ] Dashboard shows correct data for period
- [ ] Profile version displays correctly

### ✅ Integration Tests

- [ ] Load from ChildMetrix platform (`md/index.html`)
- [ ] Click "CFSR Data Profile" in sidebar
- [ ] Verify dashboard loads in iframe
- [ ] Test secondary navigation (Performance/Presentations/Data Dictionary/Notes)
- [ ] Verify profile selector works in integrated view

### ✅ Performance Tests

- [ ] Initial load time < 5 seconds
- [ ] Page navigation smooth
- [ ] Charts render without lag
- [ ] Tables sort/filter responsive
- [ ] No console errors in browser

## Updating for New Profile Periods

### When February 2025 data is released:

1. **Receive data file** from Children's Bureau
2. **Save to raw folder:**
   ```
   r_cfsr_profile/data/2025_02/raw/National - Supplemental Context Date - February 2025.xlsx
   ```
3. **Update R script:**
   ```r
   # r_cfsr_profile.R line 51
   profile_period <- "2025_02"
   ```
4. **Process data:**
   ```r
   source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
   ```
5. **Verify outputs:**
   ```
   ✓ CSV: r_cfsr_profile/data/2025_02/processed/[date]/
   ✓ RDS (DEV): r_cfsr_profile/shiny_app/data/cfsr_indicators_latest.rds
   ✓ RDS (PROD): r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds
   ```
6. **Restart Shiny app/server**
7. **Test with profile selector:** Choose "February 2025"

### When August 2025 data is released:

Repeat above steps with:
- Folder: `r_cfsr_profile/data/2025_08/raw/`
- Profile: `profile_period <- "2025_08"`
- File: `National - Supplemental Context Date - August 2025.xlsx`

## Rollback Plan

If deployment issues occur:

1. **Immediate:** Point navigation back to legacy static HTML:
   ```javascript
   // In md/index.html
   data-target="cfsr/performance/cfsr_md_2025_02.html"  // Old static file
   ```

2. **Restore previous RDS file:**
   ```bash
   # If you backed up previous version
   cp app/data/cfsr_indicators_latest.rds.backup app/data/cfsr_indicators_latest.rds
   ```

3. **Investigate issues** in development environment
4. **Re-deploy** when fixed

## Monitoring

### Logs to Check

**Shiny Server (Linux):**
```bash
# App logs
tail -f /var/log/shiny-server/cfsr-shiny-*.log

# Server logs
tail -f /var/log/shiny-server.log
```

**Docker:**
```bash
docker logs -f [container-id]
```

**R Console (Local):**
- Watch console output for warnings/errors
- Check for package load failures
- Monitor for data loading issues

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| App won't start | Missing packages | Install all required packages |
| Data not loading | Wrong RDS path | Check `global.R` data path |
| State not updating | URL parameter not read | Check `selected_state()` reactive |
| Charts blank | Plotly not installed | `install.packages('plotly')` |
| Tables blank | DT not installed | `install.packages('DT')` |
| 404 in iframe | Wrong path in index_static.html | Check iframe `src` attribute |

## Security Considerations

### For Production Deployment:

- [ ] Enable authentication (Shiny Server Pro, Connect, or custom)
- [ ] Restrict network access to authorized users
- [ ] Use HTTPS for remote access
- [ ] Set appropriate file permissions on data directory
- [ ] Consider data encryption at rest
- [ ] Implement audit logging
- [ ] Regular security updates for Shiny Server

### Firewall Rules:

```bash
# Allow Shiny Server port (example for Linux)
sudo ufw allow 3838/tcp
sudo ufw enable
```

## Backup Strategy

### What to Back Up:

1. **Data files:**
   - `r_cfsr_profile/data/[all periods]/`
   - `r_cm_reports/md/cfsr/performance/app/data/`

2. **Configuration:**
   - `r_cfsr_profile/code/r_cfsr_profile.R`
   - Shiny Server config: `/etc/shiny-server/shiny-server.conf`

3. **Application code:**
   - `r_cm_reports/md/cfsr/performance/app/` (entire directory)

### Backup Schedule:

- **Before each data update:** Backup current RDS file
- **After each deployment:** Backup app directory
- **Weekly:** Backup entire data folder

```bash
# Example backup script
TODAY=$(date +%Y-%m-%d)
tar -czf cfsr-backup-$TODAY.tar.gz \
  r_cm_reports/md/cfsr/performance/app/ \
  r_cfsr_profile/data/
```

## Support Contacts

- **Technical Issues:** [Your contact]
- **Data Issues:** Children's Bureau
- **Shiny Server:** RStudio Support
- **Platform Issues:** ChildMetrix team
