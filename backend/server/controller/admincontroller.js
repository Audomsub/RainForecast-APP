// ===============================
// ENV CONFIG (ต้องอยู่บนสุด)
// ===============================
require('../config/env');   // ✅ โหลด env กลาง

const { createClient } = require('@supabase/supabase-js');

// ===============================
// SUPABASE CLIENT
// ===============================
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    console.error("❌ Missing Supabase ENV in admincontroller");
    console.error("SUPABASE_URL =", process.env.SUPABASE_URL);
    console.error("SUPABASE_KEY =", process.env.SUPABASE_KEY);
    throw new Error("Supabase ENV not loaded");
}

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ===============================
// ONLINE USER TRACKING
// ===============================
let onlineUsers = new Map();

// ===============================
// CONTROLLERS
// ===============================

/**
 * Track Online Device
 */
exports.trackOnline = (req, res) => {
    const { deviceId } = req.body || {}; 
    
    if (deviceId) {
        onlineUsers.set(deviceId, Date.now());
    }

    // ตอบกลับเสมอ
    res.status(200).json({ success: true });
};


/**
 * Get Online Count
 */
exports.getOnlineCount = (req, res) => {
    const now = Date.now();
    const timeout = 60 * 1000; // 60s

    for (let [id, lastSeen] of onlineUsers) {
        if (now - lastSeen > timeout) {
            onlineUsers.delete(id);
        }
    }

    res.json({ online_count: onlineUsers.size });
};


/**
 * Admin Login
 */
exports.loginAdmin = async (req, res) => {
    try {
        const { email, password } = req.body || {}; 

        if (!email || !password) {
            return res.status(400).json({ 
                success: false, 
                message: "Email and password are required" 
            });
        }

        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password,
        });

        if (error) {
            return res.status(401).json({ 
                success: false, 
                message: "Invalid email or password" 
            });
        }

        return res.status(200).json({
            success: true,
            message: "Login successful",
            token: data.session.access_token,
            refresh_token: data.session.refresh_token,
            user: {
                id: data.user.id,
                email: data.user.email,
                role: data.user.role || "admin"
            }
        });

    } catch (error) {
        console.error("❌ loginAdmin error:", error.message);
        res.status(500).json({ 
            success: false, 
            message: "Internal server error",
            error: error.message 
        });
    }
};
