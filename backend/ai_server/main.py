from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import os
from model import SimpleRainCNN
from preprocess import process_radar_image

app = FastAPI()

# โหลด Model
model = SimpleRainCNN()
model.eval()

class PredictRequest(BaseModel):
    image_path: str

@app.get("/")
def read_root():
    return {"status": "AI Service is running"}

@app.post("/predict")
def predict(req: PredictRequest):
    if not os.path.exists(req.image_path):
        raise HTTPException(status_code=404, detail="Image file not found")

    # 1. Preprocess
    input_tensor = process_radar_image(req.image_path)
    if input_tensor is None:
        raise HTTPException(status_code=500, detail="Image processing failed")

    # 2. Predict
    with torch.no_grad():
        output = model(input_tensor)
        probability = output.item() 

    # 3. ตีความผลลัพธ์ (Classification Levels)
    # แบ่งตามมาตรฐานความรุนแรงของฝน (ดัดแปลงจาก dBZ scale)
    prob_percent = probability * 100
    level = "Unknown"
    
    if prob_percent < 10:
        level = "No Rain (ไม่มีฝน)"
    elif prob_percent < 30:
        level = "Light Rain (ฝนเล็กน้อย)"      # เทียบเท่าสีเขียว
    elif prob_percent < 60:
        level = "Moderate Rain (ฝนปานกลาง)"   # เทียบเท่าสีเหลือง
    elif prob_percent < 85:
        level = "Heavy Rain (ฝนตกหนัก)"       # เทียบเท่าสีส้ม
    else:
        level = "Very Heavy Rain (ฝนตกหนักมาก)" # เทียบเท่าสีแดง/ม่วง

    return {
        "rain_probability": round(prob_percent, 2),
        "level": level,
        "processed_size": "800x800 (Cropped)"
    }