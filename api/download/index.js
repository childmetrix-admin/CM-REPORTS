const { BlobServiceClient, StorageSharedKeyCredential, generateBlobSASQueryParameters, BlobSASPermissions } = require("@azure/storage-blob");

module.exports = async function (context, req) {
    const state = (req.query.state || "").toLowerCase();
    const period = req.query.period || "";

    if (!state || !period) {
        context.res = {
            status: 400,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: "Missing required parameters: state and period" })
        };
        return;
    }

    if (!/^\d{4}_\d{2}$/.test(period)) {
        context.res = {
            status: 400,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: "Invalid period format. Expected: YYYY_MM" })
        };
        return;
    }

    const accountName = process.env.AZURE_STORAGE_ACCOUNT;
    const accountKey = process.env.AZURE_STORAGE_KEY;

    if (!accountName || !accountKey) {
        context.res = {
            status: 500,
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: "Storage configuration missing" })
        };
        return;
    }

    const containerName = "processed";
    const stateUpper = state.toUpperCase();
    const blobPath = `${state}/cfsr/presentations/${period}/${stateUpper}_CFSR_Presentation_${period}.pptx`;

    try {
        const sharedKeyCredential = new StorageSharedKeyCredential(accountName, accountKey);
        const blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            sharedKeyCredential
        );

        const containerClient = blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobPath);
        const exists = await blobClient.exists();

        if (!exists) {
            context.res = {
                status: 404,
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    error: "Presentation not found",
                    state: stateUpper,
                    period: period
                })
            };
            return;
        }

        const sasToken = generateBlobSASQueryParameters({
            containerName,
            blobName: blobPath,
            permissions: BlobSASPermissions.parse("r"),
            expiresOn: new Date(Date.now() + 5 * 60 * 1000),
            contentDisposition: `attachment; filename="${stateUpper}_CFSR_Presentation_${period}.pptx"`
        }, sharedKeyCredential).toString();

        const downloadUrl = `https://${accountName}.blob.core.windows.net/${containerName}/${blobPath}?${sasToken}`;

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
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ error: "Error generating download URL: " + error.message })
        };
    }
};
