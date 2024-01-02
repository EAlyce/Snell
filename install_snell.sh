#!/bin/bash
set_custom_path() {
    # 安装 cron，如果未安装的话
    if ! command -v cron &> /dev/null; then
        sudo apt-get update
        sudo apt-get install cron
    fi

    # 启动 cron 服务，如果未启动的话
    if ! systemctl is-active --quiet cron; then
        sudo systemctl start cron
    fi

    # 设置开机自启动，如果未设置的话
    if ! systemctl is-enabled --quiet cron; then
        sudo systemctl enable cron
    fi

    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(grep -q '^PATH=' /etc/crontab && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        # 设置全面的 PATH
        echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' >> /etc/crontab

        # 重新加载 cron 服务
        systemctl reload cron
    fi
}


check_root() {
    [ "$(id -u)" != "0" ] && echo "Error: You must be root to run this script" && exit 1
}

install_tools() {
    # 隐藏安装工具函数的输出
    sudo apt-get update -y > /dev/null || true
    sudo apt-get install -y curl wget mosh ncat netcat-traditional nmap apt-utils apt-transport-https ca-certificates iptables netfilter-persistent software-properties-common > /dev/null || true
}

clean_lock_files() {
    # 隐藏清理锁文件和终止进程函数的输出
   sudo pkill -9 apt > /dev/null || true
sudo pkill -9 dpkg > /dev/null || true
sudo rm -f /var/{lib/dpkg/{lock,lock-frontend},lib/apt/lists/lock} > /dev/null || true
sudo dpkg --configure -a > /dev/null || true
apt clean > /dev/null && apt autoclean > /dev/null && apt autoremove -y > /dev/null && rm -rf /tmp/* > /dev/null && history -c > /dev/null && history -w > /dev/null && docker system prune -a --volumes -f > /dev/null && dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge > /dev/null && echo "清理完成"
}

# 错误代码
ERR_DOCKER_INSTALL=1
ERR_COMPOSE_INSTALL=2
install_docker_and_compose(){
sudo apt-get update > /dev/null 2>&1 && sudo apt-get install --only-upgrade docker-ce > /dev/null 2>&1 && sudo rm -rf /sys/fs/cgroup/systemd && sudo mkdir /sys/fs/cgroup/systemd && sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd && echo "修复完成"

echo -e "net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\nnet.ipv4.tcp_ecn=1" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1 && sudo sysctl -p > /dev/null 2>&1 && echo "设置已更新"

sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1 && sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null 2>&1 && echo "密钥已更新"

sudo apt install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null 2>&1 && curl -fsSL https://test.docker.com | sudo bash > /dev/null 2>&1 && sudo apt update > /dev/null 2>&1 && sudo apt install -y docker-compose > /dev/null 2>&1 && echo "安装完成"

# 如果系统版本是 Debian 12，则重新添加 Docker 存储库，使用新的 signed-by 选项来指定验证存储库的 GPG 公钥
if [ "$(lsb_release -cs)" = "bookworm" ]; then
    # 重新下载 Docker GPG 公钥并保存到 /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && echo "源已添加"
fi

# 更新 apt 存储库
sudo apt update > /dev/null 2>&1 && sudo apt upgrade -y > /dev/null 2>&1 && sudo apt autoremove -y > /dev/null 2>&1 && echo "系统更新已完成"

# 如果未安装，则使用包管理器安装 Docker
if ! command -v docker &> /dev/null; then
    sudo apt install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1
    sudo systemctl enable --now docker > /dev/null 2>&1
    echo "Docker 已安装并启动成功"
else
    echo "Docker 已经安装"
fi

# 安装 Docker Compose
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose
    echo "Docker Compose 已安装成功"
else
    echo "Docker Compose 已经安装"
fi
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
apt-get update > /dev/null || true
echo "Necessary packages installed."

# Open UDP port range and save iptables rules using netfilter-persistent
iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
echo "UDP port range opened."
sudo mkdir -p /etc/iptables
sudo touch /etc/iptables/rules.v4 > /dev/null || true
iptables-save > /etc/iptables/rules.v4
service netfilter-persistent reload > /dev/null || true
echo "Iptables saved."

# Update packages and dependencies (non-interactive mode)
apt-get upgrade -y > /dev/null || true
echo "Packages updated."

# Enable TCP fast open if supported
if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
  echo 3 > /proc/sys/net/ipv4/tcp_fastopen > /dev/null || true
  echo "TCP fast open enabled."
fi

# Docker system prune
docker system prune -af --volumes > /dev/null || true
echo "Docker system pruned."

# Additional configurations
iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT > /dev/null || true
echo "SYN packets accepted."

curl -fsSL https://raw.githubusercontent.com/EAlyce/ToolboxScripts/master/Linux.sh | bash > /dev/null && echo "网络优化完成"

}

select_version() {
  echo "请选择 Snell 的版本："
  echo "1. v3"
  echo "2. v4 Surge专属"
  echo "0. 退出脚本"
  read -p "输入选择（默认选择2）: " choice

  choice="${choice:-2}"

  case $choice in
    0) echo "退出脚本"; exit 0 ;;
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

  # 安装 netcat-traditional（如果尚未安装）
  if ! command -v nc.traditional &> /dev/null; then
    sudo apt-get update
    sudo apt-get install netcat-traditional
  fi

  while true; do
    PORT_NUMBER=$(shuf -i 5000-9999 -n 1)

    if ! nc.traditional -z 127.0.0.1 "$PORT_NUMBER" && [[ ! " ${EXCLUDED_PORTS[@]} " =~ " ${PORT_NUMBER} " ]]; then
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
version: "3.3"
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
tfo = false
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
sudo apt-get autoremove -y > /dev/null
apt-get install sudo > /dev/null
select_version
set_custom_path
clean_lock_files
install_tools
install_docker_and_compose
get_public_ip
get_location
setup_environment
select_architecture
generate_port
setup_firewall
generate_password
setup_docker
print_node
}

main