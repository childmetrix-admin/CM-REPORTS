# CFSR Profile - Backlog

*Last Updated: 2025-10-13*

## Current Status

### ✅ Phase 1 Complete
- Multi-state, multi-period data processing system
- Tertiary navigation (State Performance vs. NS, State-by-State, County-by-County)
- Period selector in tertiary nav
- Shiny app integration for State-by-State Performance
- Placeholder pages for State vs NS and County-by-County

---

## Backlog Items

### 1. Performance Menu - Show Profile File Name
**Priority:** Medium
**Category:** Data Transparency
**Status:** Not Started

**Description:**
Display the source file name/date that the current data is based on somewhere in the Performance section.

**Implementation Ideas:**
- Add a small info badge near the period selector showing: "Data from: MD - February 2025"
- Add a footer to each indicator page showing: "Source: MD_cfsr_indicators_2025_02.rds"
- Add to the Overview page as metadata

**Acceptance Criteria:**
- [ ] User can see which specific file the data comes from
- [ ] Displayed in a non-intrusive way
- [ ] Shows state code and period in human-readable format

---

### 2. Tertiary Menu - Rename "CFSR Profile Period" Selector
**Priority:** High
**Category:** UI/UX
**Status:** Not Started

**Description:**
Change the dropdown label from "CFSR Profile Period" to just "CFSR Profile" to reduce redundancy and save space.

**Current:**
```
CFSR Profile Period: [February 2025 ▼]
```

**Proposed:**
```
CFSR Profile: [February 2025 ▼]
```

**File to Edit:**
- `D:/repo_childmetrix/cm-reports/states/md/index.html` (around line 203)

**Acceptance Criteria:**
- [ ] Label changed from "CFSR Profile Period:" to "CFSR Profile:"
- [ ] Dropdown functionality remains unchanged
- [ ] Spacing/alignment looks clean

---

### 3. State Performance vs. National Standards - Decide on Visualizations
**Priority:** High
**Category:** Feature Development
**Status:** Planning

**Description:**
Design and implement visualizations for the "State Performance vs. National Standards" page. This is the default view when users click CFSR Profile.

**Potential Visualizations:**

#### Option A: Bullet Chart Grid
- One bullet chart per indicator showing:
  - State performance (bar)
  - National standard (reference line)
  - National average (comparative line)
  - Color coding: green (meets), yellow (near), red (fails)

#### Option B: Radar/Spider Chart
- All 8 indicators on a radar chart
- State vs. National standards overlay
- Shows overall performance profile at a glance

#### Option C: Scorecard View
- Grid of cards, one per indicator
- Each card shows:
  - Indicator name
  - State value
  - National standard
  - ✓ or ✗ indicator
  - Rank out of 52

#### Option D: Combination Dashboard
- Top section: Summary metrics (# meeting standards, overall rank)
- Middle: Bullet chart for each indicator
- Bottom: Trend sparklines

**Questions to Answer:**
- What story should this page tell?
- Should it show just the latest period or allow comparison across periods?
- Should it show raw values or percentages/rates?
- Should it include county-level summary stats?

**Acceptance Criteria:**
- [ ] Visualization design approved
- [ ] Mockup created
- [ ] Implementation plan documented
- [ ] Data requirements identified

---

### 4. State Performance vs. NS - Reduce Top Space
**Priority:** Medium
**Category:** UI/UX Polish
**Status:** Not Started

**Description:**
Reduce whitespace at the top of the sidebar and main content area to maximize vertical space for content.

**Current Issues:**
- Shiny dashboard has header spacing (even though header is disabled)
- Main content area may have unnecessary padding
- Sidebar menu items could be more compact

**Implementation Ideas:**
- Add custom CSS to reduce shinydashboard margins
- Adjust padding on `.main-sidebar` and `.content-wrapper`
- Use CSS: `padding-top: 0 !important;` on relevant containers

**File to Edit:**
- `D:/repo_childmetrix/cm-reports/shared/cfsr/measures/app_national/app.R` (CSS section)

**Acceptance Criteria:**
- [ ] Top padding reduced by at least 20px
- [ ] Content starts higher on page
- [ ] No visual glitches or layout breaks

---

### 5. State-by-State - Ranking Visualization
**Priority:** High
**Category:** Feature Development
**Status:** Planning

**Description:**
Create a visualization showing how Maryland ranks on each CFSR indicator compared to all other states.

**Reference:**
[World Education Rankings Visualization](https://chandoo.org/wp/world-education-rankings-visualization/)

**Key Features:**
- Horizontal bar chart or dot plot
- One row per indicator
- Maryland highlighted/colored differently
- Shows position among all 52 states/territories
- Optionally shows top 5 and bottom 5 states

**Design Considerations:**
- Should show actual values or just ranks?
- Include national standard line?
- Allow drill-down to see all state values?
- Filter by category (Safety, Permanency, Well-Being)?

**Technical Approach:**
- Use plotly for interactivity
- Could be added to Overview page
- Or create new "Rankings" page in Shiny app

**Acceptance Criteria:**
- [ ] Visualization clearly shows MD's rank on each indicator
- [ ] User can see which indicators MD performs best/worst on
- [ ] Interactive (hover to see exact values/ranks)
- [ ] Responsive and works in iframe

---

### 6. State-by-State - Trend Visualization (Bump Chart)
**Priority:** Medium
**Category:** Feature Development
**Status:** Planning

**Description:**
Create a bump chart or similar visualization showing how state rankings change over time across multiple CFSR profile periods.

**Key Features:**
- X-axis: Time periods (Feb 2024, Aug 2024, Feb 2025)
- Y-axis: Rank (1-52)
- One line per state (MD highlighted with bold/color)
- Shows rank changes over time
- Can filter by specific indicator

**Benefits:**
- Shows if MD is improving or declining relative to other states
- Identifies stable vs. volatile rankings
- Highlights peer states with similar trajectories

**Technical Challenges:**
- Need historical data for all states (not just MD)
- Currently only processing MD data
- May need to load multiple state RDS files or process national files differently

**Questions:**
- Do we have access to historical data for all states?
- Should this be for one indicator at a time or show multiple?
- Is there a better chart type (e.g., slope chart, stream graph)?

**Acceptance Criteria:**
- [ ] Shows MD's rank trend over available periods
- [ ] Other states shown in muted colors for context
- [ ] Interactive (hover to see state names and exact ranks)
- [ ] Can filter by indicator

---

### 7. County-by-County - Decide on Visualizations
**Priority:** Medium
**Category:** Feature Development
**Status:** Planning

**Description:**
Design and implement the County-by-County Performance page showing CFSR indicator performance broken down by Maryland counties.

**Potential Visualizations:**

#### Option A: Choropleth Map
- Maryland map with counties colored by performance on selected indicator
- Hover to see county name and value
- Legend showing color scale
- Dropdown to select indicator

#### Option B: County Rankings Table
- Sortable table showing all counties
- One row per county
- Columns for each indicator
- Color-coded cells (meets standard or not)
- Search/filter capability

#### Option C: Small Multiples
- Grid of mini-charts, one per county
- Shows all indicators for that county
- Quick visual comparison across counties

#### Option D: Comparison Dashboard
- Select 2-4 counties to compare side-by-side
- Shows radar chart or bullet chart for each
- Highlights differences

**Data Questions:**
- Do CFSR profiles include county-level data?
- If not, would this come from a different data source?
- What level of detail is available at county level?
- Are all 8 indicators available at county level?

**Acceptance Criteria:**
- [ ] Data availability confirmed
- [ ] Visualization design approved
- [ ] Shows meaningful county-level insights
- [ ] Allows comparison across counties

---

### 8. Download/Copy Chart Images as PNG
**Priority:** High
**Category:** Feature Enhancement
**Status:** Not Started

**Description:**
Allow users to download or copy any chart/visualization as a PNG image for use in reports, presentations, etc.

**Implementation Approach:**

#### For Plotly Charts (Shiny App)
Plotly has built-in download capability:
```r
config(
  toImageButtonOptions = list(
    format = "png",
    filename = "cfsr_chart",
    height = 600,
    width = 1000
  )
)
```

#### For Custom HTML Charts
Use libraries like:
- `html2canvas` - converts HTML to canvas then to PNG
- `dom-to-image` - similar functionality
- Add "Download PNG" button to each chart

**User Experience:**
- Camera icon button on each chart
- Click to download PNG with descriptive filename
- Include chart title and date in filename
- Optionally: "Copy to Clipboard" button

**Charts to Support:**
- All indicator trend charts
- Overview ranking tables (as images)
- State vs. National comparison charts
- County maps/charts

**Technical Details:**
```javascript
// Example implementation
function downloadChartAsPNG(chartId, filename) {
  const element = document.getElementById(chartId);
  html2canvas(element).then(canvas => {
    const link = document.createElement('a');
    link.download = filename + '.png';
    link.href = canvas.toDataURL();
    link.click();
  });
}
```

**Acceptance Criteria:**
- [ ] Download button visible on all major charts
- [ ] Downloaded PNG has good resolution (at least 1000px wide)
- [ ] Filename includes chart type and date
- [ ] Works in all major browsers
- [ ] No external dependencies if possible (or well-documented)

---

## Implementation Priority

### Phase 2A - Quick Wins (1-2 days)
1. ✅ #2 - Rename "CFSR Profile Period" to "CFSR Profile"
2. ✅ #4 - Reduce top space in sidebar/content
3. ⚠️ #1 - Show profile file name

### Phase 2B - State Performance vs. NS Page (1 week)
4. ⚠️ #3 - Decide on visualizations
5. Implement approved design
6. Add file name/metadata display

### Phase 2C - Enhanced State-by-State (1-2 weeks)
7. ⚠️ #5 - Ranking visualization
8. ⚠️ #8 - Download PNG functionality
9. ⚠️ #6 - Trend/bump chart (if historical data available)

### Phase 2D - County-by-County (2-3 weeks)
10. Confirm data availability
11. ⚠️ #7 - Decide on visualizations
12. Implement county page

---

## Dependencies & Blockers

### Data Dependencies
- **Historical state data**: Need for trend/bump chart (#6)
- **County-level data**: Need to confirm availability for county page (#7)
- **File metadata**: Need to extract/display source file info (#1)

### Technical Dependencies
- **Download PNG**: May need to add `html2canvas` or similar library (#8)
- **Map visualization**: May need mapping library for county choropleth (#7)

### Design Dependencies
- **Visualization approval**: Items #3, #5, #6, #7 require design decisions before implementation

---

## Questions for Product Owner

1. **State vs. NS Page (#3)**: What's the primary use case? Compliance reporting? Identifying improvement areas? Communicating to leadership?

2. **Trend Analysis (#6)**: Do you have access to historical CFSR data for all states, or only Maryland?

3. **County Data (#7)**: Are CFSR indicators available at the county level? If not, is there a plan to obtain county-level data?

4. **Priority**: Which page is most important? State vs. NS (default view) or State-by-State (current Shiny app)?

5. **Branding**: Should downloaded PNGs include ChildMetrix logo or Maryland DHR branding?

---

## Notes

- All items are subject to change based on stakeholder feedback
- Items marked ⚠️ require decisions before implementation can begin
- Items marked ✅ are high-confidence, can start immediately
- This backlog will be updated as items are completed or requirements change
