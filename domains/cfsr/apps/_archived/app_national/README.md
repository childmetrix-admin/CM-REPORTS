# CFSR Statewide Data Indicators - Shiny Dashboard

Interactive dashboard for exploring state-by-state performance on CFSR indicators.

---

## 📋 Development Status

**✅ Phase 1 - Completed:**
- Shiny app structure with `shinydashboard`
- State detection from URL path
- Data preparation functions
- **Maltreatment in Care** detailed page (proof of concept)

**✅ Phase 2 - Completed:**
- Reusable indicator page module (`modules/indicator_page.R`)
- **All 8 indicator detailed pages**:
  - Entry Rate
  - Maltreatment in Care
  - Permanency in 12 months (entries)
  - Permanency in 12 months (12-23 months)
  - Permanency in 12 months (24+ months)
  - Placement Stability
  - Reentry to Foster Care
  - Recurrence of Maltreatment
- Complete left navigation with Safety/Permanency/Well-Being categories
- **Data Dictionary page** with searchable, sortable table

**✅ Phase 3 - Completed:**
- **Overview page** with small multiples (8 charts in grid layout)
  - Charts organized by category (Safety, Permanency, Well-Being)
  - Shows top 10 states + selected state per indicator
  - Compact visualization for quick comparison
- **Previous/Next navigation** on all indicator pages
  - Smart navigation buttons with indicator labels
  - JavaScript-based sidebar navigation
  - Automatically shows/hides based on position

**🔮 Coming in Phase 4:**
- Deploy to DigitalOcean
- Configure nginx reverse proxy
- Test on reports.childmetrix.com
- Document update process

---

## 🚀 Quick Start

### Prerequisites

```r
install.packages(c("shiny", "shinydashboard", "plotly", "DT", "dplyr", "tidyr", "ggplot2"))
```

### Step 1: Prepare Data

First, run the main R script to generate the CSV:
```r
setwd("D:/repo_childmetrix/r_cfsr_profile")
source("code/r_cfsr_profile.R")
```

Then prepare data for Shiny:
```r
setwd("D:/repo_childmetrix/r_cfsr_profile/shiny_app")
source("prepare_app_data.R")
```

This creates `data/cfsr_indicators_latest.rds`.

### Step 2: Run App

```r
library(shiny)
runApp("D:/repo_childmetrix/r_cfsr_profile/shiny_app")
```

Or in RStudio: Open `app.R` and click "Run App"

### Step 3: Test State Detection

**Test URLs** (when running locally):
- Default: `http://127.0.0.1:XXXX/` → Defaults to Maryland
- With state: `http://127.0.0.1:XXXX/?state=md` → Maryland highlighted
- Different state: `http://127.0.0.1:XXXX/?state=ca` → California highlighted

**Note**: For full URL path detection (`/md/cfsr-indicators`), you'll need to deploy with nginx reverse proxy.

---

## 📁 File Structure

```
shiny_app/
├── app.R                          # Main Shiny application
├── global.R                       # Libraries, data loading, globals
├── prepare_app_data.R             # Data preparation script
├── README.md                      # This file
│
├── functions/
│   ├── utils.R                    # URL parsing, state detection
│   ├── data_prep.R                # Data filtering, sorting
│   └── chart_builder.R            # Plotly chart generation
│
├── modules/                       # (Future: Shiny modules)
│
├── data/
│   └── cfsr_indicators_latest.rds # Pre-processed data (generated)
│
└── www/                           # Static assets
    └── custom.css                 # (Future: Custom styling)
```

---

## 🎨 Current Features

### Overview Page
- ✅ **Small multiples grid** showing all 8 indicators
- ✅ **Category organization** (Safety, Permanency, Well-Being)
- ✅ **Top 10 states** + selected state per chart
- ✅ **Compact 300px charts** optimized for quick scanning
- ✅ **Target lines** shown where applicable
- ✅ **State highlighting** (selected state in blue)
- ✅ **Consistent styling** across all charts

### Indicator Detail Pages

#### Chart Features
- ✅ 52 states sorted by performance (best at top)
- ✅ State highlighting (#4472C4 for user's state, #D3D3D3 for others)
- ✅ Target line (#87D180 dashed) showing national standard
- ✅ Data labels on bars
- ✅ Tooltips showing:
  - State name
  - Performance value
  - Numerator
  - Denominator
  - Rank

#### Navigation Features
- ✅ **Previous/Next buttons** between indicators
- ✅ **Smart button visibility** (only show when applicable)
- ✅ **Indicator labels** on navigation buttons
- ✅ **Icon indicators** (arrows for direction)

#### Metadata Display
- ✅ Title from dictionary (full indicator name)
- ✅ Period (e.g., "Oct '23 - Sep '24")
- ✅ Description from dictionary
- ✅ Target line subtitle (when applicable)
- ✅ Source citation footnote

#### Collapsible Sections
- ✅ **Measure Details** (collapsed by default):
  - Category
  - National standard
  - Desired direction
  - Denominator definition
  - Numerator definition
  - Risk adjustment
  - Exclusions
  - Notes

- ✅ **Data Table** (collapsed by default):
  - Sortable columns
  - Searchable
  - Export to: Copy, CSV, Excel
  - Formatted numbers

---

## 🧪 Testing Checklist

### Test 1: Data Loading
- [ ] Run `prepare_app_data.R` successfully
- [ ] `data/cfsr_indicators_latest.rds` created
- [ ] Check console for row counts and indicators

### Test 2: App Launch
- [ ] App launches without errors
- [ ] Maltreatment page loads
- [ ] Chart displays 52 states

### Test 3: State Detection
- [ ] Default state is Maryland (if no URL param)
- [ ] Maryland bar is blue (#4472C4)
- [ ] Other bars are grey (#D3D3D3)
- [ ] Change URL param `?state=ca` → California highlights

### Test 4: Chart Features
- [ ] States sorted correctly (lowest at top for maltreatment)
- [ ] Target line appears (dashed green)
- [ ] Data labels show on bars
- [ ] Hover tooltip shows all info (state, performance, num, den, rank)

### Test 5: Metadata
- [ ] Title shows full indicator name
- [ ] Period shows in format "Oct 'YY - Sep 'YY, FY YYYY"
- [ ] Description displays
- [ ] Target subtitle shows "< 9.07 per 100,000 days"
- [ ] Source footnote at bottom

### Test 6: Collapsible Sections
- [ ] Both sections collapsed by default
- [ ] Click "Measure Details" → expands
- [ ] All metadata fields populated
- [ ] Click "View Data Table" → expands
- [ ] Table shows all 52 states
- [ ] Export buttons work (CSV, Excel, Copy)
- [ ] Can sort by clicking column headers

---

## 🐛 Troubleshooting

### Error: "No data found"
**Solution**: Run `r_cfsr_profile.R` first to generate CSV, then `prepare_app_data.R`

### Error: "Dictionary not found"
**Solution**: Ensure `code/cfsr_round4_indicators_dictionary.csv` exists

### State not highlighting
**Solution**: Check URL parameter format: `?state=md` (lowercase, 2-letter code)

### Chart not displaying
**Solution**: Check browser console for JavaScript errors. Try refreshing page.

### Data table buttons not showing
**Solution**: Ensure `DT` package is installed: `install.packages("DT")`

---

## 🚀 Deployment to DigitalOcean

### Install Shiny Server

```bash
# Install R
sudo apt-get update
sudo apt-get install r-base r-base-dev

# Install Shiny Server
sudo su - -c "R -e \"install.packages('shiny', repos='https://cran.rstudio.com/')\""
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
sudo gdebi shiny-server-1.5.20.1002-amd64.deb
```

### Install Required Packages

```bash
sudo su - -c "R -e \"install.packages(c('shinydashboard', 'plotly', 'DT', 'dplyr', 'tidyr', 'ggplot2'), repos='https://cran.rstudio.com/')\""
```

### Deploy App

```bash
# Copy app to Shiny Server directory
sudo cp -r /path/to/shiny_app /srv/shiny-server/cfsr-indicators

# Set permissions
sudo chown -R shiny:shiny /srv/shiny-server/cfsr-indicators

# Restart Shiny Server
sudo systemctl restart shiny-server
```

### Configure Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/reports.childmetrix.com

location /md/cfsr-indicators/ {
    proxy_pass http://127.0.0.1:3838/cfsr-indicators/;
    proxy_redirect http://127.0.0.1:3838/ $scheme://$host/md/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 20d;
}

location /ca/cfsr-indicators/ {
    proxy_pass http://127.0.0.1:3838/cfsr-indicators/;
    proxy_redirect http://127.0.0.1:3838/ $scheme://$host/ca/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 20d;
}
```

Then reload nginx:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📊 Data Update Workflow

### Every 6 Months:

1. **Update source data**
   ```r
   # Copy new "National - Supplemental Context Data - [Month YYYY].xlsx"
   # to data/YYYY_MM/raw/
   ```

2. **Run processing script**
   ```r
   setwd("D:/repo_childmetrix/r_cfsr_profile")
   source("code/r_cfsr_profile.R")
   ```

3. **Prepare for Shiny**
   ```r
   setwd("shiny_app")
   source("prepare_app_data.R")
   ```

4. **Deploy updated data**
   ```bash
   # Copy new RDS file to server
   scp data/cfsr_indicators_latest.rds user@server:/srv/shiny-server/cfsr-indicators/data/

   # Restart Shiny Server
   ssh user@server 'sudo systemctl restart shiny-server'
   ```

---

## 🎯 Next Steps (Phase 4 - Deployment)

1. **Deploy to DigitalOcean**
   - Install Shiny Server on droplet
   - Install required R packages
   - Copy app files to `/srv/shiny-server/cfsr-indicators`

2. **Configure nginx reverse proxy**
   - Set up state-specific URLs (e.g., `/md/cfsr-indicators`, `/ca/cfsr-indicators`)
   - Configure WebSocket support for Shiny
   - Set up SSL certificates

3. **Testing**
   - Test state detection from URL paths
   - Verify all navigation flows
   - Test on multiple browsers
   - Performance testing with multiple concurrent users

4. **Documentation**
   - Create deployment checklist
   - Document data update process
   - Create troubleshooting guide

---

## 📝 Notes

- **Performance**: RDS file loads faster than CSV (~10x for large datasets)
- **Sorting**: Uses `direction_desired` from dictionary (some "up", some "down")
- **Target lines**: Only shown for indicators with `national_standard` value
- **State codes**: 2-letter codes automatically converted to full names
- **Browser compatibility**: Tested in Chrome, Firefox, Safari

---

## 📚 Resources

- [Shiny Documentation](https://shiny.rstudio.com/)
- [shinydashboard Guide](https://rstudio.github.io/shinydashboard/)
- [Plotly R Documentation](https://plotly.com/r/)
- [DT Package Documentation](https://rstudio.github.io/DT/)

---

**Questions?** Check the main project README or FUNCTION_USAGE_GUIDE.md
