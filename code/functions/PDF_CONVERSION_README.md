# CFSR PDF to Accessible Text Conversion

This document explains how to convert CFSR Data Profile PDFs to accessible text format for RSP data extraction.

## Automatic Conversion

The `profile_rsp.R` script now attempts automatic PDF conversion if the accessible text file doesn't exist. It tries multiple methods in order:

1. **Python with pdfplumber** (best for tables and structured data)
2. **Python with PyMuPDF** (fitz) - good alternative
3. **Python with pypdf** - basic fallback
4. **R pdftools** - final fallback

### Setup for Automatic Conversion

**Option 1: Python with pdfplumber (RECOMMENDED)**

```bash
pip install pdfplumber
```

**Option 2: Python with PyMuPDF**

```bash
pip install pymupdf
```

**Option 3: R pdftools**

```r
install.packages("pdftools")
```

## Manual Conversion Methods

### Method 1: Adobe Acrobat (MOST ACCURATE)

This is the most reliable method and produces output identical to what the extraction code expects:

1. Open the CFSR Data Profile PDF in Adobe Acrobat Pro DC
2. Go to **File > Export To > Text (Accessible Text)**
3. Save as `adobe_to_accessible_text.txt` in the ShareFile uploads folder:
   - `S:/Shared Folders/{state}/cfsr/uploads/{period}/`

### Method 2: Python Script (Manual Execution)

If you prefer to run the conversion manually:

```bash
# Navigate to functions directory
cd D:/repo_childmetrix/cfsr-profile/code/functions

# Convert PDF
python convert_pdf_to_accessible_text.py "path/to/cfsr_profile.pdf" "output.txt"

# Or let it auto-name the output
python convert_pdf_to_accessible_text.py "path/to/cfsr_profile.pdf"
```

### Method 3: R Function (Manual Execution)

From R console:

```r
# Load RSP functions
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R")

# Convert specific PDF
convert_pdf_to_accessible_text(
  pdf_path = "path/to/cfsr_profile.pdf",
  output_path = "path/to/output.txt"
)

# Or find and convert automatically
find_and_convert_cfsr_pdf(state_code = "md", profile_period = "2025_02")
```

## Conversion Quality Comparison

| Method | Table Accuracy | Layout Preservation | Speed | Reliability |
|--------|---------------|-------------------|-------|-------------|
| Adobe Acrobat | ★★★★★ | ★★★★★ | Fast | Very High |
| pdfplumber | ★★★★☆ | ★★★★☆ | Medium | High |
| PyMuPDF | ★★★☆☆ | ★★★☆☆ | Fast | Medium |
| pypdf | ★★☆☆☆ | ★★☆☆☆ | Fast | Medium |
| pdftools (R) | ★★☆☆☆ | ★★☆☆☆ | Medium | Medium |

## Troubleshooting

### "Python not found in PATH"

**Windows:**
1. Install Python from python.org
2. During installation, check "Add Python to PATH"
3. Restart R/RStudio

**Or use R pdftools instead:**
```r
install.packages("pdftools")
```

### "pdfplumber not installed"

```bash
pip install pdfplumber
```

### Conversion produces garbled text

Try in this order:
1. Use Adobe Acrobat manual export (most reliable)
2. Try pdfplumber: `pip install pdfplumber`
3. Check PDF isn't password-protected or corrupted

### Text file exists but extraction fails

The PDF might have unusual formatting. Try:
1. Re-export from Adobe Acrobat
2. Check the PDF opens correctly in Adobe Reader
3. Compare your text file to a working example from a previous period

## File Locations

- **Python script**: `D:/repo_childmetrix/cfsr-profile/code/functions/convert_pdf_to_accessible_text.py`
- **R functions**: `D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R`
- **Expected output location**: `S:/Shared Folders/{state}/cfsr/uploads/{period}/adobe_to_accessible_text.txt`

## Integration with Workflow

The automatic conversion is integrated into `profile_rsp.R`:

```r
# Run profile processing - will auto-convert PDF if needed
source("D:/repo_childmetrix/cfsr-profile/code/run.R")
run_profile(state = "md", period = "2025_02", source = "rsp")
```

If the text file doesn't exist, the script will:
1. Look for a PDF in the uploads folder
2. Attempt automatic conversion using available tools
3. Save as `adobe_to_accessible_text.txt`
4. Continue with RSP data extraction

If all automatic methods fail, you'll get instructions for manual conversion.
