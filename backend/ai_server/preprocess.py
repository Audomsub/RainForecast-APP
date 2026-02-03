from PIL import Image
import torchvision.transforms as transforms
import torch

# ค่ามาตรฐานสำหรับ Normalize (ImageNet Stats)
IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]

def get_train_transforms():
    """
    ฟังก์ชันสำหรับ Data Augmentation ตอน Train โมเดล
    """
    return transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomRotation(degrees=15),  # หมุนภาพเล็กน้อย
        transforms.RandomHorizontalFlip(),      # กลับซ้ายขวา
        transforms.ColorJitter(brightness=0.1), # ปรับแสงนิดหน่อย (อย่าเยอะเดี๋ยวสีเพี้ยน)
        transforms.ToTensor(),
        transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD)
    ])

def process_radar_image(image_path):
    """
    ฟังก์ชันสำหรับ Inference (ใช้งานจริง)
    """
    try:
        # 1. โหลดรูปภาพเป็น RGB (สำคัญมากสำหรับ ResNet + Attention)
        img = Image.open(image_path).convert("RGB")
        
        # 2. Crop เอาเฉพาะส่วนเรดาร์ (800x800)
        width, height = img.size
        if width < 800 or height < 800:
            img = img.resize((800, 800))
        else:
            img = img.crop((0, 0, 800, 800))
            
        # 3. แปลงเป็น Tensor
        transform = transforms.Compose([
            transforms.Resize((224, 224)), # ResNet ชอบขนาดนี้
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD)
        ])
        
        input_tensor = transform(img).unsqueeze(0) # เพิ่ม Batch dimension
        return input_tensor

    except Exception as e:
        print(f"Error processing image: {e}")
        return None