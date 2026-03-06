require('../config/env');
const { createClient } = require('@supabase/supabase-js');

if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    throw new Error("❌ Missing Supabase ENV");
}

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ===============================
// ONLINE USER TRACKING
// ===============================
let onlineUsers = new Map();

/**
 * Track Online Device (รับ Heartbeat จาก App)
 */
exports.trackOnline = (req, res) => {
    const { deviceId } = req.body || {}; 
    if (deviceId) {
        onlineUsers.set(deviceId, Date.now());
    }
    res.status(200).json({ success: true });
};

/**
 * Get Online Count (สำหรับตัวเลข Real-time)
 */
exports.getOnlineCount = (req, res) => {
    const now = Date.now();
    const timeout = 60 * 1000; // 1 นาที

    // Clean up คนที่หายไปเกิน 1 นาที
    for (let [id, lastSeen] of onlineUsers) {
        if (now - lastSeen > timeout) onlineUsers.delete(id);
    }

    res.json({ online_count: onlineUsers.size });
};

/**
 * Get Traffic Stats (ดึงข้อมูลจริงจาก Supabase มาวาดกราฟ)
 */
exports.getTrafficStats = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('online_stats')
            .select('timestamp, user_count')
            .order('timestamp', { ascending: true })
            .limit(24); // ดึงมา 24 จุดล่าสุด

        if (error) throw error;
        res.status(200).json(data);
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Admin Login
 */
exports.loginAdmin = async (req, res) => {
    try {
        const { email, password } = req.body || {}; 
        if (!email || !password) {
            return res.status(400).json({ success: false, message: "Email and password are required" });
        }

        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });

        if (error) {
            return res.status(401).json({ success: false, message: "Invalid email or password" });
        }

        return res.status(200).json({
            success: true,
            message: "Login successful",
            token: data.session.access_token,
            user: { id: data.user.id, email: data.user.email }
        });
    } catch (error) {
        res.status(500).json({ success: false, message: "Internal server error" });
    }
};

// ==========================================
// 🚀 ระบบบันทึกสถิติอัตโนมัติ (หัวใจสำคัญของกราฟ)
// ==========================================
const saveTrafficToSupabase = async () => {
    const count = onlineUsers.size;
    const { error } = await supabase
        .from('online_stats')
        .insert([{ 
            user_count: count, 
            timestamp: new Date().toISOString() 
        }]);

    if (error) console.error("❌ Stats Sync Error:", error.message);
    else console.log(`📊 Stats Saved: ${count} users`);
};

// บันทึกทุกๆ 10 นาที (ถ้าอยากให้กราฟละเอียดขึ้น ปรับลดตัวเลขได้ครับ)
setInterval(saveTrafficToSupabase, 10 * 60 * 1000);