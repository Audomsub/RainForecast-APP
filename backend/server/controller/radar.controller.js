const radarService = require("../service/radar.service");
const aiService = require("../service/ai.service"); // ✅ เรียกใช้ AI Service
const Radar = require("../model/radar.model");

exports.fetchRadar = async(req,res)=>{
    try{
        const data = await radarService.fetchRadarImage();
        const saved = await Radar.create(data);
        res.json(saved);
    } catch(e) {
        res.status(500).json({error:e.message});
    }
};

exports.getLatest = async(req,res)=>{
    try {
        const row = await Radar.getLatest();
        res.json(row);
    } catch(e) {
        res.status(500).json({error:e.message});
    }
};

exports.getHistory = async(req,res)=>{
    try {
        const rows = await Radar.getAll();
        res.json(rows);
    } catch(e) {
        res.status(500).json({error:e.message});
    }
};

exports.getById = async(req,res)=>{
    try {
        const row = await Radar.getById(req.params.id);
        res.json(row);
    } catch(e) {
        res.status(500).json({error:e.message});
    }
};

exports.deleteById = async(req,res)=>{
    try {
        await Radar.delete(req.params.id);
        res.json({status:"deleted"});
    } catch(e) {
        res.status(500).json({error:e.message});
    }
};

// ==========================================
// 🚀 Method ใหม่สำหรับ Visualization
// ==========================================

exports.getLatestOverlay = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });

        // ตรวจสอบว่า aiService มีฟังก์ชันนี้จริงหรือไม่
        if (!aiService.getOverlay) {
             throw new Error("aiService.getOverlay is not defined");
        }

        const overlayData = await aiService.getOverlay(latest.filepath);
        res.json(overlayData);
    } catch (e) {
        console.error("Overlay Error:", e);
        res.status(500).json({ error: e.message });
    }
};

exports.getLatestHeatmap = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });
        
        // ตรวจสอบว่า aiService มีฟังก์ชันนี้จริงหรือไม่
        if (!aiService.getHeatmap) {
             throw new Error("aiService.getHeatmap is not defined");
        }

        const heatmapData = await aiService.getHeatmap(latest.filepath);
        res.json(heatmapData);
    } catch (e) {
        console.error("Heatmap Error:", e);
        res.status(500).json({ error: e.message });
    }
};