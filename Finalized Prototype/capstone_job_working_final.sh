#!/bin/bash
#SBATCH --job-name=capstone_working_final
#SBATCH --partition=q-hgpu-batch
#SBATCH --gres=gpu:1
#SBATCH --mem-per-cpu=5G
#SBATCH --time=06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --output=capstone_working_final_%j.out
#SBATCH --error=capstone_working_final_%j.err

echo "=========================================="
echo "Capstone VidGen Pipeline (WORKING FINAL)"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"

# Load modules
module purge
module load cuda
module load ffmpeg

# Use the WORKING environment we just created
source ~/anaconda3/etc/profile.d/conda.sh
conda activate poem_vidgen_latest

echo "✓ Using working environment with latest versions:"
python -c "
import torch, diffusers, transformers
print(f'PyTorch: {torch.__version__}')
print(f'Diffusers: {diffusers.__version__}')
print(f'Transformers: {transformers.__version__}')
print(f'CUDA: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
"

# ===== PACKAGE DEPENDENCY CHECK & INSTALLATION =====
echo ""
echo "📦 Checking required packages..."

# Check if openai is installed
python -c "import openai" 2>/dev/null && {
    echo "✅ openai package found"
} || {
    echo "⚠️ openai package missing, installing..."
    pip install openai
    echo "✅ openai package installed"
}

# Check other potentially missing packages
echo "🔍 Installing any missing dependencies:"
pip install pillow pandas numpy matplotlib tqdm bayes-opt

# Verify all required packages
echo "🔍 Verifying all dependencies:"
python -c "
try:
    import torch, diffusers, transformers, openai
    from PIL import Image
    import pandas as pd
    import numpy as np
    import matplotlib.pyplot as plt
    from tqdm import tqdm
    print('✅ All core packages available')
except ImportError as e:
    print(f'❌ Missing package: {e}')
    exit(1)
"

echo "✅ All packages verified!"

# ===== FFMPEG VERIFICATION & BACKUP SETUP =====
echo ""
echo "🎬 Setting up FFmpeg..."

# Check if module loading worked
if command -v ffmpeg &> /dev/null; then
    echo "✅ FFmpeg loaded via module system"
    ffmpeg -version | head -1
else
    echo "⚠️ FFmpeg module failed, trying backup methods..."

    # Try conda installation
    echo "Trying conda installation..."
    conda install -c conda-forge ffmpeg -y &> /dev/null && {
        echo "✅ FFmpeg installed via conda"
    } || {
        echo "Conda failed, downloading static binary..."

        # Download static ffmpeg binary to temp location
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        wget -q -O ffmpeg.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz || {
            echo "❌ Failed to download FFmpeg binary"
            exit 1
        }

        tar -xf ffmpeg.tar.xz
        FFMPEG_DIR=$(find . -type d -name "ffmpeg-*-static" | head -1)
        export PATH="$TEMP_DIR/$FFMPEG_DIR:$PATH"

        # Verify it works
        if command -v ffmpeg &> /dev/null; then
            echo "✅ Static FFmpeg binary ready"
            ffmpeg -version | head -1
        else
            echo "❌ All FFmpeg installation methods failed!"
            exit 1
        fi
    }
fi

# Final verification
echo "🔍 Final FFmpeg check:"
which ffmpeg
ffmpeg -version | head -1 || {
    echo "❌ FFmpeg verification failed!"
    exit 1
}
echo "✅ FFmpeg is ready!"

# Navigate to the correct directory
PROJECT_DIR="$HOME/Capstone VidGen/Finalized Prototype"
cd "$PROJECT_DIR"
echo "✓ Working directory: $(pwd)"

# Verify script exists
if [ ! -f "combined_video_pipeline.py" ]; then
    echo "❌ Script not found in current directory!"
    echo "Directory contents:"
    ls -la
    exit 1
fi

echo "✓ Script found: $(ls -lh combined_video_pipeline.py)"

# Set GPU optimizations
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:1024
export CUDA_LAUNCH_BLOCKING=0

# Create required directories
mkdir -p logs
mkdir -p objective-1-temp-imgGen-metadata
mkdir -p objective-1-temp-vidGen-metadata
mkdir -p objective-1-generatedVid

echo "✓ Created directories:"
ls -la objective-1-*

echo "=========================================="
echo "STARTING POEM VIDEO GENERATION PIPELINE..."
echo "=========================================="
echo "Note: Running in batch mode - automatically proceeding with all poems"

# Run the pipeline with full logging - FIXED: Auto-answer "y" to prompts
echo "y" | timeout 5h python combined_video_pipeline.py 2>&1 | tee logs/pipeline_output_${SLURM_JOB_ID}.log

EXIT_CODE=$?

echo "=========================================="
echo "PIPELINE COMPLETED"
echo "=========================================="
echo "Exit code: $EXIT_CODE"
echo "Total runtime: $((SECONDS/60)) minutes ($SECONDS seconds)"

if [ $EXIT_CODE -eq 0 ]; then
    echo "🎉 SUCCESS! Pipeline completed successfully!"

    # Count generated content
    IMG_COUNT=$(find objective-1-temp-imgGen-metadata -name "*.png" 2>/dev/null | wc -l)
    VID_COUNT=$(find objective-1-generatedVid -name "*.mp4" 2>/dev/null | wc -l)
    LOG_COUNT=$(find logs -name "*.log" 2>/dev/null | wc -l)

    echo ""
    echo "📊 RESULTS SUMMARY:"
    echo "- Generated Images: $IMG_COUNT"
    echo "- Generated Videos: $VID_COUNT"
    echo "- Log files: $LOG_COUNT"

    if [ $IMG_COUNT -gt 0 ] || [ $VID_COUNT -gt 0 ]; then
        echo ""
        echo "📁 Directory sizes:"
        du -sh objective-1-*/ logs/ 2>/dev/null

        echo ""
        echo "🎬 Sample output files:"
        find objective-1-* -name "*.png" -o -name "*.mp4" | head -5 | while read file; do
            echo "  - $file ($(du -h "$file" | cut -f1))"
        done

        echo ""
        echo "✅ Your poem videos are ready!"
    else
        echo "⚠️ No output files generated. Check logs for details."
    fi

elif [ $EXIT_CODE -eq 124 ]; then
    echo "⏰ Pipeline timed out after 5 hours"
    echo "Checking for partial results..."

    IMG_COUNT=$(find objective-1-temp-imgGen-metadata -name "*.png" 2>/dev/null | wc -l)
    VID_COUNT=$(find objective-1-generatedVid -name "*.mp4" 2>/dev/null | wc -l)
    echo "Partial results: $IMG_COUNT images, $VID_COUNT videos"

else
    echo "❌ Pipeline failed with exit code: $EXIT_CODE"
    echo ""
    echo "🔍 Debugging info:"
    echo "Last 30 lines of pipeline log:"
    tail -30 logs/pipeline_output_${SLURM_JOB_ID}.log 2>/dev/null || echo "No log file found"

    echo ""
    echo "Error log content:"
    tail -20 capstone_working_final_${SLURM_JOB_ID}.err 2>/dev/null || echo "No error file"
fi

echo ""
echo "📝 Full log available at: logs/pipeline_output_${SLURM_JOB_ID}.log"
echo "Environment kept as 'poem_vidgen_latest' for debugging"
echo "Completed at $(date)"
