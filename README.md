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

三、其他
查看运行状态
```
systemctl status snell
```

做了点小改动，适配Oracle arm机子
代码参考自：整点猫咪、@SebErstellen
