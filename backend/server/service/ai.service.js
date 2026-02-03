const axios = require("axios");
const Radar = require("../model/radar.model"); //
require('dotenv').config();

exports.getPrediction = async (imageUrl) => {
    const aiUrl = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";
    const response = await axios.post(`${aiUrl}/predict`, { image_url: imageUrl });
    return response.data;
};

exports.getLatestPrediction = async () => {
    try {
        const latestRadar = await Radar.findOne().sort({ createdAt: -1 }); // ดึงภาพล่าสุด
        if (!latestRadar) throw new Error("No radar images found");

        return await this.getPrediction(latestRadar.imageUrl);
    } catch (error) {
        console.error("❌ Service Error:", error.message);
        return { rain_probability: 0, level: "Error", error: true };
    }
};