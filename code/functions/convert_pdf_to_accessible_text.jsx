// Adobe Acrobat JavaScript to export PDF as accessible text
// Usage: Run this script via Adobe Acrobat's JavaScript console or batch processing
//
// To use from command line:
// "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe" /n /s /t "input.pdf" "convert_pdf_to_accessible_text.jsx"

// Get the active document
var doc = this;

if (doc == null) {
    console.println("ERROR: No document is open");
} else {
    try {
        // Get the file path and create output path
        var inputPath = doc.path;
        var inputFilename = doc.documentFileName;

        // Remove .pdf extension and add .txt
        var outputFilename = inputFilename.replace(/\.pdf$/i, "_accessible.txt");
        var outputPath = inputPath + "/" + outputFilename;

        // Export as accessible text
        // Format: com.adobe.acrobat.accesstext
        doc.saveAs({
            cPath: outputPath,
            cConvID: "com.adobe.acrobat.accesstext"
        });

        console.println("SUCCESS: Exported to " + outputPath);

    } catch (e) {
        console.println("ERROR: " + e.toString());
    }
}
