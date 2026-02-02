const axios = require("axios");
require('dotenv').config();

// ใช้ชื่อฟังก์ชัน getPrediction เพื่อให้ตรงกับ radar.service.js
exports.getPrediction = async (imageUrl) => { 
    try {
        // AI URL ควรมาจาก Environment Variable (ถ้าไม่มีใช้ localhost เป็นค่าเริ่มต้น)
        const aiUrl = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";
        const endpoint = `${aiUrl}/predict`;
        
        console.log(`🤖 Sending Request to AI: ${endpoint}`);
        console.log(`📸 Image URL: ${imageUrl}`);
        
        // ส่ง URL ไปให้ Python (key ต้องตรงกับ Pydantic Model: image_url)
        const response = await axios.post(endpoint, { 
            image_url: imageUrl 
        });

        return response.data;
    } catch (error) {
        console.error("❌ AI Service Error:", error.message);
        
        if (error.response) {
            console.error("   Server Response:", error.response.data);
        }

        // คืนค่า Default เพื่อให้ระบบหลักทำงานต่อได้โดยไม่ล่ม
        return { 
            rain_probability: 0, 
            level: "AI Error (Connection Failed)",
            error: true 
        };
    }
};