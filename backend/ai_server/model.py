import torch
import torch.nn as nn
from torchvision import models

# --- 1. ส่วนประกอบของ Attention Mechanism (CBAM) ---
class ChannelAttention(nn.Module):
    def __init__(self, in_planes, ratio=16):
        super(ChannelAttention, self).__init__()
        self.avg_pool = nn.AdaptiveAvgPool2d(1)
        self.max_pool = nn.AdaptiveMaxPool2d(1)
        self.fc1   = nn.Conv2d(in_planes, in_planes // ratio, 1, bias=False)
        self.relu1 = nn.ReLU()
        self.fc2   = nn.Conv2d(in_planes // ratio, in_planes, 1, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg_out = self.fc2(self.relu1(self.fc1(self.avg_pool(x))))
        max_out = self.fc2(self.relu1(self.fc1(self.max_pool(x))))
        out = avg_out + max_out
        return self.sigmoid(out)

class SpatialAttention(nn.Module):
    def __init__(self, kernel_size=7):
        super(SpatialAttention, self).__init__()
        padding = 3 if kernel_size == 7 else 1
        self.conv1 = nn.Conv2d(2, 1, kernel_size, padding=padding, bias=False)
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        avg_out = torch.mean(x, dim=1, keepdim=True)
        max_out, _ = torch.max(x, dim=1, keepdim=True)
        x = torch.cat([avg_out, max_out], dim=1)
        x = self.conv1(x)
        return self.sigmoid(x)

class CBAM(nn.Module):
    def __init__(self, in_planes, ratio=16, kernel_size=7):
        super(CBAM, self).__init__()
        self.ca = ChannelAttention(in_planes, ratio)
        self.sa = SpatialAttention(kernel_size)

    def forward(self, x):
        x = x * self.ca(x) # เน้น "Feature ไหนสำคัญ" (ฝนหนัก/เบา)
        x = x * self.sa(x) # เน้น "ตรงไหนสำคัญ" (ตำแหน่งก้อนเมฆ)
        return x

# --- 2. โมเดลหลัก: Hybrid (ResNet + Attention) ---
class RainHybridModel(nn.Module):
    def __init__(self, pretrained=True):
        super(RainHybridModel, self).__init__()
        
        # ใช้ ResNet18 เป็นฐาน (Backbone)
        try:
            from torchvision.models import ResNet18_Weights
            resnet = models.resnet18(weights=ResNet18_Weights.DEFAULT)
        except ImportError:
            resnet = models.resnet18(pretrained=pretrained)

        # ตัด Layer ท้ายๆ ออก เพื่อจะแทรก Attention เข้าไป
        # เราจะเอา Feature Map ออกมาจาก Layer ก่อนถึง AvgPool
        self.features = nn.Sequential(*list(resnet.children())[:-2])
        
        # ResNet18 มี output channels สุดท้าย = 512
        self.attention = CBAM(in_planes=512)
        
        # Classifier ใหม่ของเรา
        self.avgpool = nn.AdaptiveAvgPool2d((1, 1))
        self.flatten = nn.Flatten()
        self.fc = nn.Sequential(
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Dropout(0.5), # ลด Overfitting
            nn.Linear(256, 1)
        )

    def forward(self, x):
        # 1. สกัด Feature ด้วย CNN
        x = self.features(x)
        
        # 2. ปรับปรุง Feature ด้วย Attention
        x = self.attention(x)
        
        # 3. ทำนายผล
        x = self.avgpool(x)
        x = self.flatten(x)
        x = self.fc(x)
        return torch.sigmoid(x) # คืนค่า 0.0 - 1.0