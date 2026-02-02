from PIL import Image
import torchvision.transforms as transforms
import torch

def process_radar_image(image_path):
    try:
        # 1. โหลดรูปภาพ
        img = Image.open(image_path).convert("L") # แปลงเป็นขาวดำ (Grayscale)
        
        # 2. Crop เอาเฉพาะส่วนข้อมูลเรดาร์ (ตัดด้านขวาออกเพื่อให้ได้ 800x800)
        # กรมฝนหลวงมักมี Sidebar ขวามือ เราจะเอา 800x800 ซ้ายบน
        # Box: (left, upper, right, lower)
        width, height = img.size
        
        # ถ้าภาพเล็กกว่า 800x800 ให้ Resize แทนการ Crop
        if width < 800 or height < 800:
            img = img.resize((800, 800))
        else:
            img = img.crop((0, 0, 800, 800))
            
        # 3. แปลงเป็น Tensor และ Normalize
        transform = transforms.Compose([
            transforms.Resize((224, 224)), # ย่อลงเพื่อเข้า Model (CNN ทั่วไปชอบขนาดนี้)
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5], std=[0.5])
        ])
        
        input_tensor = transform(img).unsqueeze(0) # เพิ่ม Batch dimension
        return input_tensor

    except Exception as e:
        print(f"Error processing image: {e}")
        return None