from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
import torch
import numpy as np
import cv2
import base64
import os

# Import โมเดลและฟังก์ชัน Preprocess ที่แก้ไปก่อนหน้านี้
from model import RainForecastModel
from preprocess import process_radar_sequence, create_radar_overlay, extract_rain_data

app = FastAPI()

# --- 1. โหลด Model (ConvLSTM) ---
print("⏳ Loading RainForecast Model (ConvLSTM)...")
model = RainForecastModel()
# model.load_state_dict(torch.load("path_to_model.pth")) # TODO: โหลด weight เมื่อ Train เสร็จ
model.eval()
print("✅ Model loaded successfully!")

# --- 2. ปรับ Request Body ให้รับเป็น List ---
class PredictRequest(BaseModel):
    image_urls: List[str] # ต้องการ 5 URLs เรียงจาก เก่า -> ใหม่

@app.get("/")
def read_root():
    return {"status": "AI Service (ConvLSTM Sequence) is running"}

@app.post("/predict")
def predict(req: PredictRequest):
    # ตรวจสอบจำนวนภาพ
    if len(req.image_urls) != 5:
        raise HTTPException(status_code=400, detail=f"Model requires exactly 5 images, but got {len(req.image_urls)}")

    try:
        print(f"📥 Processing sequence of {len(req.image_urls)} frames...")
        
        # 1. Preprocess (Download -> Resize 800x800 -> Grayscale -> Tensor)
        input_tensor = process_radar_sequence(req.image_urls) # Shape: (1, 5, 1, 800, 800)
        
        if input_tensor is None:
            raise HTTPException(status_code=500, detail="Image sequence processing failed")

        # 2. Inference
        with torch.no_grad():
            output_tensor = model(input_tensor) # Shape: (1, 1, 800, 800)

        # 3. Post-processing (แปลง Output เป็นข้อมูลที่ Client เข้าใจ)
        
        # ดึงค่าความน่าจะเป็น/ความเข้มฝนจาก Tensor
        prediction_map = output_tensor.squeeze().cpu().numpy() # Shape: (800, 800)
        
        # คำนวณค่าสูงสุดในภาพเพื่อระบุ "ระดับความรุนแรง" (Rain Level)
        max_intensity = np.max(prediction_map)
        prob_percent = max_intensity * 100
        
        level = "Unknown"
        if prob_percent < 10: level = "No Rain (ไม่มีฝน)"
        elif prob_percent < 30: level = "Light Rain (ฝนเล็กน้อย)"
        elif prob_percent < 60: level = "Moderate Rain (ฝนปานกลาง)"
        elif prob_percent < 85: level = "Heavy Rain (ฝนตกหนัก)"
        else: level = "Very Heavy Rain (ฝนตกหนักมาก)"

        # สร้างภาพผลลัพธ์ (Forecast Image) เป็น Base64 เพื่อแสดงผล
        # แปลงค่า 0.0-1.0 เป็น 0-255
        pred_img_byte = (prediction_map * 255).astype(np.uint8)
        # ใส่สี (Color Map) เพื่อให้ดูง่ายขึ้น (Optional: ใช้ JET หรือปล่อยขาวดำ)
        pred_colored = cv2.applyColorMap(pred_img_byte, cv2.COLORMAP_JET)
        
        # Encode เป็น Base64
        _, buffer = cv2.imencode('.png', pred_colored)
        forecast_base64 = base64.b64encode(buffer).decode('utf-8')

        return {
            "model_type": "Encoder-Decoder ConvLSTM",
            "rain_probability": round(float(prob_percent), 2),
            "level": level,
            "forecast_image": forecast_base64, # ภาพพยากรณ์อนาคต
            "input_frames": len(req.image_urls)
        }

    except Exception as e:
        print(f"❌ Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==========================================
# API สำหรับ Utility อื่นๆ (คงเดิม)
# ==========================================

class SingleImageRequest(BaseModel):
    image_url: str

@app.post("/overlay")
def get_overlay(req: SingleImageRequest):
    result = create_radar_overlay(req.image_url)
    if result is None: raise HTTPException(status_code=500, detail="Failed")
    return {"type": "overlay", "data": result}

@app.post("/heatmap")
def get_heatmap(req: SingleImageRequest):
    data = extract_rain_data(req.image_url)
    return {"type": "heatmap_points", "count": len(data), "points": data}