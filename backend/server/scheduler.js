const cron = require('node-cron');
const radarService = require('./service/radar.service');
const axios = require('axios');
require('dotenv').config();

const AI_URL = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";

console.log("⏳ Scheduler Service Started...");

// 1. ดึงรูปทุก 6 นาที
cron.schedule('*/6 * * * *', async () => {
    console.log("\n--- [Job] Rain Forecast ---");
    try {
        const result = await radarService.autoFetchRadar();
        if (result && result.success) {
            console.log(`✅ Done. Prob: ${result.rain_probability}%`);
        }
    } catch (error) {
        console.error("❌ Error:", error.message);
    }
});

// 2. ✅ สั่งเทรนโมเดลทุกเที่ยงคืน (00:00)
cron.schedule('0 0 * * *', async () => {
    console.log("\n--- [Job] Daily Model Training ---");
    try {
        const res = await axios.post(`${AI_URL}/train`);
        console.log(`💪 AI Training Started: ${res.data.message}`);
    } catch (error) {
        console.error("❌ Training Trigger Failed:", error.message);
    }
});