const router = require("express").Router();
const radarController = require("../controller/radar.controller");


router.post("/fetch", radarController.fetchRadar);
router.get("/latest", radarController.getLatest);
router.get("/history", radarController.getHistory);
router.get("/:id", radarController.getById);
router.delete("/:id", radarController.deleteById);


module.exports = router;