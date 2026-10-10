#!/bin/bash
# ============================================================
# Hive 执行模式切换脚本（本地 / 集群）
# 用法：
#   bash switch_mode.sh local    # 切到本地模式（单机，不起 YARN，省内存）
#   bash switch_mode.sh yarn     # 切到集群模式（走 YARN 分布式）
#   bash switch_mode.sh          # 不带参数 = 查看当前模式
# 原理：每次用「覆盖」方式写 ~/.hiverc，保证只有干净的两行，不残留重复
# ============================================================

MODE="${1:-}"

show_help() {
    echo "用法："
    echo "  bash switch_mode.sh local    # 切到本地模式"
    echo "  bash switch_mode.sh yarn     # 切到集群模式"
    echo "  bash switch_mode.sh          # 查看当前模式"
    echo
    echo "当前 ~/.hiverc 内容："
    cat ~/.hiverc 2>/dev/null || echo "(空)"
}

# 不带参数：查看当前模式
if [ -z "$MODE" ]; then
    show_help
    exit 0
fi

# 参数校验
if [ "$MODE" != "local" ] && [ "$MODE" != "yarn" ]; then
    echo "错误：未知模式 '$MODE'，只能是 local 或 yarn"
    echo
    show_help
    exit 1
fi

# 根据模式设置变量
if [ "$MODE" = "local" ]; then
    FRAMEWORK=local
    AUTO=true
    MSG="本地模式（单机，不起 YARN，省内存）"
else
    FRAMEWORK=yarn
    AUTO=false
    MSG="集群模式（走 YARN 分布式，需先 start-yarn.sh）"
fi

# 用 > 覆盖写入，保证干净不残留
cat > ~/.hiverc <<EOF
set mapreduce.framework.name=$FRAMEWORK;
set hive.exec.mode.local.auto=$AUTO;
EOF

echo "已切换到【$MSG】"
echo "~/.hiverc 现在的内容："
cat ~/.hiverc
