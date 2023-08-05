#!/bin/bash

while true; do
  # 列出所有 Snell 容器名
    containers=$(docker ps --filter "name=Snell" --format "{{.Names}}")
      echo "选择要卸载的 Snell 容器："

        i=1
          declare -A container_map
            for container in $containers; do
                echo "$i. $container"
                    container_map[$i]=$container
                        ((i++))
                          done

                            echo "$i. 退出脚本"

                              # 提示用户选择
                                read -p "输入选择（1/$i）: " choice

                                  if [ "$choice" -eq "$i" ]; then
                                      echo "退出脚本."
                                          exit 0
                                            fi

                                              # 获取容器名并卸载
                                                container_name=${container_map[$choice]}
                                                  if [ ! -z "$container_name" ]; then
                                                      echo "正在卸载容器 $container_name..."
                                                          docker stop $container_name
                                                              docker rm $container_name
                                                                  echo "已卸载容器 $container_name."
                                                                    else
                                                                        echo "选择无效."
                                                                          fi
                                                                          done
                                                                          
