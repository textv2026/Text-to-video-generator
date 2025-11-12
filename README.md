Download the files, set your API key and json file path in combined_video_pipeline.py, then navigate to Finalized Prototype, use the following command to run the main program on a computer with GPU access:
# Submit job and capture ID
JOB_ID=$(sbatch capstone_job_working_final.sh | awk '{print $4}')

echo "Submitted job ID: $JOB_ID"

The generated videos will be found in:
Finalized Prototype\objective-1-generatedVid
