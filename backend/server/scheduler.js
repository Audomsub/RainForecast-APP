const cron = require('node-cron');
const radarService = require('./service/radar.service');

console.log("⏳ Scheduler Service Started...");

// ตั้งเวลาทำงานทุกๆ 10 นาที (หรือตามที่คุณตั้งไว้)
cron.schedule('*/6https://github.com/Audomsub/RainForecast-APP.git * * * *', async () => {
    console.log("\n------------------------------------------------");
    console.log("⏰ [Scheduler] Starting automated rain forecast...");
    
    try {
        const result = await radarService.autoFetchRadar();

        // 🟢 เพิ่มการตรวจสอบความถูกต้องของข้อมูล (Safety Check)
        if (result && result.success) {
            console.log(`✅ Job Completed. Rain Probability: ${result.rain_probability}%`);
        } else {
            console.log(`⚠️ Job Finished with warning: ${result ? result.message : 'No result returned'}`);
        }

    } catch (error) {
        console.error("❌ Scheduler Critical Error:", error.message);
    }
});