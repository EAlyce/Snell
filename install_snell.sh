#!/bin/bash
# chmod +x install_snell.sh
# ./install_snell.sh

# 安装所需依赖
apt-get install -y wget unzip docker-compose

# 随机端口号
PORT_NUMBER=$(shuf -i 8000-8999 -n 1)

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
      - SNELL_URL=https://github.com/xOS/Others/raw/master/snell/v3.0.1/snell-server-v3.0.1-linux-amd64.zip
    volumes:
      - ./snell-conf/snell.conf:/etc/snell-server.conf
EOF

# 创建snell配置文件
mkdir -p ./snell-conf
cat > ./snell-conf/snell.conf << EOF
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = As112211
ipv6 = false
EOF

# 运行Docker容器
cd /root/snelldocker
docker-compose pull && docker-compose up -d

# 打印节点内容
echo
echo "Your Snell node has been set up with the following configuration:"
echo "Port Number: $PORT_NUMBER"
echo "PSK: As112211"
echo "Container Name: Snell$PORT_NUMBER"
