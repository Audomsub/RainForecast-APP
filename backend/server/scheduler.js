const cron = require('node-cron');
const aiService = require('./service/ai.service');

// ตั้งเวลาให้ตรวจสอบและพยากรณ์ทุก 15 นาที (หรือตามความถี่ที่ภาพเรดาร์อัปเดต)
cron.schedule('*/6 * * * *', async () => {
    console.log("⏰ Running Scheduled Rain Forecast...");
    try {
        const result = await aiService.getLatestPrediction();
        console.log(`✅ Forecast Result: ${result.level} (Prob: ${result.rain_probability}%)`);
        
        // ตรงนี้สามารถเพิ่ม Code บันทึกผลลงฐานข้อมูล Prediction ได้
    } catch (error) {
        console.error("Error in Scheduler:", error.message);
    }
});