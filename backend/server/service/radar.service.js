const axios = require("axios");
const { createClient } = require('@supabase/supabase-js');
const https = require("https");
const fs = require('fs');
const path = require('path');
require('dotenv').config();
const aiService = require('./ai.service'); 

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const API_URL = "https://file.royalrain.go.th/opendata/radar_data/cappi/api.php?station=rongkwang";
const agent = new https.Agent({ rejectUnauthorized: false });

// Path สำหรับเก็บรูปไป Train (ต้องชี้ไปหา folder ของ AI Server)
const AI_RAW_DATA_PATH = path.join(__dirname, '../../ai_server/raw_radar_images');
if (!fs.existsSync(AI_RAW_DATA_PATH)) fs.mkdirSync(AI_RAW_DATA_PATH, { recursive: true });

exports.getLatestRadarImage = async () => {
    try {
        const apiRes = await axios.get(API_URL, { httpsAgent: agent, timeout: 10000 });
        let data = apiRes.data.data || apiRes.data.result;
        if (!data || data.length === 0) throw new Error("No API Data");

        const latest = data[data.length - 1];
        let imageUrl = latest.url.replace("http://", "https://");
        
        // Download Image
        const imgRes = await axios.get(imageUrl, {
            responseType: "arraybuffer",
            timeout: 60000,
            httpsAgent: agent
        });

        const filename = `radar_${Date.now()}.png`;

        // 1. Save Local for Training
        fs.writeFileSync(path.join(AI_RAW_DATA_PATH, filename), imgRes.data);

        // 2. Upload to Supabase
        const { data: uploadData, error: uploadError } = await supabase.storage
            .from('radar-images').upload(filename, imgRes.data, { contentType: 'image/png' });
        
        if (uploadError) throw uploadError;

        const { data: publicUrlData } = supabase.storage.from('radar-images').getPublicUrl(filename);
        return { filename, filepath: publicUrlData.publicUrl };

    } catch (error) {
        throw error;
    }
};

exports.getLastNRadarImages = async (n = 5) => {
    const { data } = await supabase.from('radar_images')
        .select('filepath').order('timestamp', { ascending: false }).limit(n);
    return data ? data.map(r => r.filepath).reverse() : [];
};

exports.autoFetchRadar = async () => {
    let result = { success: false, rain_probability: 0, level: "Waiting" };
    try {
        const { filename, filepath } = await exports.getLatestRadarImage();
        
        // Save to DB
        await supabase.from('radar_images').insert([{ 
            station: 'rongkwang', filename, filepath, timestamp: new Date() 
        }]);

        // Prediction
        const sequenceUrls = await exports.getLastNRadarImages(5);
        if (sequenceUrls.length === 5) {
            console.log("🤖 Predicting...");
            const aiRes = await aiService.getPrediction(sequenceUrls);
            result = { ...result, ...aiRes, success: true };
            console.log(`🧠 Prediction: ${result.level} (${result.rain_probability}%)`);
        }
        return result;
    } catch (error) {
        console.error("Fetch Error:", error.message);
        return { ...result, level: "Error" };
    }
};