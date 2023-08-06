#!/bin/bash
# 作者 Chat GPT & Alice
# 项目地址：https://github.com/ExaAlice/Snell
# Backup old resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.backup

# Set DNS to 1.1.1.1 and 8.8.8.8
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 安装 curl 和其他常用软件
sudo apt-get install -y curl wget git vim nano sudo iptables python3 python3-pip

# 安装额外的工具
sudo apt-get install -y net-tools unzip zip gcc g++ make iptables

echo "All tools and libraries installed successfully!"

#更新所有包
echo '1' | sudo apt-get update -y && echo '1' | sudo apt-get upgrade -y && echo '1' | sudo apt-get dist-upgrade -y && echo '1' | sudo apt full-upgrade -y
# Kill all apt and dpkg processes
sudo pkill apt
sudo pkill dpkg

# Remove lock files to free up the package manager
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/apt/lists/lock
sudo dpkg --configure -a

# Restart Docker service
sudo systemctl restart docker

# 检查是否安装了 Docker
if ! command -v docker > /dev/null; then
   echo "Docker 未安装. 正在安装 Docker..."
   # 获取并安装 Docker
   curl -fsSL https://get.docker.com | bash -s docker
fi

# 如果之前安装了 Docker Compose 2.0 以下的版本，请先执行卸载指令：
if [ -f /usr/local/bin/docker-compose ]; then
    sudo rm /usr/local/bin/docker-compose
fi

# 如果之前安装了 Docker Compose 2.0 以上的版本，请先执行卸载指令：
if [ -d ~/.docker/cli-plugins/ ]; then
    rm -rf ~/.docker/cli-plugins/
fi

# 安装 Docker Compose
# 注意，可能需要根据 Docker Compose 的发布情况，修改版本号
DOCKER_COMPOSE_VERSION=`curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4`
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 开始Docker守护程序
sudo systemctl start docker

# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 打印消息，提醒用户注销并重新登录
echo "请注销并重新登录或重启你的系统，以确保组设置生效。"

# 启用BBR
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf  
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control

# 内核调优
wget https://raw.githubusercontent.com/ExaAlice/Alice/main/Script/LinuxKernelRegulation.sh
chmod +x LinuxKernelRegulation.sh
./LinuxKernelRegulation.sh

# 更新
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y

# 询问
read -p "系统优化完成，是否继续部署Snell节点? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]|"") 
        # 当用户输入yes, y或直接按Enter时执行下面的命令
        ;;
    *)
        echo "操作已取消。"
        exit 1
        ;;
esac

# 检测系统架构
ARCH=$(uname -m)

echo "请选择 Snell 的版本："
echo "1. v3"
echo "2. v4"
read -p "输入选择（默认选择1）: " choice

# 如果输入不是2，则默认选择1
if [[ "$choice" != "2" ]]; then
  choice="1"
fi

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

# 排除的端口列表
EXCLUDED_PORTS=(21 22 23 25 53 80 110 443 465 587 3306 3389 5432 5900 6379 8080 1234 1111 2345 7890 8989 8964 9929 4837 1521 1433 1444 1434)

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

# 提示用户是否重启
read -p "你想要重启系统吗? [Y/n] " answer

case $answer in
    y|Y|"") # y、Y或直接按Enter被认为是确认重启
        echo "正在重启系统..."
        sudo reboot
        ;;
    *) # 除了y、Y或直接按Enter的其他任何输入都直接退出脚本
        echo "退出脚本."
        exit 0
        ;;
esac
