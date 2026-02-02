exports.overlay = (req,res)=>{
res.json({type:"radar_overlay", source:"radar_images"});
};


exports.heatmap = (req,res)=>{
res.json({type:"heatmap", source:"prediction_points"});
};