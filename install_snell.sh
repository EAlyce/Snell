#!/bin/bash

# 验证当前用户是否为root。
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

sudo apt-get install -y curl wget

# 检测是否已安装Docker
if ! command -v docker &> /dev/null; then
    # 未安装，执行安装命令
    curl -fsSL https://test.docker.com | bash
else
    # 已安装，输出提示信息
    echo "Docker已安装"
fi

# 检测是否已安装Docker Compose
if ! command -v docker-compose &> /dev/null; then
    # 未安装，执行安装命令
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # 检查安装是否成功
    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose安装失败。"
        exit 1
    fi
else
    # 已安装，输出提示信息
    echo "Docker Compose已安装。"
fi

# 输出Docker Compose的版本信息
docker-compose --version

# 定义公网IP获取服务列表
ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")

# 检查网络连接
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "网络连接不可用。"
    exit 1
fi

# 循环尝试获取公网IP
public_ip=""
for service in "${ip_services[@]}"; do
    public_ip=$(curl -s "$service")
    if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "公网IP: $public_ip"
        break
    else
        echo "$service 无法获取公网IP"
        sleep 1
    fi
done

# 检查是否成功获取公网IP
if [[ ! "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "所有服务都无法获取公网IP。"
    exit 1
fi

# 检查网络连接
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "网络连接不正常。无法获取城市名。"
    exit 1
fi

# 尝试使用ip-api.com获取城市名
LOCATION=$(curl -s "http://ip-api.com/line?fields=city")

# 如果失败，尝试使用ipinfo.io获取城市名
if [ -z "$LOCATION" ]; then
    LOCATION=$(curl -s ipinfo.io/city)
fi

# 如果还是失败，尝试使用ip-api.io获取城市名
if [ -z "$LOCATION" ]; then
    LOCATION=$(curl -s "https://ip-api.io/json" | jq -r .city)
fi

# 如果所有服务都失败，输出错误消息
if [ -z "$LOCATION" ]; then
    echo "无法获取城市名。"
else
    echo "主机位置：$LOCATION"
fi

# 设置PATH变量，包括了常见的系统二进制文件路径
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# 定义路径变量
resolv_conf="/etc/resolv.conf"

# 检查原文件是否存在，如果不存在则创建一个新的空文件
if [ ! -f "${resolv_conf}" ]; then
    echo "文件 ${resolv_conf} 不存在，正在创建新文件。"
    touch "${resolv_conf}"
fi

# 如果备份文件已经存在，直接覆盖它
if [ -f "${resolv_conf}.backup" ]; then
    cp -v "${resolv_conf}" "${resolv_conf}.backup"
fi

echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 如果必要，强制结束任何剩余的 apt、dpkg
sudo pkill -9 apt || true
sudo pkill -9 dpkg || true

# 检查锁文件是否存在，如果存在则移除它们
if [ -f "/var/lib/dpkg/lock-frontend" ]; then
    sudo rm -f /var/lib/dpkg/lock-frontend
fi
if [ -f "/var/lib/apt/lists/lock" ]; then
    sudo rm -f /var/lib/apt/lists/lock
fi

# 配置未配置的包
sudo dpkg --configure -a

# 更新包列表
sudo apt-get update -y

# 安装软件包
sudo apt-get install -y curl wget git vim nano sudo iptables python3 python3-pip net-tools unzip zip gcc g++ make jq netcat-traditional iptables-persistent

# 更新包和依赖
sudo apt-get upgrade -y

# 清理垃圾
sudo apt autoremove -y

# 检查/proc/sys/net/ipv4/tcp_fastopen文件是否存在，如果存在则启用TFO客户端功能
if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
    echo 3 | sudo tee /proc/sys/net/ipv4/tcp_fastopen
fi

# 如果您使用的是iptables，允许TFO数据包
sudo iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT

# Linux 优化
wget https://raw.githubusercontent.com/ExaAlice/ToolboxScripts/master/Linux.sh -O Linux.sh && chmod +x Linux.sh && ./Linux.sh

# 检查当前内核版本是否支持BBR
KERNEL_VER=$(uname -r | cut -d- -f1)
SUPPORT_BBR=$(echo "$KERNEL_VER 4.9" | awk '{print ($1 >= $2)}')

if [ "$SUPPORT_BBR" -eq "1" ]; then
    modprobe tcp_bbr &>/dev/null
    if grep -wq bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
        echo "BBR已经启用。"
    else
        echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
    fi
else
    echo "当前内核版本不支持BBR。"
fi

# 应用系统参数更改
if sysctl -p; then
    . ~/.bashrc
    echo "Successful kernel optimization - Powered by apad.pro"
else
    echo "应用系统参数更改失败。"
fi

# 检测系统架构
ARCH=$(uname -m)

echo "请选择 Snell 的版本："
echo "1. v3"
echo "2. v4"
read -p "输入选择（默认选择2）: " choice

# 如果输入不是2，则默认选择1
if [[ "$choice" != "1" ]]; then
  choice="2"
fi

BASE_URL=""
SUB_PATH=""

case $choice in
  1) BASE_URL="https://github.com/xOS/Others/raw/master/snell"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
  2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.0.1"; VERSION_NUMBER="4" ;;
  *) echo "无效选择"; exit 1 ;;
esac

[[ "$ARCH" == "aarch64" ]] && ARCH_TYPE="linux-aarch64.zip" || ARCH_TYPE="linux-amd64.zip"
SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"

# 排除的端口列表
EXCLUDED_PORTS=(20 21 22 23 25 26 42 53 80 110 135 136 137 138 139 143 443 444 445 465 587 593 1025 1026 1027 1028 1068 1111 1234 1433 1434 1444 1521 2345 3127 3128 3129 3130 3306 3389 4444 5432 5554 5800 5900 6379 7890 8080 8964 8989 9929 9996 4837)

# 随机生成端口号
PORT_NUMBER=$(shuf -i 1000-9999 -n 1)

# 检查端口是否已经被使用或在排除列表中
while nc -z 127.0.0.1 $PORT_NUMBER || [[ " ${EXCLUDED_PORTS[@]} " =~ " ${PORT_NUMBER} " ]]; do
  PORT_NUMBER=$(shuf -i 1000-9999 -n 1)
done

echo "Port $PORT_NUMBER is available."

# 强制开放该端口
sudo iptables -A INPUT -p tcp --dport $PORT_NUMBER -j ACCEPT
echo "端口 $PORT_NUMBER "

# 生成随机密码
PASSWORD=$(openssl rand -base64 12)
echo "密码：$PASSWORD"
echo "正在生成节点，请稍等........."

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

# 使用 Docker Compose 启动容器
docker-compose up -d

# 打印节点内容
echo
if [ "$choice" == "1" ]; then
  echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
  echo "    type: snell"
  echo "    server: $(curl -s ifconfig.me)"
  echo "    port: $PORT_NUMBER"
  echo "    psk: $PASSWORD"
  echo "    version: $VERSION_NUMBER"
  echo "    udp: true"
  echo
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
elif [ "$choice" == "2" ]; then
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
fi