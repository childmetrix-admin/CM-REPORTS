"""
Build starter .pptx templates for CFSR profile officer pipelines.

Uses the default Office slide layouts (Title Slide, Two Content, etc.) so
officer::read_pptx() and add_slide(..., layout = "Two Content") work out of the box.
Slide size: 16:9 (13.333 x 7.5 in).

Run from repo root:
  python domains/cfsr/scripts/build_presentation_template.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from pptx import Presentation
from pptx.util import Inches


def build_blank_template() -> Presentation:
    prs = Presentation()
    prs.slide_width = int(Inches(13.333))
    prs.slide_height = int(Inches(7.5))
    return prs


def main() -> int:
    root = Path(__file__).resolve().parents[3]
    out_ky = root / "states" / "ky" / "_assets" / "ky-presentation-template.pptx"
    out_md = root / "states" / "md" / "_assets" / "md-presentation-template.pptx"
    out_ky.parent.mkdir(parents=True, exist_ok=True)
    out_md.parent.mkdir(parents=True, exist_ok=True)

    prs = build_blank_template()
    prs.save(str(out_ky))
    prs.save(str(out_md))
    print(f"Wrote {out_ky}")
    print(f"Wrote {out_md}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
