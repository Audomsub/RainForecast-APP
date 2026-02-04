from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import os
import requests 
import tempfile
from model import RainHybridModel
# ✅ เพิ่ม import ฟังก์ชันใหม่
from preprocess import process_radar_image, create_radar_overlay, extract_rain_data 

app = FastAPI()

# โหลด Model (Hybrid)
print("⏳ Loading Hybrid Model (ResNet18 + CBAM)...")
model = RainHybridModel(pretrained=True) 
model.eval()
print("✅ Model loaded successfully!")

class PredictRequest(BaseModel):
    image_url: str

@app.get("/")
def read_root():
    return {"status": "AI Service (Hybrid CNN+Attention) is running"}

@app.post("/predict")
def predict(req: PredictRequest):
    temp_file_path = None
    try:
        print(f"📥 Downloading image from: {req.image_url}")
        response = requests.get(req.image_url, timeout=15)
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to download image")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
            tmp.write(response.content)
            temp_file_path = tmp.name
        
        input_tensor = process_radar_image(temp_file_path)
        
        if input_tensor is None:
            raise HTTPException(status_code=500, detail="Image processing failed")

        with torch.no_grad():
            output = model(input_tensor)
            probability = output.item() 

        prob_percent = probability * 100
        level = "Unknown"
        if prob_percent < 10: level = "No Rain (ไม่มีฝน)"
        elif prob_percent < 30: level = "Light Rain (ฝนเล็กน้อย)"
        elif prob_percent < 60: level = "Moderate Rain (ฝนปานกลาง)"
        elif prob_percent < 85: level = "Heavy Rain (ฝนตกหนัก)"
        else: level = "Very Heavy Rain (ฝนตกหนักมาก)"

        return {
            "model_type": "Hybrid (CNN + Attention)",
            "rain_probability": round(prob_percent, 2),
            "level": level,
            "processed_size": "800x800 -> 224x224 (RGB)"
        }

    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if temp_file_path and os.path.exists(temp_file_path):
            os.remove(temp_file_path)

# ==========================================
# 🚀 API ใหม่สำหรับ Overlay และ Heatmap
# ==========================================

@app.post("/overlay")
def get_overlay(req: PredictRequest): # ใช้ PredictRequest เพราะมี image_url เหมือนกัน
    result = create_radar_overlay(req.image_url)
    if result is None:
        raise HTTPException(status_code=500, detail="Failed to create overlay")
    return {"type": "overlay", "data": result}

@app.post("/heatmap")
def get_heatmap(req: PredictRequest):
    data = extract_rain_data(req.image_url)
    return {"type": "heatmap_points", "count": len(data), "points": data}