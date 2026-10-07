#!/bin/bash

# ============================================================
# Hadoop + Hive One-click Start/Stop Script
# Usage:
#   bash run.sh          # Auto-detect: stop if running, start if stopped
#   bash run.sh start    # Force start cluster
#   bash run.sh stop     # Force stop cluster
# ============================================================

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/opt/hadoop-3.3.6
export HIVE_HOME=/opt/hive-3.1.2
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin

IS_RUNNING=$(jps | grep -E "NameNode|RunJar" | wc -l)

start_all() {
    echo ">>> Starting cluster..."
    start-dfs.sh
    start-yarn.sh
    hive --service metastore > /dev/null 2>&1 &
    sleep 2
    jps
}

stop_all() {
    echo ">>> Stopping cluster..."
    pkill -f 'hive.*metastore'  # Stop Hive Metastore (the RunJar process)
    stop-yarn.sh
    stop-dfs.sh
    sleep 2
    jps
}

if [ "$1" = "start" ]; then
    start_all
elif [ "$1" = "stop" ]; then
    stop_all
elif [ "$IS_RUNNING" -gt 0 ]; then
    echo ">>> Cluster is running, executing stop..."
    stop_all
else
    echo ">>> Cluster is stopped, executing start..."
    start_all
fi

# 防止以后在 slave 上误跑，把 NameNode 起错地方
if [ "$(hostname)" != "master" ]; then
    echo "run.sh 只能在 master 上执行"; exit 1
fi
