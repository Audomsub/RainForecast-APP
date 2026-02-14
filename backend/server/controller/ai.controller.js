const aiService = require('../service/ai.service');

exports.predict = async (req, res) => {
    try {
        const { image_url } = req.body;
        if (!image_url) return res.status(400).json({ error: "image_url is required" });

        const result = await aiService.getPrediction(image_url);
        res.json(result);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// ฟังก์ชันใหม่สำหรับพยากรณ์ภาพล่าสุดอัตโนมัติ
exports.predictLatest = async (req, res) => {
    try {
        const result = await aiService.getLatestPrediction();
        if (res) res.json(result); // รองรับการเรียกจากทั้ง API และ Scheduler
        return result;
    } catch (error) {
        if (res) res.status(500).json({ error: error.message });
    }
};

exports.history = async (req, res) => {
    res.json({ message: "History API implementation pending" });
};