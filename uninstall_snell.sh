#!/bin/bash

# 获取 Snell 容器列表
CONTAINERS=$(docker ps -a --filter "name=Snell" --format "{{.ID}} {{.Names}}" | nl -w 1 -s '. ')

if [ -z "$CONTAINERS" ]; then
  echo "没有找到 Snell 容器."
    exit 0
    fi

    echo "找到以下 Snell 容器："
    echo "$CONTAINERS"

    # 选择一个容器来卸载
    read -p "请输入你想要卸载的容器编号: " CHOICE

    # 获取所选容器的 ID
    CONTAINER_ID=$(docker ps -a --filter "name=Snell" --format "{{.ID}}" | sed "${CHOICE}q;d")

    # 停止容器
    echo "正在停止容器 $CONTAINER_ID ..."
    docker stop $CONTAINER_ID

    # 删除容器
    echo "正在删除容器 $CONTAINER_ID ..."
    docker rm $CONTAINER_ID

    echo "卸载完成！"
    
