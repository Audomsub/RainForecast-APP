const aiService = require("../service/ai.service");
const Radar = require("../model/radar.model");
const Prediction = require("../model/prediction.model");

exports.predict = async (req, res) => {
    try {
        // 1. เช็คว่ามี Body ส่งมาไหม (ป้องกัน Error: Cannot destructure...)
        if (!req.body) {
            return res.status(400).json({ 
                error: "ไม่พบข้อมูลที่ส่งมา (Request Body is missing). กรุณาส่งเป็น POST + JSON" 
            });
        }

        const { radar_id } = req.body;

        // 2. เช็คว่าส่ง radar_id มาไหม
        if (!radar_id) {
            return res.status(400).json({ error: "กรุณาระบุ radar_id ใน JSON Body" });
        }

        // 3. ค้นหาข้อมูล Radar จาก Database
        const radar = await Radar.getById(radar_id);

        if (!radar) {
            return res.status(404).json({ error: `ไม่พบข้อมูลรูปภาพ Radar ID: ${radar_id}` });
        }

        console.log("🔍 วิเคราะห์ภาพจาก:", radar.filepath);

        // 4. ส่ง filepath เข้า AI
        const result = await aiService.predictRain(radar.filepath);

        // 5. บันทึกผลลัพธ์
        const savedPrediction = await Prediction.create({
            radar_id: radar.id,
            rain_probability: result.rain_probability,
            level: result.level
        });

        res.json(savedPrediction);

    } catch (e) {
        console.error("AI Error:", e);
        res.status(500).json({ error: e.message });
    }
};

exports.history = async (req, res) => {
    try {
        const data = await Prediction.getAll();
        res.json(data);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};