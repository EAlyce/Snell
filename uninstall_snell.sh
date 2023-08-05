#!/bin/bash

echo "选择要卸载的 Snell 容器："

# 获取 Snell 容器
snell_containers=$(docker ps -a --format "{{.Names}}" --filter name=Snell)
declare -A container_map

index=1
for container in $snell_containers; do
  echo "$index. $container"
    container_map[$index]=$container
      ((index++))
      done

      echo "$index. 删除所有容器"
      echo "$((index + 1)). 退出脚本"

      read -p "输入选择： " choice

      if [ "$choice" -eq "$((index + 1))" ]; then
        echo "退出脚本."
          exit 0
          elif [ "$choice" -eq "$index" ]; then
            echo "正在卸载所有 Snell 容器..."
              for container in $snell_containers; do
                  docker stop $container
                      docker rm $container
                          rm -rf "/root/snelldocker/$container"
                            done
                              echo "已卸载所有 Snell 容器."
                              else
                                # 获取容器名并卸载
                                  container_name=${container_map[$choice]}
                                    if [ ! -z "$container_name" ]; then
                                        echo "正在卸载容器 $container_name..."
                                            docker stop $container_name
                                                docker rm $container_name
                                                    rm -rf "/root/snelldocker/$container_name"
                                                        echo "已卸载容器 $container_name."
                                                          else
                                                              echo "选择无效."
                                                                fi
                                                                fi
                                                                
