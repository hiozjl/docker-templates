#!/bin/bash

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
options=("安装sing-box" "配置reality-brutal" "配置reality" "安装tcp-brutal" "启用bbr" "退出")
PS3="请输入您的选择[1-5]："

select opt in "${options[@]}"
do
    case $opt in
        "安装sing-box")
            echo "正在安装sing-box..."
            bash <(curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.11.15)
            echo "安装sing-box成功！"
            ;;
        "配置reality-brutal")
            # 自动生成 private_key 和 public_key
            keypair=$(sing-box generate reality-keypair)
            private_key=$(echo "$keypair" | awk '/PrivateKey:/ {print $2}')
            public_key=$(echo "$keypair" | awk '/PublicKey:/ {print $2}')

            # 自动生成 UUID
            uuid=$(uuidgen)

            # 自动生成 short_id (8到16位的16进制字符串)
            short_id=$(openssl rand -hex $((RANDOM % 9 + 8)))

            # 提示用户输入其他配置信息
            read -p "请输入服务器IP地址 [默认: $default_ip]: " server_ip
            server_ip=${server_ip:-$default_ip} # 如果用户未输入内容，使用默认值
            read -p "请输入监听端口: " listen_port
            read -p "请输入伪装服务器域名: " server_name
            read -p "请输入上行Mbps: " up_mbps
            read -p "请输入下行Mbps: " down_mbps
            echo

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
                "tag": "vless-brutal-in",
                "listen": "::",
                "listen_port": $listen_port,
                "users": [
                    {
                    "uuid": "$uuid",
                    "flow": ""
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
                },
                    "multiplex": {
                        "enabled": true,
                        "padding": true,
                        "brutal": {
                            "enabled": true,
                            "up_mbps": $up_mbps,
                            "down_mbps": $down_mbps
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
- name: "Reality-Brutal"
  type: vless
  server: $server_ip
  port: $listen_port
  uuid: $uuid
  network: tcp
  udp: true
  tls: true
  flow:
  servername: $server_name
  client-fingerprint: chrome
  reality-opts:
    public-key: $public_key
    short-id: $short_id
  smux:
    enabled: true
    protocol: h2mux
    max-connections: 1
    min-streams: 4
    padding: true
    brutal-opts:
      enabled: true
      up: $up_mbps
      down: $down_mbps
EOF
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
            read -p "请输入监听端口: " listen_port
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
            ;;
        "安装tcp-brutal")
            kernel_version=$(uname -r | cut -d'-' -f1)
            required_version="5.8"
            if [ "$(printf '%s\n' "$required_version" "$kernel_version" | sort -V | head -n1)" = "$required_version" ]; then
                echo "内核版本满足要求，正在安装tcp-brutal..."
                bash <(curl -fsSL https://tcp.hy2.sh/)
            else
                echo "内核版本不满足要求，需要5.8以上版本。当前版本: $kernel_version"
            fi
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
        "退出")
            break
            ;;
        *) echo "无效选项 $REPLY";;
    esac
done
