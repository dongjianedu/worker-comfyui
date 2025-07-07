# start from a clean base image (replace <version> with the desired release)
FROM runpod/worker-comfyui:5.1.0-base
WORKDIR /

# Add application code and scripts
ADD src/start.sh handler.py test_input.json  civita_config  download_civita.py ./


RUN chmod +x /start.sh

CMD ["/start.sh"]
# install custom nodes using comfy-cli

WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/diffusion_models/WanVideo  models/vae/wanvideo

RUN comfy-node-install ComfyUI-WanVideoWrapper ComfyUI-KJNodes ComfyUI-LogicUtils ComfyUI-VideoHelperSuite ComfyUI_essentials


# download models
# Download checkpoints/vae/unet/clip models to include in image based on model type
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" -O "/comfyui/models/vae/wanvideo/Wan2_1_VAE_bf16.safetensors"   --no-check-certificate
RUN  wget  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors" -O "/comfyui/models/clip/umt5_xxl_fp16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors" -O "/comfyui/models/text_encoders/umt5-xxl-enc-bf16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" -O "/comfyui/models/clip/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" -O "/comfyui/models/diffusion_models/WanVideo/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" --no-check-certificate



RUN python /download_civita.py "https://civitai.com/api/download/models/1475095" "/comfyui/models/loras/"
RUN python /download_civita.py "https://civitai.com/api/download/models/1517164" "/comfyui/models/loras/"

# Copy local static input files into the ComfyUI input directory (delete if not needed)
# Assumes you have an 'input' folder next to your Dockerfile
COPY input/ /comfyui/input/


