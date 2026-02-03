// backend/server/controller/ai.controller.js
const aiService = require('../service/ai.service');

exports.predictLatest = async (req, res) => {
    try {
        console.log("📡 Requesting prediction for the latest radar image...");
        
        // เรียกใช้ service ตัวใหม่ที่ดึงภาพล่าสุดอัตโนมัติ
        const result = await aiService.getLatestPrediction();

        res.json(result);
    } catch (error) {
        console.error("Controller Error:", error);
        res.status(500).json({ error: error.message });
    }
};