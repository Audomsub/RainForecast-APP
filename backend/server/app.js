const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

// Import Routes
const radarRoutes = require('./routes/radar.routes');
const mapRoutes = require('./routes/map.routes');
const aiRoutes = require('./routes/ai.routes');
const adminRoutes = require('./routes/admin.routes');
require('./scheduler'); // Start Scheduler

const app = express();
app.use(cors());
app.use(express.json());

// Supabase Client
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

// ✅ Route หลัก (Health Check)
app.get('/', (req, res) => {
    res.json({ status: "Online", service: "Rain Forecast Backend" });
});

// ✅ Route สำหรับ Flutter (ดึงผลพยากรณ์ล่าสุด)
app.get('/api/weather/latest', async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('predictions')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(1);

        if (error || !data || data.length === 0) {
            return res.status(404).json({ message: "No prediction data found" });
        }

        const latest = data[0];
        
        // Logic แปลงข้อความ
        let msg = "ไม่มีฝน";
        if (latest.rain_level.includes("Very Heavy")) msg = "⚠️ อันตราย! ฝนตกหนักมาก";
        else if (latest.rain_level.includes("Heavy")) msg = "🌧️ ฝนตกหนัก";
        else if (latest.rain_level.includes("Moderate")) msg = "🌦️ ฝนปานกลาง";
        else if (latest.rain_level.includes("Light")) msg = "☁️ มีฝนเล็กน้อย";

        res.json({
            status: "success",
            timestamp: latest.created_at,
            data: {
                rain_probability: latest.rain_probability,
                rain_level: latest.rain_level,
                message: msg,
                heatmap_image: latest.raw_heatmap_base64
            }
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Register Routes
app.use('/api/radar', radarRoutes);
app.use('/api/map', mapRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/admin', adminRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server is running on port ${PORT}`);
});