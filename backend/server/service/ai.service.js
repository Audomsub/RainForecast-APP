const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
require('dotenv').config();

// นำเข้า AI Service
const aiService = require('./ai.service'); 

// ตั้งค่า Supabase
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";

// Agent สำหรับข้าม SSL Error ของเว็บต้นทาง
const agent = new https.Agent({ rejectUnauthorized: false });

// ฟังก์ชัน 1: ดึงรูปและอัปโหลด (Helper Function)
exports.getLatestRadarImage = async () => {
    try {
        console.log("📡 กำลังดึงข้อมูลจาก:", API_URL);
        
        const apiRes = await axios.get(API_URL, { 
            httpsAgent: agent, timeout: 10000 
        });
        
        let data = apiRes.data;
        if (data.data) data = data.data;
        else if (data.result) data = data.result;

        if (!Array.isArray(data) || data.length === 0) throw new Error("❌ ข้อมูล API ไม่ถูกต้อง");

        const latest = data[data.length - 1];
        
        // บังคับ HTTPS
        let imageUrl = latest.url.replace("http://", "https://");
        console.log("⏳ กำลังดาวน์โหลดรูปภาพ:", imageUrl);

        // โหลดรูปเป็น Buffer
        const imgRes = await axios.get(imageUrl, {
            responseType: "arraybuffer",
            timeout: 60000,
            httpsAgent: agent
        });

        const filename = `radar_${Date.now()}.png`;

        // 🟢 Upload ขึ้น Supabase Storage
        const { data: uploadData, error: uploadError } = await supabase
            .storage
            .from('radar-images')
            .upload(filename, imgRes.data, {
                contentType: 'image/png'
            });

        if (uploadError) throw new Error(`Upload Error: ${uploadError.message}`);

        // ดึง Public URL
        const { data: publicUrlData } = supabase
            .storage
            .from('radar-images')
            .getPublicUrl(filename);

        const publicUrl = publicUrlData.publicUrl;
        console.log("☁️ อัปโหลดเสร็จสิ้น:", publicUrl);

        // ส่ง key ชื่อ 'filepath' เพื่อให้ตรงกับ Model และ Database
        return { 
            filename, 
            filepath: publicUrl, 
            source_url: imageUrl 
        };

    } catch (error) {
        console.error("❌ Error in getLatestRadarImage:", error.message);
        throw error;
    }
};

// ✅ ฟังก์ชันใหม่: ดึง URL ของ 5 ภาพล่าสุดจาก Database
exports.getLastNRadarImages = async (n = 5) => {
    try {
        // ดึงข้อมูลเรียงจาก ใหม่ -> เก่า (DESC)
        const { data, error } = await supabase
            .from('radar_images')
            .select('filepath')
            .order('timestamp', { ascending: false })
            .limit(n);

        if (error) {
            console.error("❌ Error fetching recent images:", error.message);
            return [];
        }

        if (data.length < n) {
            console.warn(`⚠️ Warning: Not enough images (Found ${data.length}, Need ${n})`);
            return [];
        }

        // Supabase ส่งมาเป็น [ล่าสุด, ล่าสุด-1, ...]
        // Model ต้องการลำดับเวลา: [เก่าสุด, ..., ล่าสุด] -> ต้อง reverse
        const urls = data.map(row => row.filepath).reverse();
        return urls;

    } catch (e) {
        console.error("❌ Error in getLastNRadarImages:", e.message);
        return [];
    }
};

// ฟังก์ชัน 2: Auto Fetch (เรียกโดย Scheduler)
exports.autoFetchRadar = async () => {
    console.log(`⏰ [${new Date().toLocaleTimeString()}] เริ่มทำงาน Auto Fetch Radar...`);
    
    try {
        // 1. ดึงภาพล่าสุดและ Upload
        const { filename, filepath } = await exports.getLatestRadarImage();

        // 2. บันทึกลง Database
        const { data: insertData, error: dbError } = await supabase
            .from('radar_images')
            .insert([{ 
                station: 'rongkwang', 
                filename: filename, 
                filepath: filepath, 
                timestamp: new Date() 
            }])
            .select();

        if (dbError) throw dbError;
        console.log(`✅ บันทึกภาพลง DB สำเร็จ ID: ${insertData[0].id}`);

        // =========================================================
        // 🚀 เตรียมข้อมูล 5 ภาพ ส่งให้ AI (Sequence Prediction)
        // =========================================================
        console.log("🤖 กำลังเตรียมข้อมูล Sequence 5 ภาพ...");
        const sequenceUrls = await exports.getLastNRadarImages(5);
        
        if (sequenceUrls.length === 5) {
            console.log("📤 Sending sequence to AI:", sequenceUrls);
            const predictionResult = await aiService.getPrediction(sequenceUrls);
            console.log("🧠 ผลการพยากรณ์:", predictionResult);
            
            // (Optional) คุณอาจจะอยากบันทึกผลพยากรณ์ลง DB ตรงนี้
        } else {
            console.log("⚠️ ข้ามการพยากรณ์: ข้อมูลภาพไม่ครบ 5 เฟรม");
        }

        return insertData;

    } catch (error) {
        console.error(`❌ Auto Fetch ล้มเหลว: ${error.message}`);
    }
};

// ฟังก์ชัน 3: Manual Fetch
exports.fetchRadarImage = exports.getLatestRadarImage;