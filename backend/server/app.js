const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// ✅ Route 1: Health Check
app.get('/', (req, res) => {
    res.json({ status: "Online", service: "Rain Forecast API" });
});

// ✅ Route 2: API สำหรับ Flutter (ดึงผลล่าสุด)
app.get('/api/weather/latest', async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('predictions')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(1);

        if (error || !data || data.length === 0) {
            return res.status(404).json({ message: "No data" });
        }

        const latest = data[0];
        res.json({
            status: "success",
            timestamp: latest.created_at,
            data: {
                rain_probability: latest.rain_probability,
                rain_level: latest.rain_level,
                heatmap_image: latest.raw_heatmap_base64,
                message: getThaiMessage(latest.rain_level)
            }
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

function getThaiMessage(level) {
    if (level.includes("Very Heavy")) return "ฝนตกหนักมาก อันตราย!";
    if (level.includes("Heavy")) return "ฝนตกหนัก";
    if (level.includes("Moderate")) return "ฝนปานกลาง";
    if (level.includes("Light")) return "มีฝนเล็กน้อย";
    return "ไม่มีฝน";
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));