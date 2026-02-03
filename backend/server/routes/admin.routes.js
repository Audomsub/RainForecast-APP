// backend/server/routes/admin.routes.js
const express = require("express");
const router = express.Router();
// ตรวจสอบว่าชื่อไฟล์ admincontroller.js ตัวเล็กทั้งหมดตรงตามไฟล์จริง
const admincontroller = require("../controller/admincontroller");

// ตรวจสอบว่า admincontroller.loginAdmin ไม่เป็น undefined
if (typeof admincontroller.loginAdmin !== 'function') {
    console.error("❌ Error: admincontroller.loginAdmin is not a function. Check your exports!");
}

router.post("/login", admincontroller.loginAdmin);

module.exports = router;