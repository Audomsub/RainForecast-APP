const axios = require("axios");
require('dotenv').config();

// ✅ ใช้ชื่อ getPrediction เป็นมาตรฐาน
exports.getPrediction = async (imageUrl) => { 
    try {
        const aiUrl = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";
        const endpoint = `${aiUrl}/predict`;
        
        console.log(`🤖 Sending Request to AI: ${endpoint}`);
        
        const response = await axios.post(endpoint, { 
            image_url: imageUrl 
        });

        return response.data;
    } catch (error) {
        console.error("❌ AI Service Error:", error.message);
        return { 
            rain_probability: 0, 
            level: "AI Error",
            error: true 
        };
    }
};