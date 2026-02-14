const express = require("express");
const router = express.Router();
// เพิ่ม getTrafficStats เข้ามาในบรรทัดนี้
const { loginAdmin, trackOnline, getOnlineCount, getTrafficStats } = require("../controller/admincontroller");


router.post("/login", loginAdmin);
router.post("/track-online", trackOnline);

router.get("/online-count", getOnlineCount);
router.get("/traffic-stats", getTrafficStats);

module.exports = router;