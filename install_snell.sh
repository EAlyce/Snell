#!/bin/bash
# 验证当前用户是否为root。
[ "$(id -u)" != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }
# 检测是否已安装Docker
if ! command -v docker &> /dev/null
then
    # 未安装，执行安装命令
    curl -fsSL https://test.docker.com | bash
else
    # 已安装，输出提示信息
    echo "Docker已经安装在系统中。"
fi
# 定义公网IP获取服务列表
ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")

# 循环尝试获取公网IP
for service in "${ip_services[@]}"; do
    public_ip=$(curl -s "$service")
    if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "成功从 $service 获取到公网IP: $public_ip"
        break
    else
        echo "$service 无法获取公网IP"
    fi
done

# 设置PATH变量，包括了常见的系统二进制文件路径
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# 使用export命令将PATH变量导出，这样在当前shell及其子shell中都可以访问这个变量
export PATH


# 定义路径变量
resolv_conf="/etc/resolv.conf"

# 备份原文件
cp "${resolv_conf}" "${resolv_conf}.backup"

# 设置DNS服务器
echo "nameserver 8.8.4.4" > "${resolv_conf}"
echo "nameserver 8.8.8.8" >> "${resolv_conf}"

# 如果必要，强制结束任何剩余的 apt、dpkg
sudo pkill -9 apt
sudo pkill -9 dpkg

# Remove lock files to free up the package manager
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/apt/lists/lock
sudo dpkg --configure -a

# 安装 curl 和其他常用软件
sudo apt-get install -y curl wget git vim nano sudo iptables python3 python3-pip

# 安装额外的工具
sudo apt-get install -y net-tools unzip zip gcc g++ make iptables

sudo apt-get install jq

# 安装netcat-traditional

sudo apt-get install -y netcat-traditional

#更新所有包
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y
# apt full-upgrade -y
sudo apt autoremove -y
# 重启 Docker 服务
sudo systemctl restart docker

# 开始 Docker 守护程序
sudo systemctl start docker

# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 创建 Docker Compose 文件
cat << EOF > docker-compose.yml
version: '3'
services:
  debian_service:
    image: debian:latest
    network_mode: 'host'
    environment:
      - SOME_ENV_VAR
      - ANOTHER_ENV_VAR
EOF

# 使用 Docker Compose 启动容器
docker-compose up -d


# 启用TFO客户端功能
echo 3 > /proc/sys/net/ipv4/tcp_fastopen

# 如果您使用的是iptables，允许TFO数据包
iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT


# Linux 优化
wget https://raw.githubusercontent.com/ExaAlice/ToolboxScripts/master/Linux.sh -O Linux.sh && chmod +x Linux.sh && ./Linux.sh

# 检查当前内核版本是否支持BBR
KERNEL_VER=$(uname -r | cut -d- -f1)
SUPPORT_BBR=$(echo "$KERNEL_VER 4.9" | awk '{print ($1 >= $2)}')

if [ "$SUPPORT_BBR" -eq "1" ]; then
    modprobe tcp_bbr &>/dev/null
    if grep -wq bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
        echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
    fi
else
    echo "当前内核版本不支持BBR。跳过BBR设置。"
fi

sysctl -p && clear && . ~/.bashrc && echo "Successful kernel optimization - Powered by apad.pro"

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
  echo "Port $PORT_NUMBER is in use or in the exclusion list. Generating a new one..."
  PORT_NUMBER=$(shuf -i 1000-9999 -n 1)
done

echo "Port $PORT_NUMBER is available."

# 预先设置debconf的选择
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | sudo debconf-set-selections

# 安装iptables-persistent
sudo apt-get install -y iptables-persistent

# 强制开放该端口
sudo iptables -A INPUT -p tcp --dport $PORT_NUMBER -j ACCEPT
echo "Port $PORT_NUMBER has been opened in iptables."

# 生成随机密码
PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 18)
echo $PASSWORD

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

# 解除Docker限制
# docker ps -q | xargs -I {} sh -c 'docker update --cpus=0 {} && docker update --memory=0 {} && docker update --blkio-weight=0 {} && docker restart {} && echo "已成功解除容器 {} 的所有资源限制。"'

# Docker 保持自启动
docker ps -aq | xargs docker update --restart=always

# 打印节点内容
echo
if [ "$choice" == "1" ]; then
  LOCATION=$(curl -s ipinfo.io/city)
  echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
  echo "    type: snell"
  echo "    server: $(curl -s ifconfig.me)"
  echo "    port: $PORT_NUMBER"
  echo "    psk: $PASSWORD"
  echo "    version: $VERSION_NUMBER"
  echo "    udp: true"
  echo
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true,ip-version=v4-only"
elif [ "$choice" == "2" ]; then
  LOCATION=$(curl -s ipinfo.io/city)
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true,ip-version=v4-only"
fi
