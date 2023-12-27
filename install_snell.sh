#!/bin/bash
set_custom_path() {
    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(crontab -l | grep -q '^PATH=' && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        # 设置全面的 PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    fi
}

check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    # 隐藏安装工具函数的输出
    sudo apt-get install -y curl wget > /dev/null || true
    sudo apt-get install tmux mosh > /dev/null
}

clean_lock_files() {
    # 隐藏清理锁文件和终止进程函数的输出
    sudo pkill -9 apt > /dev/null || true
    sudo pkill -9 dpkg > /dev/null || true
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock
    sudo dpkg --configure -a > /dev/null
}

# 错误代码
ERR_DOCKER_INSTALL=1
ERR_COMPOSE_INSTALL=2


# 安装Docker和Docker Compose
install_docker_and_compose() {
    # 为 tmux会话创建一个唯一名字
    SESSION_NAME="docker_install_$(date +%s)"

    # 创建新的tmux会话
    tmux new-session -d -s "$SESSION_NAME"

    # 向 tmux会话发送要执行的命令
    tmux send-keys "

    # 在bash上设置错误处理
    set -e

    # 现在，在这个新创建的tmux会话中执行安装过程
    echo \"开始安装...\"

    # 安装Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh 
        sudo sh get-docker.sh
        sudo usermod -aG docker \$USER
    fi

    # 安装Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)\" -o \"/usr/local/bin/docker-compose\"
        sudo chmod +x \"/usr/local/bin/docker-compose\"
    fi

    echo \"安装完成\"

    # 结束当前的bash会话，此时tmux会话也会自动结束
    exit
    " C-m
}

check_network() {
    # 检查网络是否畅通
    ping -c 1 8.8.8.8 &> /dev/null || { echo "网络连接不可用。"; exit 1; }
}



get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "公网IP: $public_ip"
                break
            else
                echo "$service 返回的不是一个有效的IP地址：$public_ip"
            fi
        else
            echo "$service 无法连接或响应太慢"
        fi
        sleep 1  # 在尝试下一个服务之前稍微延迟
    done
    [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "所有服务都无法获取公网IP。"; exit 1; }
}

get_location() {
    # 获取主机位置
    location_services=("http://ip-api.com/line?fields=city" "ipinfo.io/city" "https://ip-api.io/json | jq -r .city")
    for service in "${location_services[@]}"; do
        LOCATION=$(curl -s "$service" 2>/dev/null)
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


# Your function
setup_environment() {


# Set DNS servers
echo -e "nameserver 8.8.4.4\nnameserver 8.8.8.8" > /etc/resolv.conf
echo "DNS servers updated successfully."

# Install necessary packages (non-interactive mode)
export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null
apt-get install -y iptables netfilter-persistent > /dev/null
echo "Necessary packages installed."

# Open UDP port range and save iptables rules using netfilter-persistent
iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null
echo "UDP port range opened."
iptables-save > /etc/iptables/rules.v4
service netfilter-persistent reload > /dev/null
echo "Iptables saved."

# Update packages and dependencies (non-interactive mode)
apt-get upgrade -y > /dev/null
echo "Packages updated."

# Enable TCP fast open if supported
if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
  echo 3 > /proc/sys/net/ipv4/tcp_fastopen > /dev/null
  echo "TCP fast open enabled."
fi

# Docker system prune
docker system prune -af --volumes > /dev/null
echo "Docker system pruned."

# Additional configurations
iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT > /dev/null
echo "SYN packets accepted."

  # 设置脚本名和tmux会话名
  script_name="Linux.sh"
  session_name="${script_name%.*}"  # 去掉文件扩展名

  # 创建新的tmux会话
  tmux new-session -d -s "$session_name"

  # 在tmux中执行以下命令下载、授权并运行脚本
  tmux send-keys -t "$session_name" "curl -o $script_name https://raw.githubusercontent.com/EAlyce/ToolboxScripts/master/$script_name && chmod +x $script_name && ./$script_name && echo '优化完成' && exit" C-m

  # 关闭tmux会话（不等待）
  tmux kill-session -t "$session_name"
}

select_version() {
  echo "请选择 Snell 的版本："
  echo "1. v3"
  echo "2. v4 Surge专属"
  read -p "输入选择（默认选择2）: " choice

  choice="${choice:-2}"

  case $choice in
    1) BASE_URL="https://github.com/xOS/Others/raw/master/snell"; SUB_PATH="v3.0.1/snell-server-v3.0.1"; VERSION_NUMBER="3" ;;
    2) BASE_URL="https://dl.nssurge.com/snell"; SUB_PATH="snell-server-v4.0.1"; VERSION_NUMBER="4" ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}

select_architecture() {
  ARCH="$(uname -m)"
  ARCH_TYPE="linux-amd64.zip"

  if [ "$ARCH" == "aarch64" ]; then
    ARCH_TYPE="linux-aarch64.zip"
  fi

  SNELL_URL="${BASE_URL}/${SUB_PATH}-${ARCH_TYPE}"
}

generate_port() {
  EXCLUDED_PORTS=(5432 5554 5800 5900 6379 8080 9996)

  while true; do
    PORT_NUMBER=$(shuf -i 5000-9999 -n 1)

    if ! nc -z 127.0.0.1 "$PORT_NUMBER" && [[ ! " ${EXCLUDED_PORTS[@]} " =~ " ${PORT_NUMBER} " ]]; then
      break
    fi
  done
}

setup_firewall() {
  sudo iptables -A INPUT -p tcp --dport "$PORT_NUMBER" -j ACCEPT || { echo "Error: Unable to add firewall rule"; exit 1; }
  echo "防火墙规则已添加，允许端口 $PORT_NUMBER 的流量"
}

generate_password() {
  PASSWORD=$(openssl rand -base64 12) || { echo "Error: Unable to generate password"; exit 1; }
  echo "密码已生成：$PASSWORD"
}

setup_docker() {
  NODE_DIR="/root/snelldocker/Snell$PORT_NUMBER"
  
  mkdir -p "$NODE_DIR" || { echo "Error: Unable to create directory $NODE_DIR"; exit 1; }
  cd "$NODE_DIR" || { echo "Error: Unable to change directory to $NODE_DIR"; exit 1; }

  cat <<EOF > docker-compose.yml
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

  mkdir -p ./snell-conf || { echo "Error: Unable to create directory $NODE_DIR/snell-conf"; exit 1; }
  cat <<EOF > ./snell-conf/snell.conf
[snell-server]
listen = 0.0.0.0:$PORT_NUMBER
psk = $PASSWORD
tfo = true
obfs = off
ipv6 = false
EOF

  docker-compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }

  echo "节点设置完成，以下是你的节点信息"
}
print_node() {
  if [ "$choice" == "1" ]; then
    echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
    echo "    type: snell"
    echo "    server: $public_ip"
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
set_custom_path
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