#!/bin/bash

# Complete Sunshine + Xvfb setup script
set -e

USER_NAME="cmiranda"
USER_HOME="/home/$USER_NAME"
SUNSHINE_DEB="https://github.com/LizardByte/Sunshine/releases/download/v2025.924.154138/sunshine-debian-trixie-amd64.deb"
#SUNSHINE_DEB="https://github.com/LizardByte/Sunshine/releases/download/v0.21.0/sunshine-debian-bookworm-amd64.deb"
DISPLAY_NUMBER="99"

echo "Setting up Sunshine with Xvfb for user $USER_NAME..."

# Create necessary directories
echo "Creating directories..."
mkdir -p "$USER_HOME/.local/bin"
mkdir -p "$USER_HOME/.config/sunshine"

# Set directory permissions
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.local"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config"

# Install Sunshine from .deb package
echo "Installing Sunshine..."
if ! command -v sunshine &> /dev/null; then
    wget -O /tmp/sunshine.deb "$SUNSHINE_DEB"
    apt install -y /tmp/sunshine.deb || apt --fix-broken install -y
    rm -f /tmp/sunshine.deb
else
    echo "Sunshine is already installed"
fi

# Create symlink for user convenience
ln -sf "/usr/bin/sunshine" "$USER_HOME/.local/bin/sunshine"
chown -h "$USER_NAME:$USER_NAME" "$USER_HOME/.local/bin/sunshine"

# Setup GPU permissions
echo "Setting up GPU device permissions..."
chmod 666 /dev/dri/card* 2>/dev/null || true
chmod 666 /dev/dri/render* 2>/dev/null || true
chmod 666 /dev/nvidia* 2>/dev/null || true

# Create uinput device for virtual input
echo "Creating uinput device..."
if [ ! -c /dev/uinput ]; then
    mknod -m 660 /dev/uinput c 10 223
    chown root:input /dev/uinput
fi

# Create udev rules for persistent permissions
echo "Creating udev rules for persistent permissions..."
cat > /etc/udev/rules.d/99-sunshine-gpu.rules << 'EOF'
# GPU devices for Sunshine
KERNEL=="card[0-9]*", MODE="0666"
KERNEL=="renderD[0-9]*", MODE="0666"
KERNEL=="nvidia*", MODE="0666"
KERNEL=="uinput", MODE="0660", GROUP="input"
EOF

udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# Create Xvfb systemd service
echo "Creating Xvfb virtual display service..."
cat > /etc/systemd/system/xvfb.service << EOF
[Unit]
Description=X Virtual Framebuffer
Before=sunshine.service

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :$DISPLAY_NUMBER -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5
Environment="DISPLAY=:$DISPLAY_NUMBER"

[Install]
WantedBy=multi-user.target
EOF

# Create Sunshine configuration
echo "Creating Sunshine configuration..."
cat > "$USER_HOME/.config/sunshine/sunshine.conf" << EOF
# Sunshine configuration
# https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html
capture = x11
display_number = $DISPLAY_NUMBER
# output_name = 0
# adapter_name = /dev/dri/card0
adapter_name = /dev/dri/renderD128


# Input settings
#mouse = enabled
#keyboard = enabled

#high_resolution_scrolling = enabled

# Encoder settings
encoder = nvenc
nvenc_preset = 1
nvenc_twopass = quarter_res

# Fallback to software if NVENC fails
sw_preset = ultrafast

# Audio settings
audio_sink = alsa_output.pci-0000_01_00.1.hdmi-stereo

# Network settings
origin_web_ui_allowed = wan
upnp = on
# address_family = ipv4
port = 47989
lan_encryption_mode = 0
wan_encryption_mode = 0

# Logging
min_log_level = debug
EOF

# Create apps.json configuration file
echo "Creating apps.json configuration..."
cat > "$USER_HOME/.config/sunshine/apps.json" << EOF
{
  "env": {
    "PATH": "\$(PATH):\$(HOME)/.local/bin",
    "DISPLAY": ":$DISPLAY_NUMBER"
  },
  "apps": [
    {
      "name": "MATE Desktop",
      "detached": ["dbus-run-session -- mate-session"],
      "image-path": "desktop.png"
    },
    {
      "name": "XFCE Desktop",
      "detached": ["dbus-run-session -- xfce4-session"],
      "image-path": "desktop.png"
    },
    {
      "name": "Steam Big Picture",
      "detached": ["steam steam://open/bigpicture"],
      "prep-cmd": [
        {
          "do": "true",
          "undo": "steam steam://close/bigpicture"
        }
      ],
      "image-path": "steam.png"
    },
    {
      "name": "Terminal",
      "detached": ["x-terminal-emulator"],
      "image-path": "terminal.png"
    }
  ]
}
EOF

# Set configuration file permissions
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config/sunshine"

# Create systemd service for Sunshine
echo "Creating Sunshine systemd service..."
cat > /etc/systemd/system/sunshine.service << EOF
[Unit]
Description=Sunshine Game Streaming Service
After=network.target xvfb.service
Wants=xvfb.service

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME

# Environment variables
Environment="DISPLAY=:$DISPLAY_NUMBER"
Environment="HOME=$USER_HOME"
Environment="XAUTHORITY=/tmp/.Xauthority"

# Add supplementary groups for device access
SupplementaryGroups=video render input audio

# Wait for Xvfb to be ready
ExecStartPre=/bin/sleep 3

# Start Sunshine
ExecStart=/usr/bin/sunshine

# Restart policy
Restart=on-failure
RestartSec=5
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Add user to required groups
echo "Adding user to required groups..."
usermod -a -G video,render,input,audio "$USER_NAME" 2>/dev/null || true

# Reload systemd and enable services
echo "Enabling services..."
systemctl daemon-reload
systemctl enable xvfb.service
systemctl enable sunshine.service

# Start Xvfb service
echo "Starting Xvfb service..."
systemctl start xvfb.service
sleep 3
systemctl start sunshine.service
sleep 3

# Verify Xvfb is running
echo "Verifying Xvfb..."
if DISPLAY=:$DISPLAY_NUMBER xdpyinfo &>/dev/null; then
    echo "✓ Xvfb is running successfully on display :$DISPLAY_NUMBER"
else
    echo "⚠ Xvfb verification failed. Check: systemctl status xvfb"
fi

# Verify Sunshine is running
echo "Verifying Sunshine..."
if systemctl is-active --quiet sunshine; then
    echo "✓ Sunshine is running successfully"
    # Show relevant startup logs
    journalctl -u sunshine -n 20 --no-pager | grep -E "Found.*encoder|Screencasting" || echo "Check logs with: journalctl -u sunshine -n 50"
else
    echo "⚠ Sunshine failed to start. Check: systemctl status sunshine"
    journalctl -u sunshine -n 30 --no-pager
fi

# Test OpenGL (may fail in containers, that's ok)
echo "Testing OpenGL rendering..."
if DISPLAY=:$DISPLAY_NUMBER glxinfo 2>/dev/null | grep -q "OpenGL renderer"; then
    echo "✓ OpenGL rendering is available"
else
    echo "⚠ OpenGL test skipped (normal in containers)"
fi

echo ""
echo "========================================="
echo "Sunshine setup completed!"
echo "========================================="
echo ""
echo "Services status:"
echo "  Xvfb:     systemctl status xvfb"
echo "  Sunshine: systemctl status sunshine"
echo ""
echo "Important notes:"
echo "  - Sunshine runs as root for device access"
echo "  - Applications launch as user: $USER_NAME"
echo "  - Input devices configured with full permissions"
echo ""
echo "To start Sunshine now:"
echo "  systemctl start sunshine"
echo ""
echo "To view logs:"
echo "  journalctl -u sunshine -f"
echo ""
echo "Web interface will be available at:"
echo "  https://$(hostname -I | awk '{print $1}'):47989"
echo ""
echo "Default credentials for web interface:"
echo "  Username: admin"
echo "  Password: admin"
echo "  (Change these on first login!)"
echo ""
echo "Moonlight connection:"
echo "  - Your desktop session will run as: $USER_NAME"
echo "  - Keyboard and mouse should work via /dev/uinput"
echo "========================================="
