#!/bin/bash

# 列出所有 Snell 容器
CONTAINERS=$(docker ps -a --filter "name=Snell" --format "{{.ID}}:{{.Names}}")

if [ -z "$CONTAINERS" ]; then
  echo "没有找到 Snell 容器."
  exit 0
fi

echo "选择要卸载的 Snell 容器："
i=1
declare -A container_map
for container in $CONTAINERS; do
  id=$(echo $container | cut -d ':' -f1)
  name=$(echo $container | cut -d ':' -f2)
  echo "$i. $name ($id)"
  container_map[$i]=$id
  i=$((i+1))
done
echo "$i. 删除所有容器"
echo "$((i+1)). 退出脚本"

read -p "输入选择（输入数字）： " choice

if [[ $choice -eq $i ]]; then
  # 删除所有 Snell 容器
  docker rm -f $(docker ps -a -q --filter name=Snell)
  echo "所有 Snell 容器已删除。"
elif [[ $choice -eq $((i+1)) ]]; then
  # 退出脚本
  echo "退出脚本。"
else
  # 删除选定的 Snell 容器
  selected_container=${container_map[$choice]}
  echo "正在停止容器 $selected_container ..."
  docker stop $selected_container
  echo "正在删除容器 $selected_container ..."
  docker rm $selected_container
  echo "容器 $selected_container 已删除。"
fi
