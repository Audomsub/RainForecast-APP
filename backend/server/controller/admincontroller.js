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
 * Track Online Device
 */
exports.trackOnline = (req, res) => {
    const { deviceId } = req.body || {}; 
    if (deviceId) {
        onlineUsers.set(deviceId, Date.now());
    }
    res.status(200).json({ success: true });
};

/**
 * Get Online Count
 */
exports.getOnlineCount = (req, res) => {
    const now = Date.now();
    const timeout = 60 * 1000;

    for (let [id, lastSeen] of onlineUsers) {
        if (now - lastSeen > timeout) onlineUsers.delete(id);
    }

    res.json({ online_count: onlineUsers.size });
};

/**
 * Get Traffic Stats (ส่วนที่เพิ่มใหม่เพื่อแก้ Error)
 */
exports.getTrafficStats = (req, res) => {
    // โค้ดตัวอย่างการส่งค่ากลับ (Mockup) ป้องกันโปรแกรม Crash
    // คุณสามารถเขียน Logic จริงๆ เพิ่มเติมตรงนี้ได้
    const now = Date.now();
    const timeout = 60 * 1000;
    
    // Clean up old users first
    for (let [id, lastSeen] of onlineUsers) {
        if (now - lastSeen > timeout) onlineUsers.delete(id);
    }

    res.status(200).json({ 
        success: true,
        message: "Traffic stats retrieved",
        active_users: onlineUsers.size,
        total_hits: onlineUsers.size // ตัวอย่างข้อมูล
    });
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
            refresh_token: data.session.refresh_token,
            user: {
                id: data.user.id,
                email: data.user.email
            }
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: "Internal server error",
            error: error.message 
        });
    }
};