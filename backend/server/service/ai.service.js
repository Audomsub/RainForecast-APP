const axios = require("axios");
require('dotenv').config();

exports.predictRain = async (imageUrl) => { // เปลี่ยนชื่อพารามิเตอร์เป็น imageUrl ให้ชัดเจน
    try {
        // AI ต้องรองรับการโหลดรูปจาก URL หรือต้องโหลดไฟล์ไปให้
        // สมมติว่า AI API รับ URL รูปภาพได้
        const aiUrl = process.env.AI_API_URL || "http://localhost:8000/predict";
        
        // หมายเหตุ: ถ้า Python Code ของคุณรับแค่ 'path' เครื่องตัวเอง 
        // คุณต้องแก้ Python ให้รับ URL แล้วโหลดรูปเอง หรือส่งรูปเป็น Base64
        const r = await axios.post(aiUrl, { 
            image_path: imageUrl // ตอนนี้ filepath กลายเป็น URL ของ Supabase แล้ว
        });
        return r.data;
    } catch (error) {
        console.error("❌ ติดต่อ AI Server ไม่ได้:", error.message);
        throw error;
    }
};