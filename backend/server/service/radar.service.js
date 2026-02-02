const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
require('dotenv').config();

const aiResult = await aiService.getPrediction(publicUrl);

// ตั้งค่า Supabase
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";

const agent = new https.Agent({ rejectUnauthorized: false });

exports.fetchRadarImage = async () => {
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

        // ส่งข้อมูลกลับ (ใช้ publicUrl เป็น filepath)
        return { filename, filepath: publicUrl, source_url: imageUrl };

    } catch (error) {
        console.error("❌ Error in fetchRadarImage:", error.message);
        throw error;
    }
};