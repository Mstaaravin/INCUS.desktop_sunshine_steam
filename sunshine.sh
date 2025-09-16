#!/bin/bash

# Sunshine setup script
set -e

USER_NAME="cmiranda"
USER_HOME="/home/$USER_NAME"
SUNSHINE_URL="https://github.com/LizardByte/Sunshine/releases/download/v2025.628.4510/sunshine.AppImage"
SUNSHINE_DEB="https://github.com/LizardByte/Sunshine/releases/download/v2025.628.4510/sunshine-debian-bookworm-amd64.deb"

echo "Setting up Sunshine for user $USER_NAME..."

# Create necessary directories
mkdir -p "$USER_HOME/.local/bin"
mkdir -p "$USER_HOME/.config/sunshine"

# Set directory permissions
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.local"
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config"

# Download Sunshine AppImage
#echo "Downloading Sunshine AppImage..."
#wget -O "$USER_HOME/.local/bin/sunshine.AppImage" "$SUNSHINE_URL"
#wget -O "$USER_HOME/SUNSHINE_DEB"
#sudo apt install -y "$USER_HOME/SUNSHINE_DEB"

# Set AppImage permissions
#chown "$USER_NAME:$USER_NAME" "$USER_HOME/.local/bin/sunshine.AppImage"
#chmod +x "$USER_HOME/.local/bin/sunshine.AppImage"

# Create symlink
#ln -sf "$USER_HOME/.local/bin/sunshine.AppImage" "$USER_HOME/.local/bin/sunshine"
ln -sf "/usr/bin/sunshine" "$USER_HOME/.local/bin/sunshine"
chown -h "$USER_NAME:$USER_NAME" "$USER_HOME/.local/bin/sunshine"

# Create apps.json configuration file
echo "Creating apps.json configuration..."
cat > "$USER_HOME/.config/sunshine/apps.json" << 'EOF'
{
  "env": {
    "PATH": "$(PATH):$(HOME)/.local/bin",
    "DISPLAY": ":0"
  },
  "apps": [
    {
      "name": "MATE Desktop",
      "detached": ["dbus-run-session -- mate-session"],
      "image-path": "desktop.png"
    },
    {
      "name": "Low Res Desktop",
      "detached": true,
      "image-path": "sunshine.png",
      "cmd": [
        "xrandr",
        "--output", "rdp0",
        "--mode", "1024x768"
        ]
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
    }
  ]
}
EOF

# Set configuration file permissions
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/sunshine/apps.json"

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/sunshine.service << 'EOF'
[Unit]
Description=Sunshine Game Streaming (system service)
After=network.target

[Service]
User=cmiranda
ExecStart=/home/cmiranda/.local/bin/sunshine
Restart=on-failure
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/cmiranda/.Xauthority

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
echo "Enabling Sunshine service..."
systemctl daemon-reload
systemctl enable sunshine.service

echo "Sunshine setup completed!"
echo "Service will start automatically on next reboot."
echo "To start it now: systemctl start sunshine.service"
