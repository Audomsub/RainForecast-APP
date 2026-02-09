// ===============================
// ENV CONFIG (ต้องอยู่บนสุดเสมอ)
// ===============================
require('../config/env');   // ✅ โหลด env จากไฟล์กลาง

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

// Path สำหรับเก็บรูปไป Train AI
const AI_RAW_DATA_PATH = path.join(__dirname, '../../ai_server/raw_radar_images');
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
        const apiRes = await axios.get(API_URL, { httpsAgent: agent, timeout: 15000 });
        const data = apiRes.data?.data || apiRes.data?.result;

        if (!data || data.length === 0) {
            throw new Error("No API Data");
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
        fs.writeFileSync(path.join(AI_RAW_DATA_PATH, filename), imgRes.data);

        // 2) Upload to Supabase Storage
        const { error: uploadError } = await supabase.storage
            .from('radar-images')
            .upload(filename, imgRes.data, { contentType: 'image/png', upsert: true });

        if (uploadError) throw uploadError;

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
        console.error("❌ getLatestRadarImage:", error.message);
        throw error;
    }
};


/**
 * ดึง radar ล่าสุด N ภาพ สำหรับ sequence prediction
 */
exports.getLastNRadarImages = async (n = 5) => {
    const { data, error } = await supabase
        .from('radar_images')
        .select('filepath')
        .order('timestamp', { ascending: false })
        .limit(n);

    if (error) {
        console.error("❌ getLastNRadarImages:", error.message);
        return [];
    }

    return data ? data.map(r => r.filepath).reverse() : [];
};


/**
 * Auto fetch radar + save + AI predict
 */
exports.autoFetchRadar = async () => {
    let result = { success: false, rain_probability: 0, level: "Waiting" };

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
            console.log("🤖 Predicting...");
            const aiRes = await aiService.getPrediction(sequenceUrls);
            result = { ...result, ...aiRes, success: true };
            console.log(`🧠 Prediction: ${result.level} (${result.rain_probability}%)`);
        } else {
            console.log("⏳ Not enough radar images for prediction");
        }

        return result;

    } catch (error) {
        console.error("❌ autoFetchRadar:", error.message);
        return { ...result, level: "Error" };
    }
};
