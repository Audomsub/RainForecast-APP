const radarService = require("../service/radar.service");
const Radar = require("../model/radar.model");

exports.fetchRadar = async(req,res)=>{
    try{
        // 1. Service ไปดึงรูปมา และ return { filename, filepath, source_url }
        const data = await radarService.fetchRadarImage();
        
        // 2. Model นำไปบันทึก (ตอนนี้มี filepath แล้ว ไม่ error)
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