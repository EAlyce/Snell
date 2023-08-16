#!/bin/bash
# 作者 Chat GPT & Alice
# 项目地址：https://github.com/ExaAlice/Snell
# Backup old resolv.conf
# 设置PATH变量，包括了常见的系统二进制文件路径
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# 使用export命令将PATH变量导出，这样在当前shell及其子shell中都可以访问这个变量
export PATH

echo "请选择一个操作："
echo "1: 不执行更新，直接部署Snell"
echo "2: 更新然后部署"
read -p "输入选择 (1/2): " choice

if [ "$choice" == "2" ]; then

# 定义路径变量
resolv_conf="/etc/resolv.conf"

# 备份原文件
cp "${resolv_conf}" "${resolv_conf}.backup"

# 设置DNS服务器
echo "nameserver 1.1.1.1" > "${resolv_conf}"
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

#更新所有包
apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y && apt full-upgrade -y

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
# 启用TFO客户端功能
echo 3 > /proc/sys/net/ipv4/tcp_fastopen

# 如果您使用的是iptables，允许TFO数据包
iptables -A INPUT -p tcp --tcp-flags SYN SYN -j ACCEPT

# 验证当前用户是否为root。
[ "$(id -u)" != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

[ -e /etc/security/limits.d/*nproc.conf ] && rename nproc.conf nproc.conf_bk /etc/security/limits.d/*nproc.conf
[ -f /etc/pam.d/common-session ] && [ -z "$(grep 'session required pam_limits.so' /etc/pam.d/common-session)" ] && echo "session required pam_limits.so" >> /etc/pam.d/common-session
sed -i '/^# End of file/,$d' /etc/security/limits.conf
cat >> /etc/security/limits.conf <<EOF
# End of file
*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited

root     soft   nofile    1048576
root     hard   nofile    1048576
root     soft   nproc     1048576
root     hard   nproc     1048576
root     soft   core      1048576
root     hard   core      1048576
root     hard   memlock   unlimited
root     soft   memlock   unlimited
EOF

sed -i '/fs.file-max/d' /etc/sysctl.conf
sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf
sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_mem/d' /etc/sysctl.conf
sed -i '/net.ipv4.udp_mem/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_keepalive_time/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_notsent_lowat/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.route_localnet/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.forwarding/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.default.forwarding/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
fs.file-max = 1048576
fs.inotify.max_user_instances = 8192
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.tcp_mem = 786432 1048576 26777216
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 131072
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.conf.all.route_localnet = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
EOF

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
elif [ "$choice" != "1" ]; then
    echo "无效的选择!"
    exit 1
fi

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
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
elif [ "$choice" == "2" ]; then
  LOCATION=$(curl -s ipinfo.io/city)
  echo "$LOCATION Snell v$VERSION_NUMBER $PORT_NUMBER = snell, $(curl -s ifconfig.me), $PORT_NUMBER, psk=$PASSWORD, version=$VERSION_NUMBER, tfo=true"
fi
