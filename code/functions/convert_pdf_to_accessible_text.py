#!/usr/bin/env python3
"""
Convert CFSR PDF to accessible text format

This script extracts text from CFSR Data Profile PDFs in a format
that matches Adobe's "Export to Accessible Text" output.

Usage:
    python convert_pdf_to_accessible_text.py <input.pdf> [output.txt]

Dependencies:
    pip install pdfplumber

Alternative tools if pdfplumber doesn't work:
    pip install pypdf pymupdf  # PyMuPDF (fitz)
"""

import sys
import os
from pathlib import Path


def convert_with_pdfplumber(pdf_path, output_path, page_num=2):
    """Convert PDF using pdfplumber (best for tables)"""
    import pdfplumber

    with pdfplumber.open(pdf_path) as pdf:
        # Extract only the specified page (page_num is 1-indexed)
        if page_num > len(pdf.pages):
            raise ValueError(f"PDF only has {len(pdf.pages)} pages, cannot extract page {page_num}")

        page = pdf.pages[page_num - 1]  # Convert to 0-indexed

        # Extract text maintaining layout
        text = page.extract_text(layout=True)

        # Write to output file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(f"--- Page {page_num} ---\n")
            if text:
                f.write(text)
            else:
                f.write("(No text extracted)\n")

    print(f"✓ Converted page {page_num} with pdfplumber: {output_path}")


def convert_with_pymupdf(pdf_path, output_path, page_num=2):
    """Convert PDF using PyMuPDF (fitz) - alternative method"""
    import fitz  # PyMuPDF

    doc = fitz.open(pdf_path)

    # Extract only the specified page (page_num is 1-indexed)
    if page_num > len(doc):
        doc.close()
        raise ValueError(f"PDF only has {len(doc)} pages, cannot extract page {page_num}")

    page = doc[page_num - 1]  # Convert to 0-indexed

    # Extract text with layout preservation
    text = page.get_text("text", sort=True)

    doc.close()

    # Write to output file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"--- Page {page_num} ---\n")
        f.write(text if text else "(No text extracted)\n")

    print(f"✓ Converted page {page_num} with PyMuPDF: {output_path}")


def convert_with_pypdf(pdf_path, output_path, page_num=2):
    """Convert PDF using pypdf - basic fallback"""
    from pypdf import PdfReader

    reader = PdfReader(pdf_path)

    # Extract only the specified page (page_num is 1-indexed)
    if page_num > len(reader.pages):
        raise ValueError(f"PDF only has {len(reader.pages)} pages, cannot extract page {page_num}")

    page = reader.pages[page_num - 1]  # Convert to 0-indexed
    text = page.extract_text()

    # Write to output file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"--- Page {page_num} ---\n")
        f.write(text if text else "(No text extracted)\n")

    print(f"✓ Converted page {page_num} with pypdf: {output_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_pdf_to_accessible_text.py <input.pdf> [output.txt] [page_num]")
        print("  page_num defaults to 2 (RSP data is typically on page 2)")
        sys.exit(1)

    pdf_path = sys.argv[1]

    if not os.path.exists(pdf_path):
        print(f"ERROR: File not found: {pdf_path}")
        sys.exit(1)

    # Determine output path
    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        # Default: same directory, replace .pdf with _accessible.txt
        base = Path(pdf_path).stem
        directory = Path(pdf_path).parent
        output_path = directory / "adobe_to_accessible_text.txt"

    # Page number (default to 2 for RSP data)
    page_num = int(sys.argv[3]) if len(sys.argv) >= 4 else 2

    print(f"Converting: {pdf_path}")
    print(f"Extracting: Page {page_num}")
    print(f"Output to: {output_path}")

    # Try different methods in order of preference
    methods = [
        ("pdfplumber", convert_with_pdfplumber),
        ("PyMuPDF", convert_with_pymupdf),
        ("pypdf", convert_with_pypdf)
    ]

    for method_name, method_func in methods:
        try:
            method_func(pdf_path, output_path, page_num)
            return  # Success!
        except ImportError:
            print(f"  ⚠ {method_name} not installed, trying next method...")
        except Exception as e:
            print(f"  ✗ {method_name} failed: {e}")

    print("\nERROR: All conversion methods failed.")
    print("\nInstall dependencies:")
    print("  pip install pdfplumber")
    print("  pip install pymupdf")
    print("  pip install pypdf")
    sys.exit(1)


if __name__ == "__main__":
    main()
