# CFSR Profile - State-Level (Geographic) Dashboard

## Overview

This Shiny dashboard visualizes state-level CFSR data broken down by county, region, or other geographic subdivisions.

## Status

**Under Development** - This dashboard is planned for future implementation.

## Data Source

- **Input**: Processed state-level data from `profile_state.R`
- **Location**: `data/processed/{state}/{period}/{date}/state/`
- **Format**: CSV with indicators by geography (county/region)

## Planned Features

- Interactive maps showing indicator performance by county/region
- Geographic trends over time
- County-to-county comparisons
- Regional aggregations
- Identify geographic areas needing intervention

## Development Notes

The state-level dashboard will enable:
1. Drilling down from state-level to county/region level
2. Identifying geographic disparities within the state
3. Targeting resources to areas with poorest performance
4. Tracking improvement at local level

## Related Files

- **Processing script**: `code/profile_state.R`
- **Data preparation**: `shiny_app/prepare_app_data_state.R` (to be created)
- **App entry point**: `shiny_app/state/app/app.R` (to be created)
