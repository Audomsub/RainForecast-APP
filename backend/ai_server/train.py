import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os
import glob
from model import RainForecastModel
import dataset_tool  # ✅ เรียกใช้ module dataset_tool

# --- CONFIG ---
DATASET_DIR = "rain_dataset"  # ✅ ต้องตรงกับ dataset_tool.py
MODEL_PATH = "rain_model_best.pth"
BATCH_SIZE = 2
EPOCHS = 20 # Render อาจตัดจบถ้าเทรนนานเกินไป แนะนำให้เริ่มที่ 20 ก่อน
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
    print(f"🔄 Starting Auto-Training on {DEVICE}...")
    
    # 1. สร้าง Dataset ใหม่เสมอเมื่อเรียกเทรน
    try:
        print("📦 Updating dataset...")
        dataset_tool.create_dataset()
    except Exception as e:
        print(f"❌ Dataset Error: {e}")
        return False

    # 2. ตรวจสอบข้อมูล
    if not os.path.exists(DATASET_DIR):
        print(f"❌ Folder '{DATASET_DIR}' not found.")
        return False

    dataset = RainDataset(DATASET_DIR)
    if len(dataset) < 2:
        print(f"⚠️ Not enough data ({len(dataset)} samples). Need >= 2.")
        return False

    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    # 3. โหลด/สร้าง Model
    model = RainForecastModel().to(DEVICE)
    if os.path.exists(MODEL_PATH):
        try:
            model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
            print("✅ Loaded previous weights.")
        except:
            print("⚠️ Load failed, starting fresh.")

    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    criterion = nn.MSELoss()

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
        
        print(f"   Epoch {epoch+1}/{EPOCHS} Loss: {total_loss/len(loader):.6f}")

    torch.save(model.state_dict(), MODEL_PATH)
    print(f"💾 Model saved to {MODEL_PATH}")
    return True

if __name__ == "__main__":
    run_training()