// ===============================
// ENV CONFIG (ต้องอยู่บนสุด)
// ===============================
require('../config/env');   // ✅ โหลด env กลาง

const { createClient } = require('@supabase/supabase-js');

<<<<<<< HEAD
// ===============================
// SUPABASE CLIENT
// ===============================
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    console.error("❌ Missing Supabase ENV in admincontroller");
    console.error("SUPABASE_URL =", process.env.SUPABASE_URL);
    console.error("SUPABASE_KEY =", process.env.SUPABASE_KEY);
    throw new Error("Supabase ENV not loaded");
}
=======
const supabaseUrl = 'https://okopzoltzofgefsihcvb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb3B6b2x0em9mZ2Vmc2loY3ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjg3ODYsImV4cCI6MjA4NDgwNDc4Nn0.lcFvT2doqDsDlru5mhkrDcG1dzEdRUCpkAFMqq4futw';
const supabase = createClient(supabaseUrl, supabaseKey);
>>>>>>> ffd6ee810f3cc02508805fb2a7fd6f7678d719e7

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
);

// ===============================
// ONLINE USER TRACKING
// ===============================
let onlineUsers = new Map();

<<<<<<< HEAD
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
=======


const logOnlineTraffic = async () => {
    try {
        const now = Date.now();
        const timeout = 60000; 

        
        for (let [id, lastSeen] of onlineUsers) {
            if (now - lastSeen > timeout) onlineUsers.delete(id);
        }

        const count = onlineUsers.size;

        
        const { error } = await supabase
            .from('online_stats')
            .insert([{ user_count: count }]);

        if (error) throw error;
        console.log(`[${new Date().toLocaleTimeString()}] Traffic Logged: ${count} users`);
    } catch (err) {
        console.error("Failed to log traffic:", err.message);
    }
};


setInterval(logOnlineTraffic, 1800000);



exports.trackOnline = (req, res) => {
    const { deviceId } = req.body || {}; 
    if (deviceId) {
        onlineUsers.set(deviceId, Date.now());
    }
>>>>>>> ffd6ee810f3cc02508805fb2a7fd6f7678d719e7
    res.status(200).json({ success: true });
};


/**
 * Get Online Count
 */
exports.getOnlineCount = (req, res) => {
    const now = Date.now();
    const timeout = 60 * 1000; // 60s

    for (let [id, lastSeen] of onlineUsers) {
<<<<<<< HEAD
        if (now - lastSeen > timeout) {
            onlineUsers.delete(id);
        }
    }

    res.json({ online_count: onlineUsers.size });
=======
        if (now - lastSeen > timeout) onlineUsers.delete(id);
    }
    res.json({ online_count: onlineUsers.size });
};


exports.getTrafficStats = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('online_stats')
            .select('timestamp, user_count')
            .order('timestamp', { ascending: true })
            .limit(24);

        if (error) throw error;
        res.status(200).json(data);
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
>>>>>>> ffd6ee810f3cc02508805fb2a7fd6f7678d719e7
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
<<<<<<< HEAD
            refresh_token: data.session.refresh_token,
            user: {
                id: data.user.id,
                email: data.user.email,
                role: data.user.role || "admin"
            }
=======
            user: { id: data.user.id, email: data.user.email }
>>>>>>> ffd6ee810f3cc02508805fb2a7fd6f7678d719e7
        });
    } catch (error) {
<<<<<<< HEAD
        console.error("❌ loginAdmin error:", error.message);
        res.status(500).json({ 
            success: false, 
            message: "Internal server error",
            error: error.message 
        });
=======
        res.status(500).json({ success: false, message: "Internal server error", error: error.message });
>>>>>>> ffd6ee810f3cc02508805fb2a7fd6f7678d719e7
    }
};
