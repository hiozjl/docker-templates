#!/bin/bash

color='\033[1;34m'  # 蓝色
RES='\033[0m'       # 重置颜色

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "请以root权限运行此脚本" 
   exit 1
fi

# 自动检测服务器IP地址 
default_ip=$(hostname -I | awk '{print $1}')

# 检测并安装 uuidgen
if ! command -v uuidgen &> /dev/null; then
    echo "uuidgen 未安装，正在尝试安装..."
    if [[ -f /etc/debian_version ]]; then
        apt update && apt install -y uuid-runtime
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y util-linux
    else
        echo "无法检测系统类型，请手动安装 uuidgen。"
        exit 1
    fi
    echo "uuidgen 已成功安装。"
fi

# 检查并安装 qrencode
if ! command -v qrencode &> /dev/null; then
    echo "检测到未安装 qrencode（用于生成二维码），是否安装？[y/N]"
    read -r install_qr
    if [[ $install_qr =~ ^[Yy]$ ]]; then
        if [[ -f /etc/debian_version ]]; then
            apt install -y qrencode
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y qrencode
        else
            echo "无法自动安装 qrencode，请手动安装"
        fi
    fi
fi

echo -e "${color}请选择要执行的操作：${RES}"
options=("安装sing-box" "配置reality" "启用bbr" "退出")
PS3="请输入您的选择[1-4]："

select opt in "${options[@]}"
do
    case $opt in
        "安装sing-box")
            echo "正在安装sing-box..."
            if curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.11.15; then
                echo "安装sing-box成功！"
                # 创建配置目录
                mkdir -p /etc/sing-box/
                # 启用并启动服务
                systemctl enable sing-box
                systemctl start sing-box
            else
                echo "sing-box安装失败！"
            fi
            ;;
        "配置reality")
            # 检查sing-box是否安装
            if ! command -v sing-box &> /dev/null; then
                echo "请先安装sing-box！"
                continue
            fi
            
            # 自动生成 private_key 和 public_key
            keypair=$(sing-box generate reality-keypair)
            private_key=$(echo "$keypair" | awk '/PrivateKey:/ {print $2}')
            public_key=$(echo "$keypair" | awk '/PublicKey:/ {print $2}')

            # 自动生成 UUID
            uuid=$(uuidgen)

            # 自动生成 short_id
            short_id=$(openssl rand -hex 8)

            # 输入验证
            read -p "请输入服务器IP地址 [默认: $default_ip]: " server_ip
            server_ip=${server_ip:-$default_ip}
            
            read -p "请输入监听端口 [默认: 443]: " listen_port
            listen_port=${listen_port:-443}
            
            # 端口号验证
            if ! [[ "$listen_port" =~ ^[0-9]+$ ]] || [ "$listen_port" -lt 1 ] || [ "$listen_port" -gt 65535 ]; then
                echo "错误：端口号必须在1-65535之间"
                continue
            fi
            
            read -p "请输入伪装服务器域名 [默认: yahoo.com]: " server_name
            server_name=${server_name:-yahoo.com}

            # 创建配置目录
            mkdir -p /etc/sing-box/

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
            
            # 重启服务应用配置
            systemctl restart sing-box
            if systemctl is-active --quiet sing-box; then
                echo "sing-box服务重启成功"
            else
                echo "警告：sing-box服务重启失败，请检查配置"
            fi
            
            # 打印客户端配置
            echo -e "\n${color}mihomo客户端配置如下：${RES}"
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

            # 打印VLESS URL
            echo -e "\n${color}VLESS URL 链接：${RES}"
            vless_url="vless://${uuid}@${server_ip}:${listen_port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${server_name}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp#reality"
            echo "$vless_url"
            
            # 检查是否支持生成二维码
            if command -v qrencode &> /dev/null; then
                echo -e "\n${color}二维码：${RES}"
                qrencode -t ANSIUTF8 "$vless_url"
            else
                echo -e "\n${color}提示：安装 qrencode 可以显示二维码（可选）${RES}"
                echo "Ubuntu/Debian: sudo apt install qrencode"
                echo "CentOS/RHEL: sudo yum install qrencode"
            fi
            
            echo -e "\n${color}提示：复制上面的VLESS链接可直接导入支持URL导入的客户端${RES}"
            ;;
        "启用bbr")
            # 检查是否已启用BBR
            if sysctl -n net.ipv4.tcp_congestion_control | grep -q bbr; then
                echo "BBR已经启用"
                continue
            fi
            
            kernel_version=$(uname -r)
            major_version=$(echo $kernel_version | cut -d. -f1)
            minor_version=$(echo $kernel_version | cut -d. -f2)

            if [ $major_version -gt 4 ] || { [ $major_version -eq 4 ] && [ $minor_version -ge 9 ]; }; then
                echo "当前内核版本为 $kernel_version，支持BBR。正在启用BBR..."
                echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                sysctl -p
                echo "BBR已启用"
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
