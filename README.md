# Sunshine Game Streaming Server Setup

Automated server setup for game streaming using **Sunshine** + **XFCE** + **Steam** in LXC/Incus containers with NVIDIA GPU support.

## 📑 Table of Contents

- [Stack](#-stack)
- [Demo Videos](#-demo-videos)
- [Quick Deploy](#-quick-deploy)
- [Configuration](#️-configuration)
- [Moonlight Client](#-moonlight-client)
- [Structure](#-structure)
- [Troubleshooting](#-troubleshooting)
- [Requirements](#-requirements)

## 🎯 Stack

- **Sunshine** - Streaming server with headless Xvfb
- **XFCE Desktop** - Lightweight environment 
- **Steam** - Gaming with multi-arch support
- **NVIDIA drivers** - GPU acceleration
- **XRDP** - Remote access (optional)

## 📺 Demo Videos

**Quick Demo** (Spanish narration): https://studio.youtube.com/video/0wCxjrJudIA  
**Full Deploy Tutorial** (includes Incus setup): https://www.youtube.com/watch?v=ZVPf2jnbcGI

*Note: Audio quality may not be professional-grade due to budget microphones*

## 🚀 Quick Deploy

### LXC/Incus with GPU passthrough

```bash
export CONTAINER_NAME=xfce-steam01

# Create container with cloud-init
incus create images:debian/12/cloud $CONTAINER_NAME \
  -c boot.autostart=true \
  -c security.privileged=true \
  -c security.nesting=true \
  --config=user.user-data="$(cat ~/cloud-init/desktop.yml)"

# NVIDIA GPU passthrough
incus config device add $CONTAINER_NAME nvidia-gpu gpu pci=0000:01:00.0 gputype=physical
incus config device add $CONTAINER_NAME dri-card0 unix-char path=/dev/dri/card0
incus config device add $CONTAINER_NAME dri-renderD128 unix-char path=/dev/dri/renderD128
incus config device add $CONTAINER_NAME nvidia0 unix-char path=/dev/nvidia0
incus config device add $CONTAINER_NAME nvidiactl unix-char path=/dev/nvidiactl
incus config device add $CONTAINER_NAME nvidia-modeset unix-char path=/dev/nvidia-modeset

# Start
incus start $CONTAINER_NAME
```

### Available Scripts

- **`sunshine-complete.sh`** - Full setup (Sunshine + XRDP + services) - **Called automatically by desktop.yml**
- **`sunshine.sh`** - Sunshine only (no XRDP)
- **`xvfb-setup.sh`** - Virtual display only

*The `sunshine-complete.sh` script is automatically downloaded and executed by the cloud-init configuration. It handles the complete setup including Sunshine, XRDP, and all required services.*

## ⚙️ Configuration

### Post-deploy access

```bash
# SSH
ssh cmiranda@<container-ip>

# XRDP3 (if using sunshine-complete.sh and look deploy video why it's necessary)
xfreerdp3 /u:cmiranda /v:<container-ip> /compression-level:0 /dynamic-resolution

# Sunshine Web UI
# https://<container-ip>:47989 (admin/admin)
```

### External network access (change localhost bind)

```bash
# Edit sunshine config
nano /home/cmiranda/.config/sunshine/sunshine.conf

# Add
bind_address = 0.0.0.0
address_family = both

# Restart
systemctl restart sunshine
```

### Pre-configured apps

- **XFCE Desktop** - Full desktop environment
- **Steam Big Picture** - Gaming mode
- **Terminal** - Shell access
- **Sunshine as a Systemd service**

## 🎮 Moonlight Client

1. Install Moonlight client
2. Add host: `<container-ip>`
3. Pair & stream

## 📁 Structure

```
├── desktop.yml              # Main cloud-init config
├── sunshine-complete.sh     # Complete setup (Sunshine + XRDP)
├── sunshine.sh             # Sunshine only  
├── xvfb-setup.sh          # Virtual display only
└── README.md
```

## 🔧 Troubleshooting

```bash
# Sunshine logs
journalctl -u sunshine -f

# Service status
systemctl status sunshine xvfb xrdp

# GPU check
nvidia-smi

# Container logs
incus info $CONTAINER_NAME --show-log
```

## 📋 Requirements

- Debian 12 (Bookworm) host with Incus/LXC
- NVIDIA GPU (recommended)
- Internet access for package downloads
- Moonlight client for streaming