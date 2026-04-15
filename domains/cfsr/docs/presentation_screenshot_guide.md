# CFSR PowerPoint Presentation - Screenshot Workflow Guide

This guide explains how to capture and insert screenshots into the auto-generated PowerPoint presentations for CFSR profile data.

## Overview

The PowerPoint generation script creates slides with screenshot placeholders. You'll manually:
1. Launch the CFSR Shiny apps
2. Navigate to specific views
3. Capture screenshots
4. Insert screenshots into the PowerPoint placeholders

**Estimated time:** 15-20 minutes per presentation

---

## Step 1: Generate PowerPoint with Placeholders

Run the extraction workflow to generate the PowerPoint file with screenshot placeholders:

```r
# From the cm-reports repo root in R:
source("domains/cfsr/extraction/run_profile.R")

# For a specific state/period:
run_profile(state = "md", period = "2025_02", source = "all")

# For all available states/periods:
run_profile(source = "all")
```

**Output location:** `states/{state}/cfsr/presentations/{period}/{STATE}_CFSR_Presentation_{period}.pptx`

**Example:** `states/md/cfsr/presentations/2025_02/MD_CFSR_Presentation_2025_02.pptx`

---

## Step 2: Open the dashboards (production or local)

**Production (Azure Container Apps)** — use these bases for screenshots when capturing against live environments (override via `CM_PUBLIC_SUMMARY_URL` / `CM_PUBLIC_MEASURES_URL` in `.env` if needed):

- **Summary:** `https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io`
- **Measures:** `https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io`

**Local development** — run from R:

```r
source("domains/cfsr/launch_cfsr_apps.R")
```

This launches:

- **Measures:** `http://localhost:3838` (default; console shows if different)
- **Summary:** `http://localhost:3840`

---

## Step 3: Capture Screenshots

### Required Screenshots (in order):

1. **Summary App** (full page)
2. **RSP Overview** (KPI cards only)
3. **Observed Overview** (KPI cards only)
4. **Entry Rate - By State chart** (horizontal bar chart)
5. **Maltreatment in Care - By State chart**
6. **Maltreatment Recurrence - By State chart**
7. **Permanency in 12 Months (Entries) - By State chart**
8. **Permanency in 12 Months (12-23 months) - By State chart**
9. **Permanency in 12 Months (24+ months) - By State chart**
10. **Reentry to Foster Care - By State chart**
11. **Placement Stability - By State chart**

---

### Screenshot Instructions by Slide

Each PowerPoint slide includes a placeholder with the exact URL to navigate to. Here's the full list:

#### 1. Summary App (Slide 4)

**Production URL:** `https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state={STATE}&profile={PERIOD}`  
**Example:** `https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state=MD&profile=2025_02`  
**Local URL:** `http://localhost:3840/?state=MD&profile=2025_02`

**What to capture:**
- Full page view of the summary app
- All KPI cards visible
- Both RSP and Observed sections

**Screenshot method:**
- Windows: `Win + Shift + S` → Select rectangular area
- Mac: `Cmd + Shift + 4` → Click and drag
- Save as: `{state}_summary_app_{period}.png`
  Example: `md_summary_app_2025_02.png`

---

#### 2. RSP Overview (Slide 5)

**Production URL (Measures app, Overview → Risk Standardized Performance):**  
`https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state={STATE}&profile={PERIOD}&tab=overview&overview_tab=rsp`  
**Example:** `https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state=MD&profile=2025_02&tab=overview&overview_tab=rsp`  
**Local:** `http://localhost:3838/?state=MD&profile=2025_02&tab=overview&overview_tab=rsp`

**What to capture:**
- KPI cards section only (not the full page)
- All 8 indicator cards visible

**Screenshot method:**
- Focus on the KPI cards grid
- Save as: `{state}_rsp_overview_{period}.png`
  Example: `md_rsp_overview_2025_02.png`

---

#### 3. Observed Overview (Slide 6)

**Production URL (Measures app, Overview → Observed Performance):**  
`https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state={STATE}&profile={PERIOD}&tab=overview&overview_tab=obs`  
**Example:** `https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state=MD&profile=2025_02&tab=overview&overview_tab=obs`  
**Local:** `http://localhost:3838/?state=MD&profile=2025_02&tab=overview&overview_tab=obs`

**What to capture:**
- KPI cards section only
- All 8 indicator cards visible

**Screenshot method:**
- Focus on the KPI cards grid
- Save as: `{state}_observed_overview_{period}.png`
  Example: `md_observed_overview_2025_02.png`

---

#### 4-11. Individual Indicator Charts (Slides 8-15)

Open the **Measures** app, set `state` and `profile` in the URL, then use the **left sidebar** to open each indicator (Entry rate, Maltreatment in care, etc.). Deep links use `?tab=obs_*` (see `app_measures` `tabName` values).

**Production base:**  
`https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io/?state=MD&profile=2025_02`

**Example deep links (production):**

1. **Foster care entry rate** — add `&tab=obs_entry_rate` to the base URL above.
2. **Maltreatment in care** — `&tab=obs_maltreatment`
3. **Maltreatment recurrence** — `&tab=obs_recurrence`
4. **Permanency in 12 months (entries)** — `&tab=obs_perm12_entries`
5. **Permanency (12-23 months)** — `&tab=obs_perm12_12_23`
6. **Permanency (24+ months)** — `&tab=obs_perm12_24`
7. **Reentry** — `&tab=obs_reentry`
8. **Placement stability** — `&tab=obs_placement`

**Local:** same query parameters against `http://localhost:3838/`.

**Filenames (examples):** `md_entry_rate_2025_02.png`, `md_maltreatment_in_care_2025_02.png`, etc.

**What to capture for each:**
- The "By State" horizontal bar chart
- Include state name in focused bar (highlighted in blue)
- Include national standard line (green dashed line)
- Capture from chart title to source footnote

**Screenshot method:**
- Navigate to the "By State" tab for each indicator
- Capture the chart area
- Save with descriptive filename

---

## Step 4: Save Screenshots

**Save location:** `states/{state}/cfsr/presentations/{period}/screenshots/`

**Example:**
```
states/
└── md/
    └── cfsr/
        └── presentations/
            └── 2025_02/
                ├── MD_CFSR_Presentation_2025_02.pptx
                └── screenshots/
                    ├── md_summary_app_2025_02.png
                    ├── md_rsp_overview_2025_02.png
                    ├── md_observed_overview_2025_02.png
                    ├── md_entry_rate_2025_02.png
                    ├── md_maltreatment_in_care_2025_02.png
                    └── ... (remaining 6 indicator screenshots)
```

**File format:** PNG (recommended for web screenshots)
**Resolution:** Use your screen's native resolution (1920x1080 or higher)

---

## Step 5: Insert Screenshots into PowerPoint

1. **Open the generated PowerPoint:**
   - Location: `states/{state}/cfsr/presentations/{period}/{STATE}_CFSR_Presentation_{period}.pptx`

2. **For each slide with a placeholder:**
   - Slide will say: `[INSERT SCREENSHOT: Description]`
   - Right-click the placeholder text box
   - Select **"Change Picture"** → **"From File..."**
   - Navigate to the screenshots folder
   - Select the corresponding screenshot file
   - PowerPoint will auto-fit the image to the placeholder area

3. **Adjust if needed:**
   - If image doesn't fit well, select the image
   - Use corner handles to resize (hold Shift to maintain aspect ratio)
   - Ensure image doesn't overlap with talking points (left panel)

4. **Save the presentation:**
   - File → Save (or Ctrl+S / Cmd+S)

---

## Step 6: Final Review Checklist

Before sharing the presentation, verify:

- [ ] All 11 screenshots inserted (no placeholders remaining)
- [ ] Screenshots are clear and readable
- [ ] State name is visible and highlighted in indicator charts
- [ ] Talking points are visible and not overlapped by images
- [ ] Footer appears on all slides
- [ ] Slide order is correct:
  - Title slide
  - CFSR Round 4 Profile (bullets)
  - Section Header: Performance Summary
  - Summary app, RSP overview, Observed overview
  - Section Header: Individual Indicators
  - 8 indicator slides
- [ ] File saved with correct name: `{STATE}_CFSR_Presentation_{period}.pptx`

---

## Tips for Better Screenshots

1. **Maximize browser window** before capturing to get full-width charts
2. **Wait for charts to fully load** (watch for loading spinners)
3. **Check image quality** after inserting - retake if blurry
4. **Use consistent zoom level** across all screenshots (100% browser zoom recommended)
5. **Crop tightly** around charts to remove extra whitespace

---

## Troubleshooting

### "PowerPoint can't insert the picture from this file"
- **Solution:** Save screenshot as PNG (not WebP or other formats)
- Windows Snipping Tool: File → Save As → PNG

### Screenshots are too large/small
- **Solution:** Resize browser window before capturing
- Aim for 1600-1920px width for optimal PowerPoint display

### Chart doesn't match placeholder instructions
- **Solution:** Verify you're on the correct tab (e.g., "By State" not "By County")
- Check URL matches the one in the placeholder

### App isn't loading
- **Solution:** Verify apps are running: `source("domains/cfsr/launch_cfsr_apps.R")`
- Check port numbers in console match URLs you're using

---

## Future Enhancement: Automated Screenshots (Phase 2)

This manual workflow will be automated in Phase 2 using the `webshot2` R package to:
- Automatically launch apps in headless browser
- Navigate to each view
- Capture screenshots at optimal dimensions
- Insert directly into PowerPoint

For now, this manual process takes ~15-20 minutes per presentation and ensures high-quality results.

---

## Questions?

Contact: kurt@childmetrix.com
