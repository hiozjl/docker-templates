#!/bin/bash

echo "请选择要执行的操作："
options=("安装sing-box" "配置reality-brutal" "配置reality" "安装tcp-brutal" "退出")
PS3="请输入您的选择[1-5]："

select opt in "${options[@]}"
do
    case $opt in
        "安装sing-box")
            echo "正在安装sing-box..."
            bash <(curl -fsSL https://sing-box.app/deb-install.sh)
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
            read -p "请输入服务器IP地址: " server_ip
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
                "listen_port": "$listen_port",
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
            read -p "请输入服务器IP地址: " server_ip
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
                "listen_port": "$listen_port",
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
        "退出")
            break
            ;;
        *) echo "无效选项 $REPLY";;
    esac
done