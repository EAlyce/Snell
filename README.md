# Snell
Snell一键安装脚本

一、安装
```
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/ExaAlice/Snell/master/snell.sh)"
```
安装完成后依次运行

```
systemctl daemon-reload
```
```
systemctl restart snell.service
```


二、卸载
```
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/ExaAlice/Snell/master/rmsnell.sh)"
```

三、其他指令

1、查看运行状态
```
systemctl status snell
```
2、保持自启动
```
sudo systemctl enable snell.service
```
3、启动
```
sudo systemctl start snell.service
```
4、输出节点信息
```
echo "$(curl -s ipinfo.io/city) = snell, $(curl -s ipinfo.io/ip), $(cat snell-server.conf | grep -i listen | cut --delimiter=':' -f2),psk=$(grep 'psk' snell-server.conf | cut -d= -f2 | tr -d ' '), version=4, tfo=true"
```

做了点小改动，适配Oracle arm

代码参考自：[整点猫咪](https://github.com/getsomecat)、@[SebErstellen](https://github.com/SebErstellen/snell)
