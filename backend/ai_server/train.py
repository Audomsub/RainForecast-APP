import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os
import glob
from model import RainForecastModel
# ต้องมี dataset_tool.py อยู่โฟลเดอร์เดียวกัน
import dataset_tool 

DATASET_DIR = "rain_dataset"
MODEL_PATH = "rain_model_best.pth"
BATCH_SIZE = 2
EPOCHS = 10
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class RainDataset(Dataset):
    def __init__(self, data_dir):
        self.files = sorted(glob.glob(os.path.join(data_dir, "*.npz")))
    def __len__(self): return len(self.files)
    def __getitem__(self, idx):
        try:
            data = np.load(self.files[idx])
            return torch.from_numpy(data['x']).float(), torch.from_numpy(data['y']).float()
        except:
            return torch.zeros(5, 1, 800, 800), torch.zeros(1, 800, 800)

def run_training():
    print("🔄 Starting Auto-Training...")
    
    # 1. สร้าง Dataset ใหม่
    try:
        dataset_tool.create_dataset()
    except Exception as e:
        print(f"❌ Dataset Error: {e}")
        return False

    dataset = RainDataset(DATASET_DIR)
    if len(dataset) < 2:
        print("⚠️ Not enough data to train.")
        return False

    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    model = RainForecastModel().to(DEVICE)
    
    # Load old weights
    if os.path.exists(MODEL_PATH):
        try:
            model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
            print("✅ Loaded existing weights.")
        except:
            print("⚠️ Loading failed, starting fresh.")

    optimizer = optim.Adam(model.parameters(), lr=1e-4)
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
    print("✅ Training Completed & Saved!")
    return True

if __name__ == "__main__":
    run_training()