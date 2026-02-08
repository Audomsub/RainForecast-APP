import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os
import glob
from model import RainForecastModel # เรียกใช้ Model เดิมของคุณ

# --- CONFIG ---
DATASET_DIR = "rain_dataset"
BATCH_SIZE = 4
EPOCHS = 20
LEARNING_RATE = 1e-4
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- Custom Dataset Loader ---
class RainDataset(Dataset):
    def __init__(self, data_dir):
        self.files = sorted(glob.glob(os.path.join(data_dir, "*.npz")))

    def __len__(self):
        return len(self.files)

    def __getitem__(self, idx):
        data = np.load(self.files[idx])
        # X: (5, 1, 800, 800), Y: (1, 800, 800)
        x = torch.from_numpy(data['x']).float()
        y = torch.from_numpy(data['y']).float()
        return x, y

def train():
    print(f"🚀 เริ่มต้นการเทรนบนอุปกรณ์: {DEVICE}")
    
    # 1. Prepare Data
    dataset = RainDataset(DATASET_DIR)
    # แบ่งข้อมูล Train 90% / Val 10%
    train_size = int(0.9 * len(dataset))
    val_size = len(dataset) - train_size
    train_set, val_set = torch.utils.data.random_split(dataset, [train_size, val_size])
    
    train_loader = DataLoader(train_set, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_set, batch_size=BATCH_SIZE, shuffle=False)
    
    # 2. Model, Loss, Optimizer
    model = RainForecastModel().to(DEVICE)
    criterion = nn.MSELoss() # ใช้ Mean Squared Error สำหรับภาพ
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)

    # 3. Training Loop
    best_val_loss = float('inf')
    
    for epoch in range(EPOCHS):
        model.train()
        train_loss = 0.0
        
        for inputs, targets in train_loader:
            inputs, targets = inputs.to(DEVICE), targets.to(DEVICE)
            
            optimizer.zero_grad()
            outputs = model(inputs) # Output shape: (Batch, 1, 800, 800)
            
            loss = criterion(outputs, targets)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            
        avg_train_loss = train_loss / len(train_loader)

        # 4. Validation & Accuracy Calculation
        model.eval()
        val_loss = 0.0
        total_acc = 0.0
        
        with torch.no_grad():
            for inputs, targets in val_loader:
                inputs, targets = inputs.to(DEVICE), targets.to(DEVICE)
                outputs = model(inputs)
                loss = criterion(outputs, targets)
                val_loss += loss.item()
                
                # --- คำนวณความแม่นยำ (Pixel-wise Accuracy) ---
                # เราจะเทียบว่า Pixel ที่ทำนาย ตรงกับของจริงแค่ไหน (Error ต่ำ = แม่นยำสูง)
                # สูตร: 1 - Mean Absolute Error
                mae = torch.mean(torch.abs(outputs - targets))
                accuracy = (1.0 - mae.item()) * 100 # แปลงเป็น %
                total_acc += accuracy

        avg_val_loss = val_loss / len(val_loader)
        avg_acc = total_acc / len(val_loader)

        print(f"Epoch [{epoch+1}/{EPOCHS}] "
              f"Loss: {avg_train_loss:.6f} | "
              f"Val Loss: {avg_val_loss:.6f} | "
              f"⭐ Accuracy: {avg_acc:.2f}%")

        # Save Best Model
        if avg_val_loss < best_val_loss:
            best_val_loss = avg_val_loss
            torch.save(model.state_dict(), "rain_model_best.pth")
            print("✅ บันทึกโมเดลที่ดีที่สุดแล้ว (rain_model_best.pth)")

    print("🏁 การเทรนเสร็จสมบูรณ์!")

if __name__ == "__main__":
    train()