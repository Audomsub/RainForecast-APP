import torch
import torch.nn as nn
import torch.nn.functional as F

class SimpleRainCNN(nn.Module):
    def __init__(self):
        super(SimpleRainCNN, self).__init__()
        # Input: 1 channel (Grayscale), Output: 32 features
        self.conv1 = nn.Conv2d(1, 32, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        
        # Fully Connected Layer
        # ภาพเข้า 224x224 -> pool 2 ครั้ง -> 56x56
        self.fc1 = nn.Linear(64 * 56 * 56, 128)
        self.fc2 = nn.Linear(128, 1) # Output เดียวคือความน่าจะเป็น (0-1)

    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = x.view(-1, 64 * 56 * 56) # Flatten
        x = F.relu(self.fc1(x))
        x = torch.sigmoid(self.fc2(x)) # Sigmoid ให้ค่า 0-1
        return x