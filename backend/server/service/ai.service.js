const axios = require("axios");
const Radar = require("../model/radar.model"); 
require('dotenv').config();

exports.getPrediction = async (imageUrl) => {
    const aiUrl = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";
    const response = await axios.post(`${aiUrl}/predict`, { image_url: imageUrl });
    return response.data;
};

exports.getLatestPrediction = async () => {
    try {
        // ❌ ของเดิม (ผิด): เป็นคำสั่ง MongoDB
        // const latestRadar = await Radar.findOne().sort({ createdAt: -1 });
        
        // ✅ แก้ไข: ใช้ฟังก์ชัน getLatest() ที่เตรียมไว้ใน model (SQL)
        const latestRadar = await Radar.getLatest(); 
        
        if (!latestRadar) throw new Error("No radar images found");

        // ✅ แก้ไข: เปลี่ยนจาก .imageUrl เป็น .filepath (ตามที่บันทึกใน radar.service.js)
        return await this.getPrediction(latestRadar.filepath); 
    } catch (error) {
        console.error("❌ Service Error:", error.message);
        return { rain_probability: 0, level: "Error", error: true };
    }
};