#!/bin/bash

# 添加日志功能
log_file="/var/log/singbox_install.log"
exec > >(tee -a "$log_file") 2>&1
echo "安装日志将保存到 $log_file"

color='\033[1;34m'  # 蓝色
RES='\033[0m'       # 重置颜色
# 自动检测服务器IP地址 
default_ip=$(hostname -I | awk '{print $1}') # 获取第一个IP地址
# 检测并安装 uuidgen
if ! command -v uuidgen &> /dev/null; then
    echo "uuidgen 未安装，正在尝试安装..."
    if [[ -f /etc/debian_version ]]; then
        sudo apt update && sudo apt install -y uuid-runtime
    elif [[ -f /etc/redhat-release ]]; then
        sudo yum install -y util-linux
    else
        echo "无法检测系统类型，请手动安装 uuidgen。"
        exit 1
    fi
    echo "uuidgen 已成功安装。"
fi
echo -e "${color}请选择要执行的操作：${RES}"
options=("安装sing-box" "配置reality" "启用bbr" "卸载sing-box" "退出")
PS3="请输入您的选择[1-4]："

select opt in "${options[@]}"
do
    case $opt in
        "安装sing-box")
            echo "正在安装sing-box..."
            bash <(curl -fsSL https://sing-box.app/deb-install.sh)
            echo "安装sing-box成功！"
            echo "正在启用并启动sing-box服务..."
            systemctl enable --now sing-box
            systemctl status sing-box
            ;;
        "配置reality")
            # 自动生成 private_key 和 public_key
            keypair=$(sing-box generate reality-keypair)
            private_key=$(echo "$keypair" | awk '/PrivateKey:/ {print $2}')
            public_key=$(echo "$keypair" | awk '/PublicKey:/ {print $2}')

            # 自动生成 UUID
            uuid=$(uuidgen)

            # 自动生成 short_id (8到16位的16进制字符串)
            short_id=$(openssl rand -hex 8)

            # 提示用户输入其他配置信息
            read -p "请输入服务器IP地址 [默认: $default_ip]: " server_ip
            server_ip=${server_ip:-$default_ip} # 如果用户未输入内容，使用默认值
            # 生成随机高位端口 (1024-65535)
            random_port=$((RANDOM % 64511 + 10240))
            read -p "请输入监听端口 [默认: $random_port]: " listen_port
            listen_port=${listen_port:-$random_port}
            read -p "请输入伪装服务器域名: " server_name

            # 创建配置文件
            cat <<EOF > /etc/sing-box/config.json
            {
            "log": {
                "disabled": false,
                "level": "info",
                "timestamp": true
            },
            "inbounds": [
                {
                "sniff": true,
                "sniff_override_destination": true,
                "type": "vless",
                "tag": "vless-in",
                "listen": "::",
                "listen_port": $listen_port,
                "users": [
                    {
                    "uuid": "$uuid",
                    "flow": "xtls-rprx-vision"
                    }
                ],
                "tls": {
                    "enabled": true,
                    "server_name": "$server_name",
                    "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "$server_name",
                        "server_port": 443
                    },
                    "private_key": "$private_key",
                    "short_id": ["$short_id"]
                        }
                    }
                }
            ],
                "outbounds": [
                    {
                        "type": "direct",
                        "tag": "direct"
                    },
                    {
                        "type": "block",
                        "tag": "block"
                    }
                ]
            }
EOF

            echo "配置文件已生成并保存到 /etc/sing-box/config.json"
            # 打印客户端配置
            echo "mihomo客户端配置如下："
            cat <<EOF
- name: reality
  type: vless
  server: $server_ip
  port: $listen_port
  uuid: $uuid
  network: tcp
  tls: true
  udp: true
  flow: xtls-rprx-vision
  servername: $server_name
  reality-opts:
    public-key: $public_key
    short-id: $short_id
  client-fingerprint: chrome
EOF

            # 生成vless:// URL
            vless_url="vless://$uuid@$server_ip:$listen_port?encryption=none&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&spx=%2F&type=tcp&headerType=none&flow=xtls-rprx-vision"
            echo -e "\nVLESS URL 配置如下："
            echo "$vless_url"
            ;;
        "启用bbr")
            # 获取当前内核版本
            kernel_version=$(uname -r)
            # 提取主版本号和次版本号
            major_version=$(echo $kernel_version | cut -d. -f1)
            minor_version=$(echo $kernel_version | cut -d. -f2)

            # 比较版本号
            if [ $major_version -gt 4 ] || { [ $major_version -eq 4 ] && [ $minor_version -ge 9 ]; }; then
                echo "当前内核版本为 $kernel_version，支持BBR。正在启用BBR..."
                # 启用BBR
                echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                sysctl -p
            else
                echo "当前内核版本为 $kernel_version。内核版本低于4.9，不支持BBR。"
            fi
            ;;
        "卸载sing-box")
            echo "正在卸载sing-box..."
            systemctl stop sing-box
            systemctl disable sing-box
            rm -rf /etc/sing-box
            rm -f /usr/local/bin/sing-box
            echo "sing-box已卸载"
            ;;
        "退出")
            break
            ;;
        *) echo "无效选项 $REPLY";;
    esac
done
