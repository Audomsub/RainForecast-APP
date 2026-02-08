import os
import cv2
import numpy as np
import glob
from tqdm import tqdm

# --- CONFIG ---
RAW_DIR = "raw_radar_images"
DATASET_DIR = "rain_dataset"  # เปลี่ยนชื่อให้ตรงกับที่ train.py เรียกใช้
IMG_SIZE = (800, 800)
SEQ_LENGTH = 5
RAIN_THRESHOLD = 0.01  # กรองภาพที่มีฝน (1%)

def create_dataset():
    if not os.path.exists(RAW_DIR):
        os.makedirs(RAW_DIR)
        print(f"Created missing folder: {RAW_DIR}")
        return

    if not os.path.exists(DATASET_DIR):
        os.makedirs(DATASET_DIR)

    files = sorted([f for f in os.listdir(RAW_DIR) if f.endswith(('.png', '.jpg'))])
    print(f"Found {len(files)} raw images.")
    
    if len(files) < SEQ_LENGTH + 1:
        print("Not enough images to create dataset.")
        return

    count = 0
    # ใช้ tqdm แต่เช็คก่อนว่ารันใน mode ไหนเพื่อไม่ให้ log รก
    loop_range = range(len(files) - SEQ_LENGTH)
    
    for i in loop_range:
        input_files = files[i : i + SEQ_LENGTH]
        target_file = files[i + SEQ_LENGTH]

        imgs = []
        valid = True
        
        # Load Input (5 Frames)
        for f in input_files:
            path = os.path.join(RAW_DIR, f)
            img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
            if img is None: 
                valid = False; break
            img = cv2.resize(img, IMG_SIZE).astype(np.float32) / 255.0
            imgs.append(img)
        
        if not valid: continue

        # Load Target (1 Frame)
        target_path = os.path.join(RAW_DIR, target_file)
        target = cv2.imread(target_path, cv2.IMREAD_GRAYSCALE)
        if target is None: continue
        target = cv2.resize(target, IMG_SIZE).astype(np.float32) / 255.0

        # Rain Filter: เก็บเฉพาะรูปที่มีฝน
        if np.mean(target) > RAIN_THRESHOLD:
            X = np.expand_dims(np.array(imgs), axis=1) # (5, 1, 800, 800)
            Y = np.expand_dims(target, axis=0)         # (1, 800, 800)
            
            save_path = os.path.join(DATASET_DIR, f"seq_{count}.npz")
            np.savez_compressed(save_path, x=X, y=Y)
            count += 1

    print(f"Dataset Updated: {count} sequences created.")

if __name__ == "__main__":
    create_dataset()