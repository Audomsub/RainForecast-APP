const router = require("express").Router();
const mapController = require("../controller/map.controller");


router.get("/overlay", mapController.overlay);
router.get("/heatmap", mapController.heatmap);


module.exports = router;