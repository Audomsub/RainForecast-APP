const aiService = require('../service/ai.service');

exports.predict = async (req, res) => {
    try {
        const { image_url } = req.body;
        
        if (!image_url) {
            return res.status(400).json({ error: "image_url is required" });
        }

        console.log("📡 Manual AI Predict Request:", image_url);

        // ✅ แก้บรรทัดนี้: เรียกใช้ getPrediction ให้ตรงกับ Service
        const result = await aiService.getPrediction(image_url);

        res.json(result);
    } catch (error) {
        console.error("Controller Error:", error);
        res.status(500).json({ error: error.message });
    }
};

exports.history = async (req, res) => {
    // ... (ส่วน History ถ้ามีให้คงไว้เหมือนเดิม)
    res.json({ message: "History API implementation pending" });
};