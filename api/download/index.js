const { BlobServiceClient, StorageSharedKeyCredential, generateBlobSASQueryParameters, BlobSASPermissions } = require("@azure/storage-blob");

module.exports = async function (context, req) {
    const state = (req.query.state || "").toLowerCase();
    const period = req.query.period || "";

    if (!state || !period) {
        context.res = {
            status: 400,
            body: "Missing required parameters: state and period"
        };
        return;
    }

    // Validate period format (YYYY_MM)
    if (!/^\d{4}_\d{2}$/.test(period)) {
        context.res = {
            status: 400,
            body: "Invalid period format. Expected: YYYY_MM"
        };
        return;
    }

    const accountName = process.env.AZURE_STORAGE_ACCOUNT;
    const accountKey = process.env.AZURE_STORAGE_KEY;

    if (!accountName || !accountKey) {
        context.res = {
            status: 500,
            body: "Storage configuration missing"
        };
        return;
    }

    const containerName = "processed";
    const stateUpper = state.toUpperCase();
    const blobPath = `${state}/cfsr/presentations/${period}/${stateUpper}_CFSR_Presentation_${period}.pptx`;

    try {
        const sharedKeyCredential = new StorageSharedKeyCredential(accountName, accountKey);
        
        // Generate SAS token valid for 5 minutes
        const sasToken = generateBlobSASQueryParameters({
            containerName,
            blobName: blobPath,
            permissions: BlobSASPermissions.parse("r"),
            expiresOn: new Date(Date.now() + 5 * 60 * 1000) // 5 minutes
        }, sharedKeyCredential).toString();

        const downloadUrl = `https://${accountName}.blob.core.windows.net/${containerName}/${blobPath}?${sasToken}`;

        // Redirect to the blob URL with short-lived SAS token
        context.res = {
            status: 302,
            headers: {
                "Location": downloadUrl,
                "Cache-Control": "no-cache, no-store, must-revalidate"
            },
            body: ""
        };
    } catch (error) {
        context.res = {
            status: 500,
            body: "Error generating download URL: " + error.message
        };
    }
};
