# Archive: Pre-Shared-Shell Architecture

**Date**: November 2025
**Reason**: Refactoring from duplicated state index.html files to shared app.html

## What Changed

**Before**: Each state had its own `index.html` containing the full app shell (header, sidebar, navigation, iframe logic). This meant ~600 lines of duplicated code for each of 30+ states.

**After**: Single shared `app.html` at root level, with state-specific configuration in `config.json` files.

## Contents

This archive contains the original state-specific index.html files before the refactoring:

- `states/md/index.html` - Maryland's original app shell
- `states/ky/index.html` - Kentucky's original app shell

## New Architecture

- **Shared shell**: `cm-reports/app.html`
- **State configs**: `cm-reports/states/{state}/config.json`
- **Routing**: Landing page redirects to `app.html?state=md`

## Restoration

If needed, these files can be restored to their original locations. However, the new architecture is significantly more maintainable for multi-state deployments.
