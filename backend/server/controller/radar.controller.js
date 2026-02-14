const radarService = require("../../service/radar.service");
const aiService = require("../../service/ai.service"); // ✅ เรียกใช้ AI Service
const Radar = require("../radar.model");

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
    const row = await Radar.getLatest();
    res.json(row);
};

exports.getHistory = async(req,res)=>{
    const rows = await Radar.getAll();
    res.json(rows);
};

exports.getById = async(req,res)=>{
    const row = await Radar.getById(req.params.id);
    res.json(row);
};

exports.deleteById = async(req,res)=>{
    await Radar.delete(req.params.id);
    res.json({status:"deleted"});
};

// ==========================================
// 🚀 เพิ่ม Method ใหม่
// ==========================================

exports.getLatestOverlay = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });

        const overlayData = await aiService.getOverlay(latest.filepath);
        res.json(overlayData);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};

exports.getLatestHeatmap = async (req, res) => {
    try {
        const latest = await Radar.getLatest();
        if (!latest) return res.status(404).json({ error: "No radar data available" });

        const heatmapData = await aiService.getHeatmap(latest.filepath);
        res.json(heatmapData);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
};
