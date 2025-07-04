# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04 AS base

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
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.30 --cuda-version 12.6 --nvidia

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
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

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN=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
# Set default model type if none is provided
ARG MODEL_TYPE=wan

# Change working directory to ComfyUI
WORKDIR /comfyui





# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/diffusion_models/WanVideo  models/vae/wanvideo




# Download checkpoints/vae/unet/clip models to include in image based on model type
RUN  wget  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" -O "/comfyui/models/vae/wanvideo/Wan2_1_VAE_bf16.safetensors"   --no-check-certificate



RUN python /download_civita.py "https://civitai.com/api/download/models/1475095" "/comfyui/models/loras/"
RUN python /download_civita.py "https://civitai.com/api/download/models/1517164" "/comfyui/models/loras/"

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models



# Install ComfyUI dependencies
RUN cd /comfyui/custom_nodes/ \
    && git clone https://github.com/kijai/ComfyUI-WanVideoWrapper \
    && git clone https://github.com/kijai/ComfyUI-KJNodes \
    && git clone https://github.com/aria1th/ComfyUI-LogicUtils \
    && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
    && git clone https://github.com/cubiq/ComfyUI_essentials
#
RUN cd /comfyui/custom_nodes/ComfyUI-WanVideoWrapper \
    && pip3 install -r requirements.txt \
    && cd /comfyui/custom_nodes/ComfyUI-KJNodes\
    && pip3 install -r requirements.txt \
    && cd /comfyui/custom_nodes/ComfyUI-LogicUtils  \
    && pip3 install -r requirements.txt \
    && cd /comfyui/custom_nodes/ComfyUI-VideoHelperSuite \
    && pip3 install -r requirements.txt \
    && cd /comfyui/custom_nodes/ComfyUI_essentials \
    && pip3 install -r requirements.txt \
    &&  cd /comfyui \
    && rm -fr /root/.cache/pip

