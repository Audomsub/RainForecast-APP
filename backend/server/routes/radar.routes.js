const router = require("express").Router();
const radarController = require("../controller/radar.controller");

router.post("/fetch", radarController.fetchRadar);
router.get("/latest", radarController.getLatest);
router.get("/history", radarController.getHistory);

// ✅ เพิ่ม Routes สำหรับ Visualization
router.get("/visualization/overlay", radarController.getLatestOverlay);
router.get("/visualization/heatmap", radarController.getLatestHeatmap);

// เอา id ไว้ล่างสุด เพื่อป้องกัน conflict
router.get("/:id", radarController.getById);
router.delete("/:id", radarController.deleteById);

module.exports = router;