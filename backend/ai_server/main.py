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
from train import run_training # ✅ Import ฟังก์ชันจาก train.py

app = FastAPI()

# --- Config ---
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = RainForecastModel().to(device)
MODEL_PATH = "rain_model_best.pth"
is_training = False

def load_weights():
    if os.path.exists(MODEL_PATH):
        try:
            model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
            model.eval()
            print(f"✅ Weights loaded from {MODEL_PATH}")
        except:
            print("⚠️ Failed to load weights.")
    else:
        print("⚠️ No model file found. Running with random weights.")

load_weights()

class PredictRequest(BaseModel):
    image_urls: List[str]

@app.get("/")
def read_root():
    return {"status": "AI Service Running", "training": is_training}

@app.post("/predict")
def predict(req: PredictRequest):
    if len(req.image_urls) != 5:
        raise HTTPException(400, "Need 5 images")
    try:
        input_tensor = process_radar_sequence(req.image_urls)
        if input_tensor is None: raise HTTPException(500, "Image process failed")
        
        with torch.no_grad():
            output = model(input_tensor.to(device))
        
        pred_map = output.squeeze().cpu().numpy()
        max_val = np.max(pred_map)
        rain_prob = min(max_val * 100, 100.0)
        
        level = "No Rain"
        if rain_prob > 80: level = "Very Heavy"
        elif rain_prob > 60: level = "Heavy"
        elif rain_prob > 30: level = "Moderate"
        elif rain_prob > 10: level = "Light"

        heatmap_img = cv2.applyColorMap((pred_map * 255).astype(np.uint8), cv2.COLORMAP_JET)
        heatmap_img[pred_map < 0.05] = 0
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
        if run_training(): load_weights()
    finally:
        is_training = False

@app.post("/train")
def trigger_train(background_tasks: BackgroundTasks):
    if is_training: return {"status": "busy"}
    background_tasks.add_task(train_task)
    return {"status": "started"}