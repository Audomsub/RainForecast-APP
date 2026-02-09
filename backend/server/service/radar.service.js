// ===============================
// ENV CONFIG (ต้องอยู่บนสุดเสมอ)
// ===============================
require('../config/env');   // โหลด env จากไฟล์กลาง

const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
const fs = require('fs');
const path = require('path');
const aiService = require('./ai.service'); 

// ===============================
// SUPABASE CLIENT
// ===============================
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    console.error("❌ Missing SUPABASE ENV");
    console.error("SUPABASE_URL =", process.env.SUPABASE_URL);
    console.error("SUPABASE_KEY =", process.env.SUPABASE_KEY);
    throw new Error("Supabase ENV not loaded");
}

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ===============================
// CONSTANTS
// ===============================
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";
const agent = new https.Agent({ rejectUnauthorized: false });

// 📂 Path สำหรับเก็บรูปเพื่อให้ AI นำไปเทรน
const AI_RAW_DATA_PATH = path.join(__dirname, '../../ai_server/raw_radar_images');

// สร้างโฟลเดอร์ถ้ายังไม่มี
if (!fs.existsSync(AI_RAW_DATA_PATH)) {
    fs.mkdirSync(AI_RAW_DATA_PATH, { recursive: true });
}

// ===============================
// FUNCTIONS
// ===============================

/**
 * ดึง radar ล่าสุด → save local → upload supabase → return public url
 */
exports.getLatestRadarImage = async () => {
    try {
        console.log("📡 Connecting to Royal Rain API...");
        const apiRes = await axios.get(API_URL, { httpsAgent: agent, timeout: 15000 });
        
        let data = apiRes.data;
        if (data.data) data = data.data;
        else if (data.result) data = data.result;

        if (!Array.isArray(data) || data.length === 0) {
            throw new Error("Invalid API Data");
        }

        const latest = data[data.length - 1];
        const imageUrl = latest.url.replace("http://", "https://");

        // Download Image
        const imgRes = await axios.get(imageUrl, {
            responseType: "arraybuffer",
            timeout: 60000,
            httpsAgent: agent
        });

        const filename = `radar_${Date.now()}.png`;

        // 1) Save Local (Train AI)
        const localPath = path.join(AI_RAW_DATA_PATH, filename);
        fs.writeFileSync(localPath, imgRes.data);
        console.log(`💾 Saved local image: ${filename}`);

        // 2) Upload to Supabase Storage
        const { error: uploadError } = await supabase.storage
            .from('radar-images')
            .upload(filename, imgRes.data, { contentType: 'image/png', upsert: true });

        if (uploadError) {
            throw new Error(`Upload Error: ${uploadError.message}`);
        }

        // 3) Public URL
        const { data: publicUrlData } = supabase
            .storage
            .from('radar-images')
            .getPublicUrl(filename);

        return { 
            filename, 
            filepath: publicUrlData.publicUrl 
        };

    } catch (error) {
        console.error("❌ getLatestRadarImage Error:", error.message);
        throw error;
    }
};


/**
 * ดึง radar ล่าสุด N ภาพ สำหรับ sequence prediction
 */
exports.getLastNRadarImages = async (n = 5) => {
    try {
        const { data, error } = await supabase
            .from('radar_images')
            .select('filepath')
            .order('timestamp', { ascending: false })
            .limit(n);

        if (error || !data || data.length < n) return [];
        return data.map(row => row.filepath).reverse();
    } catch (e) {
        return [];
    }
};


/**
 * Auto fetch radar + save + AI predict
 */
exports.autoFetchRadar = async () => {
    console.log(`⏰ [${new Date().toLocaleTimeString()}] Auto Fetch Radar...`);
    
    let result = { 
        success: false, 
        rain_probability: 0, 
        level: "No Data", 
        message: "" 
    };

    try {
        // 1) Fetch + Upload
        const { filename, filepath } = await exports.getLatestRadarImage();

        // 2) Save DB
        const { error: dbError } = await supabase
            .from('radar_images')
            .insert([{ 
                station: 'rongkwang',
                filename,
                filepath,
                timestamp: new Date()
            }]);

        if (dbError) throw dbError;

        // 3) Prediction
        const sequenceUrls = await exports.getLastNRadarImages(5);
        
        if (sequenceUrls.length === 5) {
            console.log("🤖 Sending 5 frames to AI...");
            const aiResult = await aiService.getPrediction(sequenceUrls);
            
            result.success = true;
            result.rain_probability = aiResult.rain_probability || 0;
            result.level = aiResult.level || "Unknown";
            result.message = "Prediction success";
            
            console.log(`🧠 AI Prediction: ${result.level} (${result.rain_probability}%)`);

            // 4) Save prediction
            const { error: saveError } = await supabase
                .from('predictions')
                .insert([{
                    rain_probability: result.rain_probability,
                    rain_level: result.level,
                    raw_heatmap_base64: aiResult.forecast_image || null
                }]);
            
            if (!saveError) console.log("✅ Saved prediction to DB");

        } else {
            result.message = "Not enough images (Need 5)";
            console.log("⚠️ " + result.message);
        }

        return result;

    } catch (error) {
        console.error(`❌ Auto Fetch Failed: ${error.message}`);
        result.message = error.message;
        return result;
    }
};

// alias
exports.fetchRadarImage = exports.getLatestRadarImage;
