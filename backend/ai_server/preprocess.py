from PIL import Image
import torchvision.transforms as transforms
import torch
import requests
import io

INPUT_SIZE = (800, 800)
SEQUENCE_LENGTH = 5

def process_radar_sequence(image_paths_or_urls):
    if len(image_paths_or_urls) != SEQUENCE_LENGTH:
        print(f"Error: Model requires exactly {SEQUENCE_LENGTH} frames.")
        return None

    tensor_list = []
    transform = transforms.Compose([
        transforms.Grayscale(num_output_channels=1),
        transforms.Resize(INPUT_SIZE),
        transforms.ToTensor(),
    ])

    try:
        for img_source in image_paths_or_urls:
            if img_source.startswith('http'):
                resp = requests.get(img_source, timeout=10)
                img = Image.open(io.BytesIO(resp.content))
            else:
                img = Image.open(img_source)
            
            img_tensor = transform(img)
            tensor_list.append(img_tensor)

        sequence_tensor = torch.stack(tensor_list, dim=0)
        return sequence_tensor.unsqueeze(0) # (1, 5, 1, 800, 800)

    except Exception as e:
        print(f"Error processing sequence: {e}")
        return None