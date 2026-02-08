const axios = require("axios");
const Radar = require("../model/radar.model"); 
require('dotenv').config();

const getAIUrl = () => process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";

exports.getPrediction = async (imageInput) => {
    try {
        const aiUrl = getAIUrl();
        let payload;

        // ตรวจสอบว่าเป็น Array (Sequence 5 ภาพ) หรือ String (ภาพเดียว - กรณีเก่า)
        if (Array.isArray(imageInput)) {
            // สำหรับ Model ใหม่ (ConvLSTM)
            payload = { image_urls: imageInput };
        } else {
            // กรณี Fallback หรือเรียกใช้แบบเดิม (อาจจะต้องแก้ให้ Python รองรับหรือแปลงเป็น Array)
            // สมมติว่าส่งไปเป็น Array 1 ตัว หรือ Handle ตามความเหมาะสม
            payload = { image_urls: [imageInput] }; 
            // หมายเหตุ: ถ้า Model ฝั่ง Python บังคับ 5 ภาพ การส่ง 1 ภาพอาจจะ Error ได้
            // ควรแน่ใจว่าเรียกฟังก์ชันนี้ด้วย Array 5 ตัวเสมอสำหรับ Model ใหม่
        }

        const response = await axios.post(`${aiUrl}/predict`, payload);
        return response.data;

    } catch (e) {
        console.error("AI Predict Error:", e.response ? e.response.data : e.message);
        return { error: e.message };
    }
};

// ฟังก์ชันเดิม (อาจจะต้องปรับปรุงถ้าต้องการใช้ PredictLatest แบบ Sequence)
exports.getLatestPrediction = async () => {
    try {
        // ต้องแก้ logic นี้ถ้าจะให้ทำงานกับ Model ใหม่
        // โดยการดึง 5 ภาพล่าสุดจาก DB แทนการดึงภาพเดียว
        // แต่ในที่นี้คงไว้ก่อน หรือแนะนำให้ใช้ AutoFetch แทน
        const latestRadar = await Radar.getLatest(); 
        if (!latestRadar) throw new Error("No radar images found");
        return await this.getPrediction([latestRadar.filepath]); // ส่งเป็น Array ชั่วคราว
    } catch (error) {
        console.error("❌ Service Error:", error.message);
        return { rain_probability: 0, level: "Error", error: true };
    }
};

// ✅ ขอภาพ Overlay
exports.getOverlay = async (imageUrl) => {
    try {
        const aiUrl = getAIUrl();
        // Overlay API ฝั่ง Python ยังรับ image_url เดี่ยวอยู่ (ตามโค้ด main.py ก่อนหน้า)
        const response = await axios.post(`${aiUrl}/overlay`, { image_url: imageUrl });
        return response.data; // { type: 'overlay', data: 'base64...' }
    } catch (e) {
        console.error("AI Overlay Error:", e.message);
        throw new Error("Failed to generate overlay");
    }
};

// ✅ ขอข้อมูล Heatmap
exports.getHeatmap = async (imageUrl) => {
    try {
        const aiUrl = getAIUrl();
        // Heatmap API ฝั่ง Python ยังรับ image_url เดี่ยวอยู่
        const response = await axios.post(`${aiUrl}/heatmap`, { image_url: imageUrl });
        return response.data; // { type: 'heatmap_points', points: [...] }
    } catch (e) {
        console.error("AI Heatmap Error:", e.message);
        throw new Error("Failed to generate heatmap data");
    }
};