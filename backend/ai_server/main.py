import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os
import glob
from model import RainForecastModel
import dataset_tool  # ✅ เรียกใช้ไฟล์ dataset_tool.py

# --- CONFIG ---
DATASET_DIR = "rain_dataset"
MODEL_PATH = "rain_model_best.pth"
BATCH_SIZE = 2
EPOCHS = 75 # ลดจำนวนรอบลงเพื่อให้ Auto Train เสร็จไวขึ้น (ปรับเพิ่มได้)
LEARNING_RATE = 1e-4
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class RainDataset(Dataset):
    def __init__(self, data_dir):
        self.files = sorted(glob.glob(os.path.join(data_dir, "*.npz")))

    def __len__(self):
        return len(self.files)

    def __getitem__(self, idx):
        try:
            data = np.load(self.files[idx])
            x = torch.from_numpy(data['x']).float()
            y = torch.from_numpy(data['y']).float()
            return x, y
        except:
            return torch.zeros(5, 1, 800, 800), torch.zeros(1, 800, 800)

def run_training():
    print("Starting Auto-Training Process...")
    
    # 1. สร้าง Dataset ใหม่จากรูปปัจจุบัน
    try:
        dataset_tool.create_dataset()
    except Exception as e:
        print(f"Dataset Creation Failed: {e}")
        return False

    # 2. ตรวจสอบข้อมูล
    dataset = RainDataset(DATASET_DIR)
    if len(dataset) < 2:
        print("Not enough data to train (Need at least 2 sequences).")
        return False

    print(f"Training on {DEVICE} with {len(dataset)} samples.")
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    # 3. โหลดโมเดล
    model = RainForecastModel().to(DEVICE)
    
    # ถ้ามีโมเดลเดิม ให้โหลดมาเทรนต่อ (Incremental Learning)
    if os.path.exists(MODEL_PATH):
        try:
            model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
            print("Loaded existing weights. Fine-tuning...")
        except:
            print("Existing weights incompatible. Starting fresh.")

    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    criterion = nn.MSELoss()

    # 4. ลูปเทรน
    model.train()
    for epoch in range(EPOCHS):
        total_loss = 0
        for x, y in loader:
            x, y = x.to(DEVICE), y.to(DEVICE)
            
            optimizer.zero_grad()
            output = model(x)
            loss = criterion(output, y)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
        
        avg_loss = total_loss / len(loader)
        print(f"   Epoch {epoch+1}/{EPOCHS} - Loss: {avg_loss:.6f}")

    # 5. บันทึกโมเดลทับไฟล์เดิม
    torch.save(model.state_dict(), MODEL_PATH)
    print(f"Model saved to {MODEL_PATH}")
    return True

if __name__ == "__main__":
    run_training()