const radarService = require("../service/radar.service");
const aiService = require("../service/ai.service");
const Radar = require("../model/radar.model");

// ==========================================
// 🕹️ Manual Fetch (กดสั่งดึงรูปทันที)
// ==========================================
exports.fetchRadar = async (req, res) => {
    try {
        console.log("🔄 Manual Fetch Requested...");
        // Service นี้ทำการดึงรูป + ลบพื้นหลัง + บันทึกลง DB ให้แล้ว
        const result = await radarService.getLatestRadarImage();
        
        if (result.success) {
            res.json({ success: true, data: result.data });
        } else {
            res.status(500).json({ success: false, message: "Failed to fetch radar image" });
        }
    } catch (e) {
        console.error("❌ Fetch Error:", e);
        res.status(500).json({ success: false, error: e.message });
    }
};

// ==========================================
// 📡 Get Latest Image (สำหรับหน้า Map)
// ==========================================
exports.getLatest = async (req, res) => {
    try {
        // 1. ลองดึงจาก Database ก่อน
        let row = await Radar.getLatest();

        // 2. ถ้าไม่มีใน DB (Database ว่างเปล่า) ให้สั่งดึงใหม่ทันที
        if (!row) {
            console.log("⚠️ DB is empty. Fetching fresh data from API...");
            const result = await radarService.getLatestRadarImage();
            if (result.success) {
                row = result.data;
            }
        }

        // 3. ส่งข้อมูลกลับไป
        if (row) {
            res.json({
                success: true,
                data: row
            });
        } else {
            res.status(404).json({ success: false, message: "No radar data available" });
        }
    } catch (e) {
        console.error("❌ Get Latest Error:", e);
        res.status(500).json({ success: false, error: e.message });
    }
};

// ==========================================
// 📜 History & CRUD
// ==========================================
exports.getHistory = async (req, res) => {
    try {
        const rows = await Radar.getAll();
        res.json({ success: true, data: rows });
    } catch (e) {
        console.error("❌ Get History Error:", e);
        res.status(500).json({ success: false, error: e.message });
    }
};

exports.getById = async (req, res) => {
    try {
        const row = await Radar.getById(req.params.id);
        if (!row) return res.status(404).json({ success: false, message: "Not found" });
        res.json({ success: true, data: row });
    } catch (e) {
        res.status(500).json({ success: false, error: e.message });
    }
};

exports.deleteById = async (req, res) => {
    try {
        // ✅ แก้จาก Radar.delete เป็น Radar.deleteById ให้ตรงกับ Model
        await Radar.deleteById(req.params.id);
        res.json({ success: true, message: "Deleted successfully" });
    } catch (e) {
        console.error("❌ Delete Error:", e);
        res.status(500).json({ success: false, error: e.message });
    }
};

// ==========================================
// 🚀 Method สำหรับ Visualization (AI Overlay)
// ==========================================

exports.getLatestOverlay = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });

        // ตรวจสอบว่า aiService มีฟังก์ชันนี้จริงหรือไม่
        if (!aiService.getOverlay) {
             // ถ้าไม่มี ให้ส่ง URL รูปปกติกลับไปก่อน กันแอปพัง
             return res.json({ overlay_url: latest.filepath });
        }

        const overlayData = await aiService.getOverlay(latest.filepath);
        res.json(overlayData);
    } catch (e) {
        console.error("❌ Overlay Error:", e);
        res.status(500).json({ error: e.message });
    }
};

exports.getLatestHeatmap = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });
        
        if (!aiService.getHeatmap) {
             throw new Error("aiService.getHeatmap is not defined");
        }

        const heatmapData = await aiService.getHeatmap(latest.filepath);
        res.json(heatmapData);
    } catch (e) {
        console.error("❌ Heatmap Error:", e);
        res.status(500).json({ error: e.message });
    }
};