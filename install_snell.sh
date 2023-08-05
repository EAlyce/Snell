#!/bin/bash
# 作者 Chat GPT
# 项目地址：https://github.com/ExaAlice/Snell
# Backup old resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.backup

# Set DNS to 1.1.1.1 and 8.8.8.8
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
#安装常用软件
apt update && apt -y upgrade && apt install curl wget git vim nano sudo python3 python3-pip -

# 检查是否安装了 Docker 和 Docker Compose
if ! command -v docker > /dev/null; then
   echo "Docker 未安装. 正在安装 Docker..."
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
fi

if ! command -v docker-compose > /dev/null; then
   echo "Docker Compose 未安装. 正在安装 Docker Compose..."
   sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
fi
# 检查Docker服务是否运行
if ! service --status-all | grep -Fq 'docker'; then
  echo "Docker服务未运行. 正在启动Docker服务..."
  service docker start
fi
# 安装所需依赖
if cat /etc/*-release | grep -q -E -i "debian|ubuntu|armbian|deepin|mint"; then   
  apt-get install -y wget unzip dpkg
elif cat /etc/*-release | grep -q -E -i "centos|red hat|redhat"; then
  yum install -y wget unzip dpkg
elif cat /etc/*-release | grep -q -E -i "arch|manjaro"; then
  yes | pacman -S wget unzip dpkg
elif cat /etc/*-release | grep -q -E -i "fedora"; then
  dnf install -y wget unzip dpkg
  systemctl stop firewalld
  systemctl disable firewalld
fi

# 启用BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf  
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
echo "net.ipv4.udp_mem = 65536 131072 262144" >> /etc/sysctl.conf
echo "net.ipv4.udp_rmem_min = 16384" >> /etc/sysctl.conf
echo "net.ipv4.udp_wmem_min = 16384" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control
# 内核调优
wget https://raw.githubusercontent.com/ExaAlice/Alice/main/Script/LinuxKernelRegulation.sh
chmod +x LinuxKernelRegulation.sh
./LinuxKernelRegulation.sh

# 更新
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y


# 检测系统架构
ARCH=$(uname -m)

echo "请选择 Snell 的版本："
echo "1. v3"
echo "2. v4"
echo "3. 退出脚本"
read -p "输入选择（默认选择1）: " choice

# 如果输入是3，则退出脚本
if [[ "$choice" == "3" ]]; then
  echo "退出脚本中..."
  exit 0
fi

# 如果输入不是2，则默认选择1
if [[ "$choice" != "2" ]]; then
  choice="1"
fifi

# 根据选择和系统架构设置软件源
case $choice in
  1) if [[ "$ARCH" == "aarch64" ]]; then
       SNELL_URL="https://github.com/xOS/Others/raw/master/snell/v3.0.1/snell-server-v3.0.1-linux-aarch64.zip"
     else
       SNELL_URL="https://github.com/xOS/Others/raw/master/snell/v3.0.1/snell-server-v3.0.1-linux-amd64.zip"
     fi
     VERSION_NUMBER="3";;
  2) if [[ "$ARCH" == "aarch64" ]]; then
       SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-aarch64.zip"
     else
       SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-amd64.zip"
     fi
     VERSION_NUMBER="4";;
  *) echo "无效选择"; exit 1;;
esac

# 随机端口号
PORT_NUMBER=$(shuf -i 8000-50000 -n 1)
# 随机密码
PASSWORD=$(openssl rand -base64 12)
# 创建特定端口的文件夹
NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
mkdir -p $NODE_DIR
cd $NODE_DIR

# 创建Docker compose文件
cat > ./docker-compose.yml << EOF
version: "3.8"
services:
  snell:
    image: accors/snell:latest
    container_name: Snell$PORT_NUMBER
    restart: always
    network_mode: host
    environment:
      - SNELL_URL=$SNELL_URL
    volumes:
      - ./snell-conf/snell.conf:/etc/snell-server.conf
EOF

# 创建snell配置文件
mkdir -p ./snell-conf
cat > ./snell-conf/snell.conf << EOF
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = $PASSWORD
tfo = true
obfs = off
ipv6 = false
EOF

# 运行Docker容器
docker-compose pull && docker-compose up -d

# 打印节点内容
echo
if [ "$choice" == "1" ]; then
  LOCATION=$(curl -s ipinfo.io/city)
  echo "- name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
  echo "  type: snell"
  echo "  server: $(curl -s ifconfig.me)"
  echo "  port: $PORT_NUMBER"
  echo "  psk: $PASSWORD"
  echo "  version: $VERSION_NUMBER"
  echo "  udp: true"
  echo
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
elif [ "$choice" == "2" ]; then
  LOCATION=$(curl -s ipinfo.io/city)
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
fi