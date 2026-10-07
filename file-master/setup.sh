sudo hostnamectl set-hostname master
sudo tee -a /etc/hosts << 'EOF'
192.168.80.4  master
192.168.80.5  slave1
192.168.80.6  slave2
EOF
sudo sed -i '/127\.0\.1\.1/d' /etc/hosts


# root密码
echo 'set Root password'
sudo passwd root
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4

sudo apt update
sudo apt install -y openjdk-8-jdk aria2 chrony

# ===== chrony 时间服务器（master）=====
sudo systemctl stop systemd-timesyncd 2>/dev/null || true
sudo systemctl disable systemd-timesyncd 2>/dev/null || true

sudo sed -i '/^pool /d; /^server /d; /^allow /d; /^local stratum /d' /etc/chrony/chrony.conf

# 可选：master 能上外网就加，不能上外网可以删掉这行
sudo sed -i '$a pool ntp.ubuntu.com iburst' /etc/chrony/chrony.conf

sudo sed -i '$a allow 192.168.80.0/24' /etc/chrony/chrony.conf
sudo sed -i '$a local stratum 10' /etc/chrony/chrony.conf

sudo systemctl enable chrony
sudo systemctl restart chrony

sudo ufw allow 123/udp 2>/dev/null || true

sleep 3
chronyc sources || true
chronyc tracking || true

# 解压到/opt然后换用户权限
cd ~
sudo mv hadoop-3.3.6.tar.gz /opt/
cd /opt
sudo tar -zxvf /opt/hadoop-3.3.6.tar.gz -C /opt
sudo rm /opt/hadoop-3.3.6.tar.gz
sudo chown -R hx:hx /opt/hadoop-3.3.6

#配置Java和hadoop的环境变量
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


#配置hadoop的环境变量加java路径
cd $HADOOP_HOME/etc/hadoop
cat >> /opt/hadoop-3.3.6/etc/hadoop/hadoop-env.sh << 'EOF'
# Java
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
EOF

# core-site.xml配置
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
sed -i '/<configuration>/r /tmp/core-props.xml' /opt/hadoop-3.3.6/etc/hadoop/core-site.xml
rm /tmp/core-props.xml


# hdfs-site.xml配置
cat > /tmp/hdfs-props.xml << 'EOF'
<property>
<name>dfs.replication</name>
<value>2</value>
</property>
<property>
<name>dfs.namenode.name.dir</name>
<value>file:/opt/hadoop-3.3.6/tmp/dfs/name</value>
</property>
<property>
<name>dfs.datanode.data.dir</name>
<value>file:/opt/hadoop-3.3.6/tmp/dfs/data</value>
</property>
EOF
sed -i '/<configuration>/r /tmp/hdfs-props.xml' /opt/hadoop-3.3.6/etc/hadoop/hdfs-site.xml
rm /tmp/hdfs-props.xml



# mapred-site.xml配置
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
sed -i '/<configuration>/r /tmp/mapred-props.xml' /opt/hadoop-3.3.6/etc/hadoop/mapred-site.xml
rm /tmp/mapred-props.xml




# yarn-site.xml配置
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
sed -i '/<configuration>/r /tmp/yarn-props.xml' /opt/hadoop-3.3.6/etc/hadoop/yarn-site.xml
rm /tmp/yarn-props.xml


# workers配置
cat > /opt/hadoop-3.3.6/etc/hadoop/workers << 'EOF'
master
slave1
slave2
EOF


mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '=====================================================enter 3 times====================================================='
ssh-keygen -t rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys


# format 本机 NameNode（不需要 slave 就绪） 
ssh-keyscan -H master localhost >> ~/.ssh/known_hosts 2>/dev/null
ssh hx@master exit
hdfs namenode -format 
start-dfs.sh
start-yarn.sh
jps
#master已搭建完Hadoop


#===============================================================================================================

#搭建master上的hive

#hive换到/opt解压换普通权限加环境变量
cd ~
sudo mv apache-hive-3.1.2-bin.tar.gz /opt/
cd /opt
sudo tar -zxvf apache-hive-3.1.2-bin.tar.gz
sudo rm /opt/apache-hive-3.1.2-bin.tar.gz
sudo mv /opt/apache-hive-3.1.2-bin /opt/hive-3.1.2
sudo chown -R hx:hx /opt/hive-3.1.2
echo 'export HIVE_HOME=/opt/hive-3.1.2' >> ~/.bashrc
echo 'export PATH=$PATH:$HIVE_HOME/bin' >> ~/.bashrc
source ~/.bashrc


#下载mysql-connector-java-8.0.28.jar并放到hive lib目录下
cd /tmp
aria2c -x 4 -s 4 -k 1M -c --file-allocation=none -o mysql-connector-java-8.0.28.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar
cp mysql-connector-java-8.0.28.jar /opt/hive-3.1.2/lib/
mv /opt/hive-3.1.2/lib/guava-19.0.jar /opt/hive-3.1.2/lib/guava-19.0.jar.bak  
cp /opt/hadoop-3.3.6/share/hadoop/common/lib/guava-27.0-jre.jar /opt/hive-3.1.2/lib/ 
mv /opt/hive-3.1.2/lib/log4j-slf4j-impl-2.10.0.jar /opt/hive-3.1.2/lib/log4j-slf4j-impl-2.10.0.jar.bak


#下载mysql,配置
sudo apt update
sudo apt install -y mysql-server 
sudo systemctl start mysql
sudo mysql -e "CREATE DATABASE hive_metastore DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci; ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '123456'; FLUSH PRIVILEGES;"
cp /opt/hive-3.1.2/conf/hive-env.sh.template /opt/hive-3.1.2/conf/hive-env.sh

#给hive指定依赖变量
cat >> /opt/hive-3.1.2/conf/hive-env.sh << 'EOF'
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/opt/hadoop-3.3.6
export HIVE_CONF_DIR=/opt/hive-3.1.2/conf
EOF

#配置hive-site.xml
cat > /opt/hive-3.1.2/conf/hive-site.xml << 'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://localhost:3306/hive_metastore?createDatabaseIfNotExist=true&amp;useSSL=false&amp;allowPublicKeyRetrieval=true&amp;serverTimezone=UTC&amp;characterEncoding=utf8</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>com.mysql.cj.jdbc.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>root</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>123456</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>/user/hive/warehouse</value>
  </property>
  <property>
    <name>hive.metastore.schema.verification</name>
    <value>false</value>
  </property>
  <property>
    <name>datanucleus.schema.autoCreateAll</name>
    <value>false</value>
  </property>
</configuration>
EOF


hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -mkdir -p /tmp/hive
hdfs dfs -chmod -R 777 /tmp/hive /user/hive
source ~/.bashrc
schematool -dbType mysql -initSchema --verbose
hive --service metastore & 
sleep 2
jps    # RunJar
hive -e "show databases;"
echo 'Running: hive'
echo 'Tip:(bash run.sh) to start/stop cluster'
cd ~
rm setup.sh
bash ~/run.sh stop    # 关停所有
echo 'Setup complete! Entering new shell...'
exec bash -l
#hive:show databases;
#quit;

#============================================================================================
