const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
require('dotenv').config();

// นำเข้า AI Service
const aiService = require('./ai.service'); 

// ตั้งค่า Supabase
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";

const agent = new https.Agent({ rejectUnauthorized: false });

// ... (ส่วนของ exports.getLatestRadarImage และ getLastNRadarImages คงเดิม) ...
exports.getLatestRadarImage = async () => { /* ...โค้ดเดิม... */ };

// ✅ คงฟังก์ชันนี้ไว้ (ถ้ายังไม่มี ให้เพิ่มตามที่ผมให้ไปรอบก่อน)
exports.getLastNRadarImages = async (n = 5) => {
    try {
        const { data, error } = await supabase
            .from('radar_images')
            .select('filepath')
            .order('timestamp', { ascending: false })
            .limit(n);

        if (error || data.length < n) return [];
        return data.map(row => row.filepath).reverse();
    } catch (e) {
        return [];
    }
};

// 🔴 แก้ไขฟังก์ชันนี้: ให้ Return ค่าที่ Scheduler ต้องการ
exports.autoFetchRadar = async () => {
    console.log(`⏰ [${new Date().toLocaleTimeString()}] Auto Fetch Radar...`);
    
    try {
        // 1. ดึงภาพและ Upload
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
        
        // 3. เตรียมข้อมูลและส่งให้ AI
        let predictionResult = { rain_probability: 0, level: "Waiting for data" };
        const sequenceUrls = await exports.getLastNRadarImages(5);
        
        if (sequenceUrls.length === 5) {
            // เรียก AI
            predictionResult = await aiService.getPrediction(sequenceUrls);
            console.log("🧠 AI Prediction:", predictionResult.level);
        }

        // ✅ สำคัญ: ต้อง Return Object ที่มีโครงสร้างนี้กลับไป เพื่อไม่ให้ Scheduler Error
        return {
            success: true,
            rain_probability: predictionResult.rain_probability,
            level: predictionResult.level,
            filepath: filepath,
            db_id: insertData[0].id
        };

    } catch (error) {
        console.error(`❌ Auto Fetch Failed: ${error.message}`);
        // ✅ Return Object เพื่อกันไม่ให้ Scheduler Crash
        return { 
            success: false, 
            rain_probability: 0, 
            level: "Error", 
            error: error.message 
        };
    }
};

exports.fetchRadarImage = exports.getLatestRadarImage;