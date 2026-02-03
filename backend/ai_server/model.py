import torch
import torch.nn as nn
import torch.nn.functional as F

class SimpleRainCNN(nn.Module):
    def __init__(self):
        super(SimpleRainCNN, self).__init__()
        # เพิ่ม Layers และ Batch Normalization เพื่อความเสถียรและความแม่นยำ
        self.conv1 = nn.Conv2d(1, 32, kernel_size=3, padding=1)
        self.bn1 = nn.BatchNorm2d(32)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.bn2 = nn.BatchNorm2d(64)
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
        self.bn3 = nn.BatchNorm2d(128)
        
        self.pool = nn.MaxPool2d(2, 2)
        self.dropout = nn.Dropout(0.3) # ป้องกัน Overfitting

        # Input 224x224 -> Pool 3 ครั้ง -> 28x28
        self.fc1 = nn.Linear(128 * 28 * 28, 256)
        self.fc2 = nn.Linear(256, 1) 

    def forward(self, x):
        x = self.pool(F.relu(self.bn1(self.conv1(x))))
        x = self.pool(F.relu(self.bn2(self.conv2(x))))
        x = self.pool(F.relu(self.bn3(self.conv3(x))))
        
        x = x.view(-1, 128 * 28 * 28)
        x = self.dropout(F.relu(self.fc1(x)))
        x = torch.sigmoid(self.fc2(x)) # คืนค่าความน่าจะเป็น 0.0 - 1.0
        return x