#!/bin/sh

# LTE LAN 转发控制脚本
# 逻辑：根据 UCI 配置决定是否拦截 LAN 到 LTE 物理网卡的转发流量

# 1. 获取配置
ALLOW=$(uci get network.lte.allow_lan_forward 2>/dev/null)
# 如果配置不存在，默认设为 1 (开启转发)
[ -z "$ALLOW" ] && ALLOW="1"

# 物理设备（默认为 eth1，如果 UCI 中有定义则使用定义值）
DEV=$(uci get network.lte.device 2>/dev/null)
[ -z "$DEV" ] && DEV="eth1"

# 2. 应用规则
if [ "$ALLOW" = "0" ]; then
    # 模式：禁止转发 (单机模式)
    # 检查规则是否已存在，避免重复插入
    iptables -C FORWARD -o "$DEV" -j DROP 2>/dev/null
    if [ $? -ne 0 ]; then
        iptables -I FORWARD -o "$DEV" -j DROP
        logger -t "lte_forward" "Status changed to BLOCKED for device $DEV"
    fi
else
    # 模式：允许转发 (路由器模式)
    # 循环删除所有匹配的拦截规则，确保干净
    while iptables -D FORWARD -o "$DEV" -j DROP 2>/dev/null; do
        logger -t "lte_forward" "Status changed to ALLOWED for device $DEV"
    done
fi
