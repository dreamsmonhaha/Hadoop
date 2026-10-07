# master 上执行 搭好slave后
ssh-copy-id hx@slave1          # 第一次输 slave1 密码
ssh hx@slave1 exit             # 不要密码 = 成功
ssh-copy-id hx@slave2
ssh hx@slave2 exit
bash run.sh stop
bash run.sh start

# ===== 时间同步验证：master 本机 =====
echo '===================== 时间同步检查: master ====================='
date
chronyc sources
chronyc tracking

# ===== 时间同步验证：slave1 =====
echo '===================== 时间同步检查: slave1 ====================='
ssh hx@slave1 "date; chronyc sources; chronyc tracking"

# ===== 时间同步验证：slave2 =====
echo '===================== 时间同步检查: slave2 ====================='
ssh hx@slave2 "date; chronyc sources; chronyc tracking"

ssh hx@slave1 "cd ~ && rm setup_slave.sh"
ssh hx@slave2 "cd ~ && rm setup_slave2.sh"
echo "- HDFS Web UI : ========http://192.168.80.4:9870======== "
echo "- YARN Web UI : ========http://192.168.80.4:8088======== "
echo "- bash run.sh : =============start or stop============== "

rm slave.sh