# start from a clean base image (replace <version> with the desired release)
FROM runpod/worker-comfyui:5.1.0-flux1-dev

# install custom nodes using comfy-cli
RUN comfy-node-install comfyui-kjnodes comfyui-ic-light comfyui_ipadapter_plus comfyui_essentials ComfyUI-Hangover-Nodes


RUN  wget  "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors" -O "/comfyui/models/checkpoints/flux1-dev-fp8.safetensors" --no-check-certificate

# Copy local static input files into the ComfyUI input directory (delete if not needed)
# Assumes you have an 'input' folder next to your Dockerfile
