#!/bin/bash
# 定义设置 PATH 的函数
set_custom_path() {
    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(crontab -l | grep -q '^PATH=' && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        # 设置全面的 PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    fi
}

# 调用设置 PATH 函数
set_custom_path
check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    sudo apt-get install -y curl wget || true
}

clean_lock_files() {
    sudo pkill -9 apt || true
    sudo pkill -9 dpkg || true
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
    sudo dpkg --configure -a
}

install_docker_and_compose() {
    # 安装Docker
    command -v docker &> /dev/null || {
        echo "Installing Docker...";
        curl -fsSL https://get.docker.com | bash
    }
    command -v docker &> /dev/null && echo "Docker已安装"

    # 安装Docker Compose
    command -v docker-compose &> /dev/null || {
        echo "Installing Docker Compose...";
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose;
    }
    command -v docker-compose &> /dev/null && echo "Docker Compose已安装" || {
        echo "Docker Compose安装失败。";
        exit 1; 
    }
}

check_network() {
    # 检查网络是否畅通
    ping -c 1 8.8.8.8 &> /dev/null || { echo "网络连接不可用。"; exit 1; }
}

get_public_ip() {
    # 获取公网IP
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""
    for service in "${ip_services[@]}"; do
        public_ip=$(curl -s "$service")
        if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "公网IP: $public_ip"
            break
        else
            echo "$service 无法获取公网IP"
        fi
    done
    [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "所有服务都无法获取公网IP。"; exit 1; }
}

get_location() {
    # 获取主机位置
    location_services=("http://ip-api.com/line?fields=city" "ipinfo.io/city" "https://ip-api.io/json | jq -r .city")
    for service in "${location_services[@]}"; do
        LOCATION=$(curl -s "$service")
        if [ -n "$LOCATION" ]; then
            echo "主机位置：$LOCATION"
            break
        else
            echo "无法从 $service 获取城市名。"
            continue
        fi
    done
    [ -n "$LOCATION" ] || echo "无法获取城市名。"
}
function setup_environment {
  echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf
  # 更新包列表并安装软件包
  sudo apt-get update -y && sudo apt-get install -y iptables
  # 更新包和依赖
  sudo apt update -y && sudo apt upgrade -y
  # apt dist-upgrade -y && apt full-upgrade -y
  [ -f "/proc/sys/net/ipv4/tcp_fastopen" ] && echo 3 | sudo tee /proc/sys/net/ipv4/tcp_fastopen
  docker system prune -af --volumes
  sudo iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT
  curl -o Linux.sh https://raw.githubusercontent.com/EAlyce/ToolboxScripts/master/Linux.sh && chmod +x Linux.sh && ./Linux.sh
}
function select_version {
  echo "请选择 Snell 的版本："
  echo "1. v3"
  echo "2. v4 Surge专属"
  read -p "输入选择（默认选择2）: " choice

  if [[ "$choice" != "1" ]]; then
    choice="2"
  fi

  case $choice in
    1) BASE_URL="https://github.com/xOS/Others/raw/master/snell"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
    2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.0.1"; VERSION_NUMBER="4" ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}

function select_architecture {
  ARCH="$(uname -m)"
  [[ "$ARCH" == "aarch64" ]] && ARCH_TYPE="linux-aarch64.zip" || ARCH_TYPE="linux-amd64.zip"
  SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"
}

function generate_port {
  EXCLUDED_PORTS=(5432 5554 5800 5900 6379 8080 9996)

  PORT_NUMBER=$(shuf -i 5000-9999 -n 1)

  while nc -z 127.0.0.1 $PORT_NUMBER || [[ " ${EXCLUDED_PORTS[@]} " =~ " ${PORT_NUMBER} " ]]; do
    PORT_NUMBER=$(shuf -i 5000-9999 -n 1)
  done
}

function setup_firewall {
  sudo iptables -A INPUT -p tcp --dport $PORT_NUMBER -j ACCEPT
  echo "端口 $PORT_NUMBER "
}

function generate_password {
  PASSWORD=$(openssl rand -base64 12)
  echo "密码：$PASSWORD"
}

function setup_docker {
  NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
  mkdir -p $NODE_DIR
  cd $NODE_DIR

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

  mkdir -p ./snell-conf
  cat > ./snell-conf/snell.conf << EOF
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = $PASSWORD
tfo = true
obfs = off
ipv6 = false
EOF

  docker-compose up -d
}

function print_node {
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
}

main(){
check_root
install_tools
clean_lock_files
install_docker_and_compose
check_network
get_public_ip
get_location
setup_environment
select_version
select_architecture
generate_port
setup_firewall
generate_password
setup_docker
print_node
}
main