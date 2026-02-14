const express = require('express');
const router = express.Router();
const aiController = require('../model/controller/ai.controller');

// ตรวจสอบว่าชื่อฟังก์ชันใน controller ตรงกับที่เรียกใช้
router.post('/predict', aiController.predict); 
router.get('/predict-latest', aiController.predictLatest); // เพิ่ม Route สำหรับพยากรณ์ภาพล่าสุด
router.get('/history', aiController.history);

module.exports = router;