#!/bin/bash

if cat /etc/*-release | grep -q -E -i "debian|ubuntu|armbian|deepin|mint"; then 	# 安装依赖
	apt-get install wget unzip dpkg -y
elif cat /etc/*-release | grep -q -E -i "centos|red hat|redhat"; then
	yum install wget unzip dpkg -y
elif cat /etc/*-release | grep -q -E -i "arch|manjora"; then
	yes | pacman -S wget dpkg unzip
elif cat /etc/*-release | grep -q -E -i "fedora"; then
	dnf install wget unzip dpkg -y
fi

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf	# 启用 BBR
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_available_congestion_control

cd
ARCHITECTURE=$(dpkg --print-architecture)
if [ "$ARCHITECTURE" = "arm64" ]; then
	ARCHITECTURE="aarch64"
fi
wget -c https://dl.nssurge.com/snell/snell-server-v4.0.1-linux-$ARCHITECTURE.zip	# 下载二进制文件
unzip -o snell-server-v4.0.1-linux-$ARCHITECTURE.zip

# 创建 systemd 服务文件
echo -e "[Unit]\nDescription=snell server\n[Service]\nUser=snell\nWorkingDirectory=/root\nExecStartPre=/bin/mkdir -p /run/snell\nExecStart=/root/snell-server\nExecStopPost=/bin/rm -rf /run/snell\nRestart=always\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/snell.service

systemctl daemon-reload  # 重新加载 systemd 配置文件
systemctl start snell    # 启动 snell 服务
systemctl enable snell   # 设置 snell 服务开机自启

echo
echo "将以下配置行复制到 surge 配置文件"  # 输出配置信息
echo "$(curl -s ipinfo.io/city) = snell, $(curl -s ipinfo.io/ip), $(cat snell-server.conf | grep -i listen | cut --delimiter=':' -f2),psk=$(grep 'psk' snell-server.conf | cut -d= -f2 | tr -d ' '), version=4, tfo=true"
