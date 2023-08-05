#!/bin/bash

# 获取所有名为Snell的容器
snell_containers=$(docker ps -a --format "{{.ID}}: {{.Names}}" --filter name=Snell)

# 将容器放入数组中
containers=($snell_containers)

echo "选择要卸载的Snell容器："
i=1
for container in "${containers[@]}"; do
  echo "$i. $(echo $container | cut -d ':' -f2)"
  i=$((i+1))
done
echo "$i. 删除所有容器"
echo "$((i+1)). 退出脚本"

read -p "输入选择（输入数字）： " choice

if [[ $choice -eq $i ]]; then
  # 删除所有Snell容器
  docker rm -f $(docker ps -a -q --filter name=Snell)
  echo "所有Snell容器已删除。"
elif [[ $choice -eq $((i+1)) ]]; then
  # 退出脚本
  echo "退出脚本。"
else
  # 删除选定的Snell容器
  selected_container=$(echo ${containers[$((choice-1))]} | cut -d ':' -f1)
  docker rm -f $selected_container
  echo "容器 $selected_container 已删除。"
fi
