# start from a clean base image (replace <version> with the desired release)
FROM  nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8


# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip


# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv (latest) using official installer and create isolated venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment for all subsequent commands
ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli + dependencies needed by it to install ComfyUI
RUN uv pip install comfy-cli pip setuptools wheel


# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.30 --cuda-version 12.8 --nvidia

# Change working directory to ComfyUI


WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client

# Add application code and scripts
ADD src/start.sh handler.py test_input.json  civita_config  download_civita.py ./


RUN chmod +x /start.sh

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

# Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode


CMD ["/start.sh"]
# install custom nodes using comfy-cli

WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/diffusion_models/WanVideo  models/vae/wanvideo

RUN comfy-node-install ComfyUI-WanVideoWrapper comfyui-kjnodes comfyui-logicutils comfyui-videohelpersuite comfyui_essentials


# download models
# Download checkpoints/vae/unet/clip models to include in image based on model type
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" -O "/comfyui/models/vae/wanvideo/Wan2_1_VAE_bf16.safetensors"   --no-check-certificate
RUN  wget  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp16.safetensors" -O "/comfyui/models/clip/umt5_xxl_fp16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors" -O "/comfyui/models/text_encoders/umt5-xxl-enc-bf16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" -O "/comfyui/models/clip/open-clip-xlm-roberta-large-vit-huge-14_visual_fp16.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" -O "/comfyui/models/diffusion_models/WanVideo/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" --no-check-certificate
RUN  wget  "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors" -O "/comfyui/models/checkpoints/flux1-dev-fp8.safetensors" --no-check-certificate

RUN python /download_civita.py "https://civitai.com/api/download/models/1475095" "/comfyui/models/loras/"
RUN python /download_civita.py "https://civitai.com/api/download/models/1517164" "/comfyui/models/loras/"

# Copy local static input files into the ComfyUI input directory (delete if not needed)
# Assumes you have an 'input' folder next to your Dockerfile
#COPY input/ /comfyui/input/


