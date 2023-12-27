#!/bin/bash
install_docker_and_compose() {
    # 安装Docker
    command -v docker &> /dev/null || {
        echo "Installing Docker...";
        curl -fsSL https://get.docker.com | bash
    }
    command -v docker &> /dev/null && echo "Docker已安装"

    # 安装Docker Compose
    command -v docker-compose &> /dev/null || {
        echo "Installing Docker Compose...";
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose;
    }
    command -v docker-compose &> /dev/null && echo "Docker Compose已安装" || {
        echo "Docker Compose安装失败。";
        exit 1; 
    }
}
# Function to remove a container and its associated folder
function remove_container() {
  local selected_container=$1
  local container_name=$(docker ps --filter "id=$selected_container" --format "{{.Names}}")

  if [ -n "$selected_container" ]; then
    echo "正在停止容器 $selected_container ..."
    docker stop $selected_container

    echo "正在删除容器 $selected_container ..."
    docker rm $selected_container
    echo "容器 $selected_container 已删除。"

    local folder="/root/snelldocker/$container_name"
    if [ -d "$folder" ]; then
      echo "正在删除与容器名 $container_name 相同的文件夹 $folder ..."
      sudo rm -rf "$folder"
	  docker system prune -af --volumes > /dev/null
      echo "文件夹 $folder 已删除。"
    else
      echo "未找到与容器名 $container_name 相同的文件夹。"
    fi
  else
    echo "未知错误，无法找到容器。"
  fi
}

# Function to list all Docker containers
function list_containers() {
  while true; do
    CONTAINERS=$(docker ps -a --format "{{.ID}}:{{.Names}}")

    if [ -z "$CONTAINERS" ]; then
      echo "没有找到 Docker 容器."
      exit 0
    fi

    echo "选择要卸载的容器："
    declare -A container_map
    index=0

    for container in $CONTAINERS; do
      id=$(echo $container | cut -d ':' -f1)
      name=$(echo $container | cut -d ':' -f2)
      echo "$index. $name ($id)"
      container_map["$index"]=$id
      ((index++))
    done

    echo "$index. 退出脚本"
    container_map["$index"]="exit"

    read -p "输入选择（输入数字）： " choice

    if [[ "${container_map["$choice"]}" == "exit" ]]; then
      exit 0
    elif [[ "${container_map["$choice"]}" ]]; then
      remove_container "${container_map["$choice"]}"
    else
      echo "输入无效，请输入有效的数字."
    fi
  done
}
# 定义设置 PATH 的函数
set_custom_path() {
    # 检查是否存在 PATH 变量，如果不存在则设置
    PATH_CHECK=$(crontab -l | grep -q '^PATH=' && echo "true" || echo "false")

    if [ "$PATH_CHECK" == "false" ]; then
        # 设置全面的 PATH
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    fi
}

# 调用设置 PATH 函数
set_custom_path
# Start listing containers
install_docker_and_compose
docker system prune -af --volumes
list_containers
