from PIL import Image
import torchvision.transforms as transforms
import torch
import cv2
import numpy as np
import base64
import requests

# ค่ามาตรฐานสำหรับ Normalize (ImageNet Stats)
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

def get_train_transforms():
    """
    ฟังก์ชันสำหรับ Data Augmentation ตอน Train โมเดล
    """
    return transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomRotation(degrees=15),
        transforms.RandomHorizontalFlip(),
        transforms.ColorJitter(brightness=0.1),
        transforms.ToTensor(),
        transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD)
    ])

def process_radar_image(image_path):
    """
    ฟังก์ชันสำหรับ Inference (ใช้งานจริง) - เตรียมภาพเข้า Model
    """
    try:
        # 1. โหลดรูปภาพเป็น RGB
        img = Image.open(image_path).convert("RGB")
        
        # 2. Crop เอาเฉพาะส่วนเรดาร์ (800x800)
        width, height = img.size
        if width < 800 or height < 800:
            img = img.resize((800, 800))
        else:
            img = img.crop((0, 0, 800, 800))
            
        # 3. แปลงเป็น Tensor
        transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD)
        ])
        
        input_tensor = transform(img).unsqueeze(0)
        return input_tensor

    except Exception as e:
        print(f"Error processing image: {e}")
        return None

# ==========================================
# 🚀 ส่วนที่เพิ่มใหม่สำหรับ Visualization
# ==========================================

def create_radar_overlay(image_url):
    """ สร้างภาพ Overlay พื้นหลังใส (Base64) """
    try:
        # 1. โหลดภาพจาก URL
        resp = requests.get(image_url, timeout=10)
        arr = np.asarray(bytearray(resp.content), dtype=np.uint8)
        img = cv2.imdecode(arr, -1)

        if img is None: 
            return None

        # 2. แปลงเป็น RGBA
        rgba = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)

        # 3. กำหนดช่วงสีที่ต้องการ "ลบออก" (สีพื้นหลังดำ/เทาเข้ม)
        lower_bg = np.array([0, 0, 0, 0])
        upper_bg = np.array([50, 50, 50, 255])

        # 4. สร้าง Mask และปรับ Alpha Channel
        mask = cv2.inRange(rgba, lower_bg, upper_bg)
        mask_inv = cv2.bitwise_not(mask)
        rgba[:, :, 3] = mask_inv

        # 5. ส่งกลับเป็น Base64 Image string
        _, buffer = cv2.imencode('.png', rgba)
        return base64.b64encode(buffer).decode('utf-8')

    except Exception as e:
        print(f"Overlay Error: {e}")
        return None

def extract_rain_data(image_url):
    """ ดึงข้อมูลพิกัดและความแรงฝน (Heatmap Data) """
    try:
        # 1. โหลดภาพ
        resp = requests.get(image_url, timeout=10)
        arr = np.asarray(bytearray(resp.content), dtype=np.uint8)
        img = cv2.imdecode(arr, -1)
        
        if img is None: 
            return []

        # 2. Resize เล็กลงเพื่อประมวลผลเร็ว (เช่น 200x200)
        target_size = (200, 200)
        resized = cv2.resize(img, target_size)
        h, w, _ = resized.shape

        heatmap_points = []
        
        # 3. Scan หาจุดที่มีสี (ฝน)
        for y in range(h):
            for x in range(w):
                b, g, r = resized[y, x]
                
                # กรองสีดำออก (ไม่ใช่ฝน)
                if not (r < 50 and g < 50 and b < 50):
                    # คำนวณความแรงฝน 0.0 - 1.0
                    intensity = (int(r) + int(g)) / 510.0 
                    
                    if intensity > 0.1: 
                        heatmap_points.append({
                            "x": x,            
                            "y": y,            
                            "weight": round(intensity, 2)
                        })

        return heatmap_points

    except Exception as e:
        print(f"Heatmap Data Error: {e}")
        return []