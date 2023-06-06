#!/bin/bash

install_dependencies() {
    local cmd=$1
    shift
    for pkg in "$@"; do
        $cmd $pkg
    done
}

if grep -q -E -i "debian|ubuntu|armbian|deepin|mint" /etc/*-release; then
    install_dependencies "apt-get install -y" wget unzip dpkg
elif grep -q -E -i "centos|red hat|redhat" /etc/*-release; then
    install_dependencies "yum install -y" wget unzip dpkg
elif grep -q -E -i "arch|manjaro" /etc/*-release; then
    install_dependencies "yes | pacman -S" wget unzip dpkg
elif grep -q -E -i "fedora" /etc/*-release; then
    install_dependencies "dnf install -y" wget unzip dpkg
fi

# Enable BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control

cd
ARCHITECTURE=$(dpkg --print-architecture)
FILE=snell-server-v4.0.1-linux-aarch64.zip
URL=https://dl.nssurge.com/snell/$FILE

# Download and unzip binary
wget -c $URL
unzip -o $FILE

# Configure and start Snell service
echo -e "[Unit]\nDescription=snell server\n[Service]\nUser=root\nWorkingDirectory=/root\nExecStart=/root/snell-server\nRestart=always\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/snell.service
./snell-server
systemctl start snell
systemctl enable snell

# Print profile
city=$(curl -s ipinfo.io/city)
ip=$(curl -s ipinfo.io/ip)
port=$(grep -i listen snell-server.conf | cut --delimiter=':' -f2)
psk=$(grep 'psk' snell-server.conf | cut -d= -f2 | tr -d ' ')
echo
echo "Copy the following line to surge"
echo "$city = snell, $ip, $port, psk=$psk, version=4, tfo=true"
