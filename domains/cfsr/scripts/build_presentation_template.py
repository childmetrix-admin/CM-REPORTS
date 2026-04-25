"""
Copy the branded CFSR presentation template to state-specific locations.

Kurt's branded template (cfsr-presentation-template.pptx) contains custom layouts:
- Title Slide
- Title and Content
- Section Header
- Side Panel with Picture (for indicator slides)
- Top Banner with Picture (for summary app)

Run from repo root:
  python domains/cfsr/scripts/build_presentation_template.py
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[3]
    
    # Source: Kurt's branded template
    source_template = root / "domains" / "cfsr" / "templates" / "cfsr-presentation-template.pptx"
    
    if not source_template.exists():
        print(f"ERROR: Branded template not found at {source_template}")
        print("Please ensure cfsr-presentation-template.pptx exists in domains/cfsr/templates/")
        return 1
    
    # Destinations: state-specific template locations
    out_ky = root / "states" / "ky" / "_assets" / "ky-presentation-template.pptx"
    out_md = root / "states" / "md" / "_assets" / "md-presentation-template.pptx"
    
    out_ky.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    # Copy the branded template to state locations
    shutil.copy2(source_template, out_ky)
    shutil.copy2(source_template, out_md)
    
    print(f"Copied branded template to {out_ky}")
    print(f"Copied branded template to {out_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
