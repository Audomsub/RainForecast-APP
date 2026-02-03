from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import os
import requests 
import tempfile
# เปลี่ยน model import เป็น class ใหม่
from model import RainHybridModel
from preprocess import process_radar_image

app = FastAPI()

# โหลด Model (Hybrid)
print("⏳ Loading Hybrid Model (ResNet18 + CBAM)...")
# โหลด weights ImageNet มาเป็นฐานความรู้
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
        # 1. ดาวน์โหลดรูปภาพ
        print(f"📥 Downloading image from: {req.image_url}")
        response = requests.get(req.image_url, timeout=15)
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to download image from URL")

        # 2. สร้างไฟล์ชั่วคราว
        with tempfile.NamedTemporaryFile(delete=False, suffix=".png") as tmp:
            tmp.write(response.content)
            temp_file_path = tmp.name
        
        # 3. Preprocess (RGB)
        input_tensor = process_radar_image(temp_file_path)
        
        if input_tensor is None:
            raise HTTPException(status_code=500, detail="Image processing failed")

        # 4. Predict
        with torch.no_grad():
            output = model(input_tensor)
            probability = output.item() 

        # 5. ตีความผลลัพธ์
        prob_percent = probability * 100
        level = "Unknown"
        
        if prob_percent < 10:
            level = "No Rain (ไม่มีฝน)"
        elif prob_percent < 30:
            level = "Light Rain (ฝนเล็กน้อย)"
        elif prob_percent < 60:
            level = "Moderate Rain (ฝนปานกลาง)"
        elif prob_percent < 85:
            level = "Heavy Rain (ฝนตกหนัก)"
        else:
            level = "Very Heavy Rain (ฝนตกหนักมาก)"

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
        # 6. ลบไฟล์ชั่วคราว
        if temp_file_path and os.path.exists(temp_file_path):
            os.remove(temp_file_path)