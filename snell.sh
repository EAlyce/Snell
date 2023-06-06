#!/bin/bash

# Create a new user for Snell
sudo adduser snell

# Add the new user to the sudo group (optional)
sudo usermod -aG sudo snell

# Install dependencies based on the Linux distribution
if cat /etc/*-release | grep -q -E -i "debian|ubuntu|armbian|deepin|mint"; then
    sudo apt-get install wget unzip dpkg -y
elif cat /etc/*-release | grep -q -E -i "centos|red hat|redhat"; then
    sudo yum install wget unzip dpkg -y
elif cat /etc/*-release | grep -q -E -i "arch|manjaro"; then
    yes | sudo pacman -S wget dpkg unzip
elif cat /etc/*-release | grep -q -E -i "fedora"; then
    sudo dnf install wget unzip dpkg -y
fi

# Enable BBR
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sysctl net.ipv4.tcp_available_congestion_control

# Download Snell binary
cd ~
ARCHITECTURE=$(dpkg --print-architecture)
if [ "$ARCHITECTURE" = "arm64" ]; then
    ARCHITECTURE="aarch64"
fi
wget -c https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-$ARCHITECTURE.zip
unzip -o snell-server-v4.0.1-linux-$ARCHITECTURE.zip

# Create a systemd service file for Snell
echo -e "[Unit]
Description=snell server
[Service]
User=snell
Group=snell
WorkingDirectory=/root
ExecStartPre=/path/to/pre-start-script.sh
ExecStart=/root/snell-server
ExecStopPost=/path/to/post-stop-script.sh
Restart=always
[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/snell.service

# Execute Snell binary to generate the configuration file
echo "y" | sudo ./snell-server

# Start and enable Snell service
sudo systemctl start snell
sudo systemctl enable snell

echo
echo "Copy the following line to surge"
echo "$(curl -s ipinfo.io/city) = snell, $(curl -s ipinfo.io/ip), $(cat snell-server.conf | grep -i listen | cut --delimiter=':' -f2),psk=$(grep 'psk' snell-server.conf | cut -d= -f2 | tr -d ' '), version=4, tfo=true"
