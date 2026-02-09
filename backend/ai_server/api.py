from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List
import torch
import numpy as np
import cv2
import base64
import os

# Imports
from model import RainForecastModel
from preprocess import process_radar_sequence
from train import run_training # ✅ เรียกใช้ฟังก์ชันเทรน

app = FastAPI()

# --- Config ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = RainForecastModel().to(device)
MODEL_PATH = "rain_model_best.pth"
is_training = False

def load_weights():
    """ฟังก์ชันโหลดโมเดลใหม่"""
    if os.path.exists(MODEL_PATH):
        try:
            # โหลดโดย map_location เพื่อกัน error กรณีเทรน gpu แต่รัน cpu
            model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
            model.eval()
            print(f"✅ Weights loaded from {MODEL_PATH}")
        except Exception as e:
            print(f"⚠️ Failed to load weights: {e}")
    else:
        print("⚠️ No model file found. Running with random weights.")

# โหลดครั้งแรกตอนเริ่ม Server
load_weights()

class PredictRequest(BaseModel):
    image_urls: List[str]

@app.get("/")
def read_root():
    return {"status": "AI Service Running", "training": is_training}

@app.post("/predict")
def predict(req: PredictRequest):
    if len(req.image_urls) != 5:
        raise HTTPException(400, "Need exactly 5 images.")
    try:
        # 1. Preprocess
        input_tensor = process_radar_sequence(req.image_urls)
        if input_tensor is None: raise HTTPException(500, "Image processing failed.")
        
        # 2. Predict
        with torch.no_grad():
            output = model(input_tensor.to(device))
        
        # 3. Post-process
        pred_map = output.squeeze().cpu().numpy()
        
        # คำนวณ % ฝนตก (ใช้ค่า Max ในภาพ)
        max_val = np.max(pred_map)
        rain_prob = min(max_val * 100, 100.0)
        
        level = "No Rain"
        if rain_prob > 80: level = "Very Heavy Rain"
        elif rain_prob > 60: level = "Heavy Rain"
        elif rain_prob > 30: level = "Moderate Rain"
        elif rain_prob > 10: level = "Light Rain"

        # สร้าง Heatmap (พื้นหลังใส)
        heatmap_img = cv2.applyColorMap((pred_map * 255).astype(np.uint8), cv2.COLORMAP_JET)
        heatmap_img[pred_map < 0.05] = 0 # ตัดส่วนที่ค่าน้อยออก (ให้เป็นสีดำ/ใส)
        _, buf = cv2.imencode('.png', heatmap_img)
        
        return {
            "rain_probability": round(float(rain_prob), 2),
            "level": level,
            "forecast_image": base64.b64encode(buf).decode('utf-8')
        }
    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(500, str(e))

def train_task():
    global is_training
    is_training = True
    try:
        if run_training(): 
            load_weights()
    finally:
        is_training = False

@app.post("/train")
def trigger_train(background_tasks: BackgroundTasks):
    if is_training: return {"status": "busy", "message": "Training in progress"}
    background_tasks.add_task(train_task)
    return {"status": "started", "message": "Training started in background"}