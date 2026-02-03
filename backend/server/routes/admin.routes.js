const express = require("express");
const router = express.Router();
// ดึงฟังก์ชัน loginAdmin มาจาก controller
const { loginAdmin } = require("../controller/admincontroller");

// กำหนด Route สำหรับ Login
router.post("/login", loginAdmin);

module.exports = router;