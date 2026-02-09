import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import os
import glob
from model import RainForecastModel
import dataset_tool

DATASET_DIR = "rain_dataset"
MODEL_PATH = "rain_model_best.pth"
BATCH_SIZE = 2
EPOCHS = 75
LEARNING_RATE = 1e-4

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class RainDataset(Dataset):
    def __init__(self, data_dir):
        self.files = sorted(glob.glob(os.path.join(data_dir, "*.npz")))

    def __len__(self):
        return len(self.files)

    def __getitem__(self, idx):
        data = np.load(self.files[idx])
        x = torch.from_numpy(data['x']).float()
        y = torch.from_numpy(data['y']).float()
        return x, y

def run_training():
    print("Starting Auto-Training Process...")

    dataset_tool.create_dataset()

    dataset = RainDataset(DATASET_DIR)
    if len(dataset) < 2:
        print("Not enough data to train")
        return False

    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)

    model = RainForecastModel().to(DEVICE)

    if os.path.exists(MODEL_PATH):
        model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
        print("Loaded existing weights")

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

        print(f"Epoch {epoch+1}/{EPOCHS} Loss: {total_loss/len(loader):.6f}")

    torch.save(model.state_dict(), MODEL_PATH)
    print("Model saved")
    return True
