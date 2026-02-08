import os
import cv2
import numpy as np
from PIL import Image
from tqdm import tqdm

# --- CONFIG ---
RAW_IMAGE_DIR = "raw_radar_images"   # โฟลเดอร์เก็บรูปต้นฉบับ
OUTPUT_DIR = "rain_dataset"          # โฟลเดอร์เก็บข้อมูลที่ทำเสร็จแล้ว
IMG_SIZE = (800, 800)
SEQ_LENGTH = 5                       # 5 ภาพย้อนหลัง
RAIN_THRESHOLD = 0.02                # ค่าเฉลี่ยพิกเซลขั้นต่ำ (0.0-1.0) เพื่อระบุว่า "มีฝน"

def create_dataset():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # 1. อ่านไฟล์รูปภาพทั้งหมด
    files = sorted([f for f in os.listdir(RAW_IMAGE_DIR) if f.endswith(('.png', '.jpg'))])
    print(f"📂 พบรูปภาพทั้งหมด: {len(files)} รูป")

    X_data = []
    Y_data = []
    processed_count = 0

    # 2. วนลูปสร้าง Sequence (Sliding Window)
    for i in tqdm(range(len(files) - SEQ_LENGTH)):
        input_files = files[i : i + SEQ_LENGTH]
        target_file = files[i + SEQ_LENGTH]

        # โหลดภาพทั้งหมดใน Sequence
        seq_imgs = []
        is_valid_sequence = True
        
        # --- ตรวจสอบ Input (5 เฟรม) ---
        for f in input_files:
            path = os.path.join(RAW_IMAGE_DIR, f)
            img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
            if img is None:
                is_valid_sequence = False
                break
            
            # Resize & Normalize
            img = cv2.resize(img, IMG_SIZE)
            img = img.astype(np.float32) / 255.0
            seq_imgs.append(img)

        # --- ตรวจสอบ Target (1 เฟรมเฉลย) ---
        if is_valid_sequence:
            path = os.path.join(RAW_IMAGE_DIR, target_file)
            target_img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
            if target_img is None:
                is_valid_sequence = False
            else:
                target_img = cv2.resize(target_img, IMG_SIZE)
                target_img = target_img.astype(np.float32) / 255.0

        if not is_valid_sequence:
            continue

        # --- ⚡ กรองเฉพาะรูปที่มีฝน (Rain Filter) ⚡ ---
        # คำนวณค่าเฉลี่ยความสว่างของภาพเฉลย (Target)
        # ถ้าค่าน้อยเกินไป แสดงว่าท้องฟ้าโปร่ง (ไม่มีฝน) -> ข้าม ไม่เอามา Train
        rain_intensity = np.mean(target_img)
        if rain_intensity < RAIN_THRESHOLD:
            continue 

        # จัด Shape ข้อมูล: (Time, Channel, H, W)
        # Input: (5, 1, 800, 800)
        X = np.expand_dims(np.array(seq_imgs), axis=1)
        # Target: (1, 800, 800) -> Output model เราเป็น (1, 800, 800)
        Y = np.expand_dims(target_img, axis=0)

        # บันทึกไฟล์
        np.savez_compressed(f"{OUTPUT_DIR}/seq_{processed_count}.npz", x=X, y=Y)
        processed_count += 1

    print(f"✅ สร้าง Dataset เสร็จสิ้น: ได้ข้อมูลสำหรับเทรน {processed_count} ชุด (คัดเฉพาะที่มีฝน)")

if __name__ == "__main__":
    create_dataset()