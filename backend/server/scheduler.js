const cron = require('node-cron');
const aiController = require('./controller/ai.controller');

// รันทุก 15 นาที
cron.schedule('*/6 * * * *', async () => {
    console.log("⏰ [Scheduler] Starting automated rain forecast...");
    try {
        const result = await aiController.predictLatest();
        console.log(`✅ Forecast Done: Prob ${result.rain_probability}% - ${result.level}`);
    } catch (err) {
        console.error("❌ Scheduler Error:", err.message);
    }
});