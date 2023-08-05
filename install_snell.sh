#!/bin/bash
# 作者@ALice
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
echo "- name: Snell$PORT_NUMBER"
echo "  type: snell"
echo "  server: $(curl -s ifconfig.me)"
echo "  port: $PORT_NUMBER"
echo "  psk: $PASSWORD"
echo "  version: $VERSION_NUMBER"
echo "  udp: true"

echo "Snell$PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
