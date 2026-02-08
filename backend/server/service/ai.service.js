const axios = require("axios");
require('dotenv').config();

const getAIUrl = () => process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";

exports.getPrediction = async (imageInput) => {
    try {
        const payload = { image_urls: Array.isArray(imageInput) ? imageInput : [imageInput] };
        const response = await axios.post(`${getAIUrl()}/predict`, payload);
        return response.data;
    } catch (e) {
        console.error("AI Service Error:", e.message);
        return { rain_probability: 0, level: "AI Error" };
    }
};