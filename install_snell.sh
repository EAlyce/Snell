#!/bin/bash
# 作者 Chat GPT
# 自用脚本

echo "请选择 Snell 的版本："
echo "1. v3"
echo "2. v4"
read -p "输入选择（1/2）: " choice

# 检测系统类型
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
  ARCH_SUFFIX="amd64.zip"
elif [ "$ARCH" == "aarch64" ]; then
  ARCH_SUFFIX="aarch64.zip"
else
  echo "不支持的系统架构: $ARCH"
  exit 1
fi

# 根据选择设置软件源
case $choice in
  1) SNELL_URL="https://github.com/xOS/Others/raw/master/snell/v3.0.1/snell-server-v3.0.1-linux-$ARCH_SUFFIX";;
  2) SNELL_URL="https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-$ARCH_SUFFIX";;
  *) echo "无效选择"; exit 1;;
esac

# 安装所需依赖
apt-get install -y wget unzip docker-compose

# 随机端口号
PORT_NUMBER=$(shuf -i 8000-8999 -n 1)
# 随机密码
PASSWORD=$(openssl rand -base64 12)
# 创建特定端口的文件夹
NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
mkdir -p $NODE_DIR
cd $NODE_DIR
# 从URL获取版本号的第一个数字
SNELL_URL="https://github.com/xOS/Others/raw/master/snell/v3.0.1/snell-server-v3.0.1-linux-amd64.zip"
VERSION_NUMBER=$(echo "$SNELL_URL" | grep -oP 'snell-server-v\K[0-9]')
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
ipv6 = false
EOF

# 运行Docker容器
docker-compose pull && docker-compose up -d

# 打印节点内容
echo
if [ "$choice" == "1" ]; then
  echo "- name: Snell$PORT_NUMBER"
  echo "  type: snell"
  echo "  server: $(curl -s ifconfig.me)"
  echo "  port: $PORT_NUMBER"
  echo "  psk: $PASSWORD"
  echo "  version: $VERSION_NUMBER"
  echo "  udp: true"
  echo
  echo "Snell$PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
elif [ "$choice" == "2" ]; then
  echo "Snell$PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
fi
