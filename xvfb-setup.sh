#!/bin/bash

# Xvfb setup script for Sunshine game streaming
set -e

echo "Setting up Xvfb virtual display..."

# Install required packages if not already installed
echo "Checking and installing required packages..."
apt update
apt install -y xvfb x11-xserver-utils mesa-utils xauth

# Create Xvfb systemd service
echo "Creating Xvfb systemd service..."
cat > /etc/systemd/system/xvfb.service << 'EOF'
[Unit]
Description=X Virtual Framebuffer
Before=sunshine.service

[Service]
Type=simple
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5
Environment="DISPLAY=:99"

[Install]
WantedBy=multi-user.target
EOF

# Update sunshine service to use display :99
echo "Updating Sunshine service configuration..."
if [ -f /etc/systemd/system/sunshine.service ]; then
    # Create override directory
    mkdir -p /etc/systemd/system/sunshine.service.d

    # Create override configuration
    cat > /etc/systemd/system/sunshine.service.d/display.conf << 'EOF'
[Service]
Environment="DISPLAY=:99"
Environment="XAUTHORITY=/tmp/.Xauthority"

# Add dependency on Xvfb
[Unit]
After=xvfb.service
Wants=xvfb.service
EOF
    echo "Sunshine service updated to use display :99"
else
    echo "Warning: Sunshine service not found. You'll need to configure it manually."
fi

# Reload systemd and enable Xvfb service
echo "Enabling Xvfb service..."
systemctl daemon-reload
systemctl enable xvfb.service
systemctl start xvfb.service

# Wait for Xvfb to start
sleep 3

# Verify Xvfb is running
echo "Verifying Xvfb installation..."
if DISPLAY=:99 xdpyinfo &>/dev/null; then
    echo "✓ Xvfb is running successfully on display :99"
else
    echo "✗ Xvfb verification failed. Check systemctl status xvfb"
    exit 1
fi

# Test OpenGL rendering
echo "Testing OpenGL rendering..."
if DISPLAY=:99 glxinfo | grep -q "OpenGL renderer"; then
    echo "✓ OpenGL rendering is available"
    DISPLAY=:99 glxinfo | grep "OpenGL renderer"
else
    echo "⚠ OpenGL rendering test failed (this may be normal in containers)"
fi

echo ""
echo "Xvfb setup completed!"
echo "Display :99 is now available for Sunshine"
echo ""
echo "To check status: systemctl status xvfb"
echo "To restart Sunshine with new display: systemctl restart sunshine"
