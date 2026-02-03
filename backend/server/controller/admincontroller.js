// backend/server/controller/admincontroller.js

const loginAdmin = async (req, res) => {
    try {
        // โค้ดสำหรับการตรวจสอบ Login
        const { username, password } = req.body;
        
        // ตัวอย่างการส่ง response (ปรับแก้ตาม logic จริงของคุณ)
        res.json({ message: "Login successful" });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// สำคัญ: ต้อง export เป็น Object ที่มี key ชื่อ loginAdmin
module.exports = {
    loginAdmin
};