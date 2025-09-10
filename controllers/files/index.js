const getRemoteFile = require("../../helpers/getRemoteFiles");
const path = require("path");
const fs = require("fs");

const fileCtrl = {
    // getFileByName: async (req, res) => {
    //     const { filename } = req.params;
    //     const { location } = req.query;

    //     const tempDir = path.join(__dirname, "../../temp");

    //     // Ensure temp dir exists
    //     if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir);

    //     const result = await getRemoteFile(filename, tempDir, location);

    //     if (!result.success) {
    //         return res.status(404).json({ error: "File not found", detail: result.error });
    //     }

    //     res.download(result.localPath, filename, (err) => {
    //         // Delete the temp file after response
    //         fs.unlink(result.localPath, () => { });

    //         if (err) {
    //             console.error("❌ Download error:", err);
    //             return res.status(500).json({ error: "Failed to send file" });
    //         }
    //     });
    // }

    getFileByName: async (req, res) => {
        try {
          const { filename } = req.params;
          let { location, fullPath, preview } = req.query;
      
          let basePath;
          let folderName;
      
          if (fullPath) {
            fullPath = path.normalize(fullPath);
            const parts = fullPath.split(path.sep).filter(Boolean);
            basePath = path.join("\\\\", parts[0], parts[1]) + path.sep;
            folderName = parts[2];
          }
      
          let networkDrivePath = path.join("W:\\", filename);
      
          if (location === "writeable") {
            networkDrivePath = path.join("W:\\", filename);
          } else if (location === "readable") {
            networkDrivePath = path.join("P:\\", folderName, filename);
          }
      
          if (!fs.existsSync(networkDrivePath)) {
            return res.status(404).json({ error: "❌ File not found on network drive." });
          }
      
          // ✅ Preview mode (opens in browser if supported by MIME type)
          if (preview === "true") {
            const fileMime = mime.getType(filename) || "application/octet-stream";
            res.setHeader("Content-Type", fileMime);
            return res.sendFile(networkDrivePath);
          }
      
          // ✅ Default: Force download
          return res.download(networkDrivePath, filename, (err) => {
            if (err) {
              console.error("❌ Download error:", err);
              return res.status(500).json({ error: "Failed to send file" });
            }
          });
        } catch (error) {
          console.error("❌ Server error:", error);
          return res.status(500).json({ error: "Something went wrong", details: error.message });
        }
      }
};

module.exports = fileCtrl;
