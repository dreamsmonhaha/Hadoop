# ===== 主机名 + hosts =====
sudo hostnamectl set-hostname slave2
sudo tee -a /etc/hosts << 'EOF'
192.168.80.4  master
192.168.80.5  slave1
192.168.80.6  slave2
EOF
sudo sed -i '/127\.0\.1\.1/d' /etc/hosts

echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
sudo apt update
sudo apt install -y openjdk-8-jdk chrony
# ===== chrony 时间客户端（slave2）=====
sudo systemctl stop systemd-timesyncd 2>/dev/null || true
sudo systemctl disable systemd-timesyncd 2>/dev/null || true

sudo sed -i '/^pool /d; /^server /d; /^allow /d; /^local stratum /d' /etc/chrony/chrony.conf
sudo sed -i '$a server master iburst' /etc/chrony/chrony.conf

sudo systemctl enable chrony
sudo systemctl restart chrony

sudo ufw allow 123/udp 2>/dev/null || true

sleep 5
sudo chronyc makestep 2>/dev/null || true
chronyc sources || true
chronyc tracking || true

# ===== 解压 Hadoop 到 /opt =====
cd ~
sudo mv hadoop-3.3.6.tar.gz /opt/
cd /opt
sudo tar -zxvf /opt/hadoop-3.3.6.tar.gz -C /opt
sudo rm /opt/hadoop-3.3.6.tar.gz
sudo chown -R hx:hx /opt/hadoop-3.3.6

# ===== 环境变量（和 master 同款，没有 Hive 行）=====
cat >> ~/.bashrc << 'EOF'
# Java
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export JRE_HOME=${JAVA_HOME}/jre
# Hadoop
export HADOOP_HOME=/opt/hadoop-3.3.6
export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
export PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
EOF
source ~/.bashrc
java -version
hadoop version

cat >> /opt/hadoop-3.3.6/etc/hadoop/hadoop-env.sh << 'EOF'
# Java
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
EOF

cd $HADOOP_HOME/etc/hadoop

# core-site.xml：fs.defaultFS 指向 master
cat > /tmp/core-props.xml << 'EOF'
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://master:9000</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/opt/hadoop-3.3.6/tmp</value>
  </property>
EOF
sed -i '/<configuration>/r /tmp/core-props.xml' core-site.xml
rm /tmp/core-props.xml

# hdfs-site.xml：slave 只要副本数和 datanode 目录
cat > /tmp/hdfs-props.xml << 'EOF'
  <property>
    <name>dfs.replication</name>
    <value>2</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:/opt/hadoop-3.3.6/tmp/dfs/data</value>
  </property>
EOF
sed -i '/<configuration>/r /tmp/hdfs-props.xml' hdfs-site.xml
rm /tmp/hdfs-props.xml

# mapred-site.xml：和 master 完全一样，直接抄
cat > /tmp/mapred-props.xml << 'EOF'
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.env</name>
    <value>HADOOP_MAPRED_HOME=/opt/hadoop-3.3.6</value>
  </property>
  <property>
    <name>mapreduce.map.env</name>
    <value>HADOOP_MAPRED_HOME=/opt/hadoop-3.3.6</value>
  </property>
  <property>
    <name>mapreduce.reduce.env</name>
    <value>HADOOP_MAPRED_HOME=/opt/hadoop-3.3.6</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.map.java.opts</name>
    <value>-Xmx384m</value>
  </property>
  <property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>
  </property>
  <property>
    <name>mapreduce.reduce.java.opts</name>
    <value>-Xmx384m</value>
  </property>
EOF
sed -i '/<configuration>/r /tmp/mapred-props.xml' mapred-site.xml
rm /tmp/mapred-props.xml

# yarn-site.xml：和 master 完全一样，直接抄（RM 仍是 master）
cat > /tmp/yarn-props.xml << 'EOF'
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>master</value>
  </property>
  <property>
    <name>yarn.resourcemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.resourcemanager.webapp.address</name>
    <value>0.0.0.0:8088</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>1024</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>1</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>256</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>1024</value>
  </property>
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
  </property>
EOF
sed -i '/<configuration>/r /tmp/yarn-props.xml' yarn-site.xml
rm /tmp/yarn-props.xml

# workers（和 master 保持一致，方便以后互传配置）
cat > workers << 'EOF'
master
slave1
slave2
EOF

echo '===== Slave setup done! ====='
echo '搭好所有的slave后回 master 执行: bash -i slave.sh .....或自己执行后续添加的slave执行看slave.sh的文件去操作	....ssh-copy-id hx@slave? && ssh hx@slave1 exit.... master上执行bash run.sh stop bash run.sh start'
exec bash -l
