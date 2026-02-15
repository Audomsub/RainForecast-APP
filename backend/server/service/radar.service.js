// ===============================
// ENV CONFIG
// ===============================
require('../config/env');

const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
const fs = require('fs-extra'); // ใช้ fs-extra
const path = require('path');
const Jimp = require('jimp');   // ✅ ใช้ Jimp จัดการรูปภาพ
const db = require('../db');    // เชื่อมต่อ DB โดยตรง

// ===============================
// SUPABASE CLIENT (Optional keep if needed)
// ===============================
const supabase = process.env.SUPABASE_URL && process.env.SUPABASE_KEY 
    ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY) 
    : null;

// ===============================
// CONSTANTS
// ===============================
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";
const agent = new https.Agent({ rejectUnauthorized: false });

// 📂 Path สำหรับเก็บรูปที่จะแสดงผล (ในโปรเจกต์ backend)
const STORAGE_PATH = path.join(__dirname, '../storage/radar_images');

// สร้างโฟลเดอร์ถ้ายังไม่มี
fs.ensureDirSync(STORAGE_PATH);

// ===============================
// FUNCTIONS
// ===============================

/**
 * ฟังก์ชันประมวลผลภาพ: ลบพื้นหลังสีดำออก (Make Transparent)
 */
async function processRadarImage(buffer) {
    const image = await Jimp.read(buffer);

    // Scan ทุก pixel
    image.scan(0, 0, image.bitmap.width, image.bitmap.height, function(x, y, idx) {
        const red = this.bitmap.data[idx + 0];
        const green = this.bitmap.data[idx + 1];
        const blue = this.bitmap.data[idx + 2];

        // ถ้าสีดำ หรือเกือบดำ (Threshold < 30) ให้ set Alpha = 0 (โปร่งใส)
        // ปรับค่า 30 ได้ถ้ายังเห็นขอบดำๆ
        if (red < 30 && green < 30 && blue < 30) {
            this.bitmap.data[idx + 3] = 0; // Alpha channel
        }
    });

    return image;
}

/**
 * ดึง radar ล่าสุด → ลบพื้นหลัง → save local → save db → return url
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

        // 1. Download Image Buffer
        const imgRes = await axios.get(imageUrl, {
            responseType: "arraybuffer",
            timeout: 60000,
            httpsAgent: agent
        });

        // 2. Process Image (Remove Black Background)
        console.log("🎨 Processing image transparency...");
        const processedImage = await processRadarImage(imgRes.data);

        const filename = `radar_${Date.now()}.png`;
        const localFilePath = path.join(STORAGE_PATH, filename);
        
        // 3. Save Processed Image to Disk
        await processedImage.writeAsync(localFilePath);
        console.log(`💾 Saved processed image: ${filename}`);

        // สร้าง URL สำหรับเข้าถึงไฟล์ (Relative path)
        // เช่น /storage/radar_images/radar_123456.png
        const publicPath = `/storage/radar_images/${filename}`;

        // 4. Save to Database (ใช้ SQL โดยตรงตามไฟล์ model)
        // เราบันทึกทั้ง filename, filepath (url), และ source_url ต้นฉบับ
        const insertQuery = `
            INSERT INTO radar_images (filename, filepath, source_url) 
            VALUES ($1, $2, $3) 
            RETURNING *
        `;
        const { rows } = await db.query(insertQuery, [filename, publicPath, imageUrl]);
        
        return { 
            success: true,
            data: rows[0]
        };

    } catch (error) {
        console.error("❌ getLatestRadarImage Error:", error.message);
        throw error;
    }
};

/**
 * Auto fetch radar (ถูกเรียกจาก Scheduler)
 */
exports.autoFetchRadar = async () => {
    console.log(`⏰ [${new Date().toLocaleTimeString()}] Auto Fetch Radar Task...`);
    try {
        const result = await exports.getLatestRadarImage();
        console.log(`✅ Update Radar Success: ${result.data.filename}`);
        return { success: true };
    } catch (error) {
        console.error(`❌ Auto Fetch Failed: ${error.message}`);
        return { success: false, message: error.message };
    }
};

// alias
exports.fetchRadarImage = exports.getLatestRadarImage;