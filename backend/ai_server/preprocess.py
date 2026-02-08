from PIL import Image
import torchvision.transforms as transforms
import torch
import cv2
import numpy as np
import base64
import requests
import io

# Config ใหม่ตาม Architecture
INPUT_SIZE = (800, 800)
SEQUENCE_LENGTH = 5

def process_radar_sequence(image_paths_or_urls):
    """
    เตรียมข้อมูลภาพเรดาร์ย้อนหลัง 5 เฟรมเข้าโมเดล
    Input: list ของ path หรือ url (จำนวน 5 ไฟล์) เรียงจากเก่าไปใหม่
    Output: Tensor shape (1, 5, 1, 800, 800)
    """
    if len(image_paths_or_urls) != SEQUENCE_LENGTH:
        print(f"Error: Model requires exactly {SEQUENCE_LENGTH} frames.")
        return None

    tensor_list = []
    
    transform = transforms.Compose([
        transforms.Grayscale(num_output_channels=1), # แปลงเป็นขาว-ดำ (1 channel)
        transforms.Resize(INPUT_SIZE),               # ปรับขนาดเป็น 800x800
        transforms.ToTensor(),                       # แปลงเป็น Tensor 0.0 - 1.0 (Auto normalize)
    ])

    try:
        for img_source in image_paths_or_urls:
            # ตรวจสอบว่าเป็น URL หรือ Path
            if img_source.startswith('http'):
                resp = requests.get(img_source, timeout=5)
                img = Image.open(io.BytesIO(resp.content))
            else:
                img = Image.open(img_source)
            
            # Preprocess
            img_tensor = transform(img) # shape: (1, 800, 800)
            tensor_list.append(img_tensor)

        # Stack รวมเป็น Tensor เดียว: (Time, Channel, H, W) -> (5, 1, 800, 800)
        sequence_tensor = torch.stack(tensor_list, dim=0)
        
        # เพิ่ม Batch dimension ด้านหน้า -> (1, 5, 1, 800, 800)
        return sequence_tensor.unsqueeze(0)

    except Exception as e:
        print(f"Error processing sequence: {e}")
        return None

# --- ฟังก์ชันเดิมสำหรับการแสดงผล (Visualization) คงไว้ตามเดิม หรือปรับใช้ได้ ---

def create_radar_overlay(image_url):
    # (คง code เดิมไว้ได้เลยครับ เพราะใช้แสดงผลหน้าเว็บ ไม่เกี่ยวกับโมเดล)
    try:
        resp = requests.get(image_url, timeout=10)
        arr = np.asarray(bytearray(resp.content), dtype=np.uint8)
        img = cv2.imdecode(arr, -1)
        if img is None: return None
        
        rgba = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
        lower_bg = np.array([0, 0, 0, 0])
        upper_bg = np.array([50, 50, 50, 255])
        mask = cv2.inRange(rgba, lower_bg, upper_bg)
        mask_inv = cv2.bitwise_not(mask)
        rgba[:, :, 3] = mask_inv
        
        _, buffer = cv2.imencode('.png', rgba)
        return base64.b64encode(buffer).decode('utf-8')
    except Exception as e:
        print(f"Overlay Error: {e}")
        return None

def extract_rain_data(image_url):
    # (คง code เดิมไว้ได้เลยครับ)
    try:
        resp = requests.get(image_url, timeout=10)
        arr = np.asarray(bytearray(resp.content), dtype=np.uint8)
        img = cv2.imdecode(arr, -1)
        if img is None: return []

        target_size = (200, 200)
        resized = cv2.resize(img, target_size)
        h, w, _ = resized.shape
        heatmap_points = []
        
        for y in range(h):
            for x in range(w):
                b, g, r = resized[y, x]
                if not (r < 50 and g < 50 and b < 50):
                    intensity = (int(r) + int(g)) / 510.0 
                    if intensity > 0.1: 
                        heatmap_points.append({"x": x, "y": y, "weight": round(intensity, 2)})
        return heatmap_points
    except Exception as e:
        print(f"Heatmap Data Error: {e}")
        return []