const cron = require('node-cron');
const radarService = require('./service/radar.service');
const Radar = require('./model/radar.model');

console.log("⏳ Scheduler System: เริ่มต้นระบบตั้งเวลา...");

// ตั้งเวลาให้ทำงานทุกๆ 15 นาที
// ความหมายของ '*/15 * * * *' คือ: ทุกนาทีที่หาร 15 ลงตัว (นาทีที่ 0, 15, 30, 45)
cron.schedule('*/6 * * * *', async () => {
    console.log(`⏰ [${new Date().toLocaleTimeString()}] เริ่มทำงาน Auto Fetch Radar...`);
    
    try {
        // 1. เรียก Service ดึงรูปจากกรมฝนหลวง
        const data = await radarService.fetchRadarImage();
        
        // 2. บันทึกลง Database
        const saved = await Radar.create(data);
        
        console.log(`✅ Auto Fetch สำเร็จ! บันทึกเรียบร้อย (ID: ${saved.id})`);
    } catch (error) {
        console.error("❌ Auto Fetch ล้มเหลว:", error.message);
    }
});