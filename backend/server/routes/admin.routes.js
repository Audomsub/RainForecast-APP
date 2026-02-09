const express = require("express");
const router = express.Router();
const { loginAdmin, trackOnline, getOnlineCount } = require("../controller/admincontroller");


router.post("/login", loginAdmin);
router.post("/track-online",trackOnline);

router.get("/online-count",getOnlineCount);
router.get("/traffic-stats", getTrafficStats);
module.exports = router;