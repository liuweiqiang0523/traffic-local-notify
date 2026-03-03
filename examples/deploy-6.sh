#!/usr/bin/env bash
set -euo pipefail

# 用法：把下面变量改好后，在每台服务器执行对应一行。
CHAT_ID="-100xxxx"
BOT_TOKEN="123:abc"
LIMIT_GB_DEFAULT="25600"

# 1) 主控机（只执行一次）
# ROLE=master SERVER_NAME="master-hub" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)

# 2) worker（每台执行一次，改 SERVER_NAME）
# ROLE=worker SERVER_NAME="lax-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
# ROLE=worker SERVER_NAME="hkg-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
# ROLE=worker SERVER_NAME="jpn-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
# ROLE=worker SERVER_NAME="sgp-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
# ROLE=worker SERVER_NAME="de-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)
# ROLE=worker SERVER_NAME="us-01" LIMIT_GB="$LIMIT_GB_DEFAULT" CHAT_ID="$CHAT_ID" BOT_TOKEN="$BOT_TOKEN" \
# bash <(curl -fsSL https://raw.githubusercontent.com/liuweiqiang0523/traffic-local-notify/main/setup-cluster.sh)

# 3) 主控机补充节点映射
# cp examples/nodes.6.example.json /opt/traffic-local/nodes.json
# nano /opt/traffic-local/nodes.json
# systemctl restart traffic-local-bot.service

# 4) 验证（在 Telegram）
# /nodes
# /traffic lax-01
# /selfcheck lax-01
