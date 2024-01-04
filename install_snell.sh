#!/bin/bash


install_tools() {

    echo "Start updating the system..." && sudo apt-get update -y > /dev/null || true && \
echo "Start installing software..." && sudo apt-get install -y curl wget mosh ncat netcat-traditional nmap apt-utils apt-transport-https ca-certificates iptables netfilter-persistent software-properties-common > /dev/null || true && \
echo "operation completed"
}

clean_lock_files() {

   echo "Start cleaning the system..." && \
sudo pkill -9 apt > /dev/null || true && \
sudo pkill -9 dpkg > /dev/null || true && \
sudo rm -f /var/{lib/dpkg/{lock,lock-frontend},lib/apt/lists/lock} > /dev/null || true && \
sudo dpkg --configure -a > /dev/null || true && \
sudo apt-get clean > /dev/null && \
sudo apt-get autoclean > /dev/null && \
sudo apt-get autoremove -y > /dev/null && \
sudo rm -rf /tmp/* > /dev/null && \
history -c > /dev/null && \
history -w > /dev/null && \
docker system prune -a --volumes -f > /dev/null && \
dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/^ii/{print $2}' | grep -v `uname -r` | xargs apt-get -y purge > /dev/null && \
echo "Cleaning completed"
}
install_docker_and_compose() {
# 检测 Docker 版本是否小于 24 且 Docker Compose 版本是否小于 2.23
if [[ "$(docker --version | awk '{print $3}' | sed 's/,//')" < "24" && "$(docker-compose version --short | awk -F '.' '{print $1$2}' | sed 's/v//')" < "223" ]]; then
    # 添加 Docker GPG 密钥
    if ! sudo gpg --list-keys | grep -q "docker"; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg -y
        sudo chmod a+r /etc/apt/keyrings/docker.gpg -y
    fi

    # 添加 Docker 源
    if ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
    fi

    # 安装 Docker 和 Docker Compose
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 运行示例容器
    sudo docker run hello-world
fi

# 验证安装
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo "Docker and Docker Compose installation verified."
else
    echo "Error: Docker or Docker Compose installation failed."
fi
}

get_public_ip() {
    ip_services=("ifconfig.me" "ipinfo.io/ip" "icanhazip.com" "ipecho.net/plain" "ident.me")
    public_ip=""
    for service in "${ip_services[@]}"; do
        if public_ip=$(curl -s "$service" 2>/dev/null); then
            if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "Local IP: $public_ip"
                break
            else
                echo "$service 返回的不是一个有效的IP地址：$public_ip"
            fi
        else
            echo "$service Unable to connect or slow response"
        fi
        sleep 1
    done
    [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "All services are unable to obtain public IP addresses"; exit 1; }
}

get_location() {
    location_services=("http://ip-api.com/line?fields=city" "ipinfo.io/city" "https://ip-api.io/json | jq -r .city")
    for service in "${location_services[@]}"; do
        LOCATION=$(curl -s "$service" 2>/dev/null)
        if [ -n "$LOCATION" ]; then
            echo "Host location：$LOCATION"
            break
        else
            echo "Unable to obtain city name from $service."
            continue
        fi
    done
    [ -n "$LOCATION" ] || echo "Unable to obtain city name."
}

setup_environment() {
#echo -e "nnameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
echo "DNS servers updated successfully."

export DEBIAN_FRONTEND=noninteractive
apt-get update > /dev/null || true
echo "Necessary packages installed."

iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT > /dev/null || true
echo "UDP port range opened."
sudo mkdir -p /etc/iptables
sudo touch /etc/iptables/rules.v4 > /dev/null || true
iptables-save > /etc/iptables/rules.v4
service netfilter-persistent reload > /dev/null || true
echo "Iptables saved."

apt-get upgrade -y > /dev/null || true
echo "Packages updated."

echo "export HISTSIZE=10000" >> ~/.bashrc
source ~/.bashrc

if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
  echo 3 > /proc/sys/net/ipv4/tcp_fastopen > /dev/null || true
  echo "TCP fast open enabled."
fi

docker system prune -af --volumes > /dev/null || true
echo "Docker system pruned."

iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT > /dev/null || true
echo "SYN packets accepted."

curl -fsSL https://raw.githubusercontent.com/EAlyce/ToolboxScripts/master/Linux.sh | bash > /dev/null && echo "Network optimization completed"

}

select_version() {
  echo "Please select the version of Snell："
  echo "1. v3 "
  echo "2. v4 Exclusive to Surge"
  echo "0. 退出脚本"
  read -p "输入选择（回车默认2）: " choice

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
  echo "Firewall rule added, allowing port $PORT_NUMBER's traffic"
}

generate_password() {
  PASSWORD=$(openssl rand -base64 12) || { echo "Error: Unable to generate password"; exit 1; }
  echo "Password generated：$PASSWORD"
}
setup_docker() {

  cat <<EOF > docker-compose.yml
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

  docker compose up -d || { echo "Error: Unable to start Docker container"; exit 1; }
#docker restart $(docker ps -q)
  echo "Node setup completed. Here is your node information"
}
print_node() {
  if [ "$choice" == "1" ]; then
    echo
    echo
    echo "  - name: $LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER"
    echo "    type: snell"
    echo "    server: $public_ip"
    echo "    port: $PORT_NUMBER"
    echo "    psk: $PASSWORD"
    echo "    version: $VERSION_NUMBER"
    echo "    udp: true"
    echo
    echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
    echo
    echo
  elif [ "$choice" == "2" ]; then
    echo
    echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $public_ip, $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER"
    echo
  fi
}
create_and_activate_venv() {
    venv_dir="/root/SnellDockervenv"
venv_name="venv"

# 检查目录是否存在，如果不存在则创建
if [ ! -d "$venv_dir" ]; then
    mkdir -p "$venv_dir"
fi

# 创建虚拟环境
python3 -m venv "$venv_dir/$venv_name"

# 激活虚拟环境
source "$venv_dir/$venv_name/bin/activate"
}
main(){
create_and_activate_venv
select_version
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
# 退出虚拟环境
deactivate
}

main