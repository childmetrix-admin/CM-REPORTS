# CFSR Profile - Risk-Standardized Performance (RSP) Dashboard

## Overview

This Shiny dashboard visualizes Risk-Standardized Performance (RSP) data from state-specific CFSR Data Profile PDFs.

## Status

**Under Development** - This dashboard is planned for future implementation.

## Data Source

- **Input**: Processed RSP data from `profile_rsp.R`
- **Location**: `data/processed/{state}/{period}/{date}/rsp/`
- **Format**: CSV with RSP metrics by indicator and period

## Planned Features

- State-specific RSP trends over time
- Comparison of observed vs risk-standardized performance
- Indicator-by-indicator detail pages
- Risk factor visualizations
- Data quality check summaries

## Development Notes

The RSP dashboard will complement the national dashboard by showing:
1. How the state performs after adjusting for risk factors
2. Trends in risk-adjusted performance
3. Which indicators show improvement after risk adjustment

## Related Files

- **Processing script**: `code/profile_rsp.R`
- **Data preparation**: `shiny_app/prepare_app_data_rsp.R` (to be created)
- **App entry point**: `shiny_app/rsp/app/app.R` (to be created)
