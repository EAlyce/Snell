#!/bin/bash

install_dependencies() {
  if cat /etc/*-release | grep -q -E -i "debian|ubuntu|armbian|deepin|mint"; then
    apt-get install wget unzip dpkg -y
  elif cat /etc/*-release | grep -q -E -i "centos|red hat|redhat"; then
    yum install wget unzip dpkg -y
  elif cat /etc/*-release | grep -q -E -i "arch|manjora"; then
    yes | pacman -S wget dpkg unzip
  elif cat /etc/*-release | grep -q -E -i "fedora"; then
    dnf install wget unzip dpkg -y
  fi
}

enable_bbr() {
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
  sysctl -p
  sysctl net.ipv4.tcp_available_congestion_control
}

download_binary() {
  local ARCHITECTURE=$(dpkg --print-architecture)
  if [[ "$ARCHITECTURE" == "arm64" ]]; then
    ARCHITECTURE="aarch64"
  fi
  wget -c https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-$ARCHITECTURE.zip
  unzip -o snell-server-v4.0.1-linux-$ARCHITECTURE.zip
}

create_and_start_service() {
  echo -e "[Unit]\nDescription=snell server\n[Service]\nUser=root\nWorkingDirectory=/root\nExecStart=/root/snell-server\nRestart=always\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/snell.service
  chmod 644 /etc/systemd/system/snell.service
  systemctl daemon-reload
  systemctl start snell
  systemctl enable snell
  if systemctl is-active --quiet snell
  then
    echo "Snell service started successfully"
  else
    echo "Failed to start Snell service"
    exit 1
  fi
}

print_profile() {
  local city=$(curl -fs ipinfo.io/city)
  local ip=$(curl -fs ipinfo.io/ip# Let's search for the correct way to extract value from .conf file using grep and cut.
search("bash extract value from conf file")
  local listen=$(awk -F "=" '/listen/ {print $2}' snell-server.conf | tr -d ' ')
  local psk=$(awk -F "=" '/psk/ {print $2}' snell-server.conf | tr -d ' ')

  if [[ -z "$city" || -z "$ip" || -z "$listen" || -z "$psk" ]]; then
    echo "Failed to get necessary data for profile. Please check your internet connection and snell-server.conf file."
    exit 1
  fi

  echo
  echo "Copy the following line to surge"
  echo "$city = snell, $ip, $listen, psk=$psk, version=4, tfo=true"
}

main() {
  install_dependencies
  enable_bbr
  download_binary
  create_and_start_service
  print_profile
}

main
