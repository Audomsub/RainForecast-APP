const router = require("express").Router();
const mapController = require("../model/controller/map.controller");


router.get("/overlay", mapController.overlay);
router.get("/heatmap", mapController.heatmap);


module.exports = router;