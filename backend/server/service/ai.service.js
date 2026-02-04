const axios = require("axios");
const Radar = require("../model/radar.model"); 
require('dotenv').config();

const getAIUrl = () => process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";

exports.getPrediction = async (imageUrl) => {
    try {
        const aiUrl = getAIUrl();
        const response = await axios.post(`${aiUrl}/predict`, { image_url: imageUrl });
        return response.data;
    } catch (e) {
        console.error("AI Predict Error:", e.message);
        return { error: e.message };
    }
};

// ฟังก์ชันเดิมที่คุณมี
exports.getLatestPrediction = async () => {
    try {
        const latestRadar = await Radar.getLatest(); 
        if (!latestRadar) throw new Error("No radar images found");
        return await this.getPrediction(latestRadar.filepath); 
    } catch (error) {
        console.error("❌ Service Error:", error.message);
        return { rain_probability: 0, level: "Error", error: true };
    }
};

// ✅ เพิ่มใหม่: ขอภาพ Overlay
exports.getOverlay = async (imageUrl) => {
    try {
        const aiUrl = getAIUrl();
        const response = await axios.post(`${aiUrl}/overlay`, { image_url: imageUrl });
        return response.data; // { type: 'overlay', data: 'base64...' }
    } catch (e) {
        console.error("AI Overlay Error:", e.message);
        throw new Error("Failed to generate overlay");
    }
};

// ✅ เพิ่มใหม่: ขอข้อมูล Heatmap
exports.getHeatmap = async (imageUrl) => {
    try {
        const aiUrl = getAIUrl();
        const response = await axios.post(`${aiUrl}/heatmap`, { image_url: imageUrl });
        return response.data; // { type: 'heatmap_points', points: [...] }
    } catch (e) {
        console.error("AI Heatmap Error:", e.message);
        throw new Error("Failed to generate heatmap data");
    }
};