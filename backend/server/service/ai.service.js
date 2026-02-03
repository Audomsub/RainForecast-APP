const axios = require("axios");
const Radar = require("../model/radar.model"); // สมมติชื่อ model ตามโครงสร้างโปรเจกต์
require('dotenv').config();

exports.getLatestPrediction = async () => { 
    try {
        // ดึงภาพเรดาร์ล่าสุดจากฐานข้อมูล
        const latestRadar = await Radar.findOne().sort({ createdAt: -1 });
        
        if (!latestRadar || !latestRadar.imageUrl) {
            throw new Error("ไม่พบภาพเรดาร์ในระบบ");
        }

        const aiUrl = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";
        const response = await axios.post(`${aiUrl}/predict`, { 
            image_url: latestRadar.imageUrl 
        });

        return response.data;
    } catch (error) {
        console.error("❌ AI Service Error:", error.message);
        return { rain_probability: 0, level: "AI Error", error: true };
    }
};