const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://okopzoltzofgefsihcvb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9rb3B6b2x0em9mZ2Vmc2loY3ZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkyMjg3ODYsImV4cCI6MjA4NDgwNDc4Nn0.lcFvT2doqDsDlru5mhkrDcG1dzEdRUCpkAFMqq4futw';
const supabase = createClient(supabaseUrl, supabaseKey);

let onlineUsers = new Map();

exports.trackOnline = (req, res) => {
    const {deviceId} = req.body;
    if(deviceId){
        onlineUsers.set(deviceId, Date.now());
    }
    res.status(200).json({success: true});

}

exports.getOnlineCount = (req, res) => {
    const now = Date.now();
    const timeout = 60000;
    for (let [id, lastSeen] of onlineUsers) {
        if(now - lastSeen > timeout) onlineUsers.delete(id);
    }
    res.json({online_count: onlineUsers.size});
};

exports.loginAdmin = async (req, res) => {
    try {
        const { email, password } = req.body; 

        const { data, error } = await supabase.auth.signInWithPassword({
            email: email,
            password: password,
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


