#!/bin/bash

set -e

# Check root
if [ $(id -u) != 0 ] ; then
	echo -e "\033[31m Please use 'sudo' to run this tool! \033[0m\n"
	exit 1
fi

# Check ubuntu linux
if [ -z $(cat /etc/os-release | grep 'NAME="Ubuntu"') ]; then
	echo -e "\033[31m You must run it on Ubuntu Linux! \033[0m\n"
	exit 1
fi

# Chenk v2ray install
if [[ -f /usr/local/bin/v2ray ]] || [[ -f /usr/bin/v2ray ]]; then
	echo -e "\033[31m The v2ray software is already installed ! \033[0m\n"
	exit 1
fi

Install_Dir="/etc/v2ray"
Config_File="${Install_Dir}/config.json"
Service_File="/etc/systemd/system/v2ray.service"

# Check system time
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true

Download_V2ray(){
	apt-get update
	apt-get install jq unzip -y
	Last_Version=`curl -s 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest' | jq '.tag_name' | awk -F '"' '{print $2}'`
	wget https://github.com/v2ray/v2ray-core/releases/download/${Last_Version}/v2ray-linux-64.zip
	unzip v2ray-linux-64.zip -d $Install_Dir
	rm -rf v2ray-linux-64.zip
}

Init_V2ray(){
	ln -s ${Install_Dir}/v2ctl /usr/local/bin/v2ctl
	ln -s ${Install_Dir}/v2ray /usr/local/bin/v2ray
}

Config_V2ray(){
	UUID=`v2ctl uuid`
	PASSWD=`date +%s | sha256sum | base64 | head -c 16`
	if [[ ! -f $Config_File ]]; then
		touch $Config_File
	fi

cat > "$Config_File" <<-EOF
{
  "log": {
    "access": "/var/log/v2ray-access.log",
    "error": "/var/log/v2ray-error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 30303,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 1,
            "alterId": 233
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls" ]
      }
    },
    {
      "protocol": "shadowsocks",
      "port": 30304,
      "settings": {
        "method": "chacha20-ietf-poly1305",
        "password": "$PASSWD",
        "network": "tcp,udp",
        "level": 1,
        "ota": false
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    },
    {
      "protocol": "mtproto",
      "settings": {},
      "tag": "tg-out"
    }
  ],
  "dns": {
    "servers": [
      "https+local://cloudflare-dns.com/dns-query",
      "1.1.1.1",
      "1.0.0.1",
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "127.0.0.0/8",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "inboundTag": [
          "tg-in"
        ],
        "outboundTag": "tg-out"
      },
      {
        "type": "field",
        "domain": [
          "domain:epochtimes.com",
          "domain:epochtimes.com.tw",
          "domain:epochtimes.fr",
          "domain:epochtimes.de",
          "domain:epochtimes.jp",
          "domain:epochtimes.ru",
          "domain:epochtimes.co.il",
          "domain:epochtimes.co.kr",
          "domain:epochtimes-romania.com",
          "domain:erabaru.net",
          "domain:lagranepoca.com",
          "domain:theepochtimes.com",
          "domain:ntdtv.com",
          "domain:ntd.tv",
          "domain:ntdtv-dc.com",
          "domain:ntdtv.com.tw",
          "domain:minghui.org",
          "domain:renminbao.com",
          "domain:dafahao.com",
          "domain:dongtaiwang.com",
          "domain:falundafa.org",
          "domain:wujieliulan.com",
          "domain:ninecommentaries.com",
          "domain:shenyun.com"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "transport": {
    "kcpSettings": {
      "uplinkCapacity": 100,
      "downlinkCapacity": 100,
      "congestion": true
    }
  }
}
EOF
}

Config_Service(){
	if [[ ! -f $Service_File ]]; then
		touch $Service_File
	fi

cat > "$Service_File" <<-EOF
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray -config /etc/v2ray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

}

#
Download_V2ray
Init_V2ray
Config_V2ray
Config_Service
echo
echo "v2ray is installed successfully !"
nohup v2ray &
echo
exit