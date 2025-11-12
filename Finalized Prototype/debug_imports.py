#!/usr/bin/env python3

print("=== DEBUGGING DIFFUSERS IMPORT ===")

try:
    import torch
    print(f"✓ PyTorch: {torch.__version__}")
    print(f"✓ CUDA available: {torch.cuda.is_available()}")
except Exception as e:
    print(f"✗ PyTorch import failed: {e}")

try:
    import diffusers
    print(f"✓ Diffusers: {diffusers.__version__}")
except Exception as e:
    print(f"✗ Diffusers import failed: {e}")

# Test each import individually
imports_to_test = [
    "diffusers.DiffusionPipeline",
    "diffusers.StableDiffusionXLImg2ImgPipeline", 
    "diffusers.StableVideoDiffusionPipeline",
    "diffusers.utils.load_image",
    "diffusers.utils.export_to_video"
]

for import_path in imports_to_test:
    try:
        module_path, class_name = import_path.rsplit('.', 1)
        module = __import__(module_path, fromlist=[class_name])
        getattr(module, class_name)
        print(f"✓ {import_path}")
    except Exception as e:
        print(f"✗ {import_path}: {e}")

# Check what's actually available in diffusers
try:
    import diffusers
    print(f"\nAvailable in diffusers module:")
    available = [attr for attr in dir(diffusers) if 'Video' in attr or 'Pipeline' in attr]
    for attr in sorted(available):
        print(f"  - {attr}")
except Exception as e:
    print(f"Error checking diffusers contents: {e}")
