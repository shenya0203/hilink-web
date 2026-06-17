#!/bin/sh

# LTE LAN 转发控制脚本
# 使用自定义链 LTE_FORWARD 控制 LAN 到 LTE 网卡的转发
# 通过读取 UCI 配置和当前活动 SIM 卡槽，决定是否阻断转发

LTE_DEV="eth1"
CHAIN="LTE_FORWARD"

# ============================================================
# 1. 初始化自定义链（幂等）
# ============================================================

# 创建自定义链（如果已存在则静默失败）
iptables -N "$CHAIN" 2>/dev/null

# 将自定义链插入 FORWARD 链第1位（如果尚未存在）
iptables -C FORWARD -j "$CHAIN" 2>/dev/null || \
    iptables -I FORWARD 1 -j "$CHAIN"

# ============================================================
# 2. 读取 UCI 配置
# ============================================================

INT_DISABLE=$(uci -q get network.lte.internal_forward_disable) || INT_DISABLE=0
EXT_DISABLE=$(uci -q get network.lte.external_forward_disable) || EXT_DISABLE=0
SIM_MODE=$(uci -q get network.lte.modem_simnum) || SIM_MODE=0

# ============================================================
# 3. 确定当前活动 SIM 卡槽
# ============================================================
#   SIM_MODE:
#     0 = 外置卡优先（动态）
#     1 = 仅内置（固定 slot 1）
#     2 = 仅外置（固定 slot 0）
#     3 = 双卡备份（动态，硬件自动切换 + 软件回退）

case "$SIM_MODE" in
    1) ACTIVE_SLOT=1 ;;
    2) ACTIVE_SLOT=0 ;;
    *) ACTIVE_SLOT=$(cat /tmp/lte_active_slot 2>/dev/null || echo 0) ;;
esac

# ============================================================
# 4. 清空自定义链并重建规则
# ============================================================

iptables -F "$CHAIN"

if [ "$ACTIVE_SLOT" = "1" ] && [ "$INT_DISABLE" = "1" ]; then
    iptables -A "$CHAIN" -o "$LTE_DEV" -j DROP
    logger -t "lte_forward" "BLOCKED on $LTE_DEV (slot=internal, int_disable=$INT_DISABLE)"
elif [ "$ACTIVE_SLOT" = "0" ] && [ "$EXT_DISABLE" = "1" ]; then
    iptables -A "$CHAIN" -o "$LTE_DEV" -j DROP
    logger -t "lte_forward" "BLOCKED on $LTE_DEV (slot=external, ext_disable=$EXT_DISABLE)"
else
    logger -t "lte_forward" "ALLOWED on $LTE_DEV (slot=$ACTIVE_SLOT, int=$INT_DISABLE, ext=$EXT_DISABLE)"
fi

#session_41f42d12.md