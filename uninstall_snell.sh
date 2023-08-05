#!/bin/bash

while true; do
  # 列出所有 Snell 容器
    containers=$(docker ps --filter "name=Snell" --format "{{.ID}}: {{.Names}}")
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

                                              # 获取容器ID并卸载
                                                container_id=${container_map[$choice]}
                                                  container_id=${container_id%%:*}
                                                    if [ ! -z "$container_id" ]; then
                                                        echo "正在卸载容器 $container_id..."
                                                            docker stop $container_id
                                                                docker rm $container_id
                                                                    echo "已卸载容器 $container_id."
                                                                      else
                                                                          echo "选择无效."
                                                                            fi
                                                                            done
                                                                            
