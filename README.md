# Hadoop + Hive 完全分布式部署

**集群规模**：1 台 master + 2 台 slave

---

## Windows 前置需求

| #   | 软件                                   | 说明         |
|:---:| ------------------------------------ | ---------- |
| 1   | Aria2                                | 需加入 `PATH` |
| 2   | VMware Workstation Pro               | 虚拟机平台      |
| 3   | ubuntu-22.04.5-live-server-amd64.iso | 系统镜像       |

镜像设置：`http://mirrors.aliyun.com/ubuntu`

> 新建 3 台虚拟机系统完成后，分别在各自的虚拟机按顺序执行 master、slave、slave2 上的 cmd 文件，根据脚本提示完成部署。

---

## 环境信息

| 项目  | 配置                                   |
| --- | ------------------------------------ |
| 虚拟机 | VMware Workstation Pro               |
| 系统  | ubuntu-22.04.5-live-server-amd64.iso |

新建三台虚拟机：

| 用户名 | `hx` |
| --- | ---- |
| 密码  | `aa` |

---

## 网络配置

1. VMware 配置 vmnet 子网为 `192.168.80.0/24`，网关设置 `192.168.80.1`，虚拟机都选对应 vmnet。

2. 各节点 IP 地址：
   
   | 节点     | IP 地址          |
   | ------ | -------------- |
   | master | `192.168.80.4` |
   | slave  | `192.168.80.5` |
   | slave2 | `192.168.80.6` |

3. 新建 3 台虚拟机，装系统时镜像设置 `http://mirrors.aliyun.com/ubuntu/`，勾上 `openssh-server`。

---

## 集群管理

```bash
bash run.sh          # 自动判断
bash run.sh start    # 强制启动（HDFS + YARN + Hive Metastore）
bash run.sh stop     # 强制关闭
```

**验证：**

```bash
jps        # 应有 NameNode、DataNode、ResourceManager、NodeManager、RunJar
hive -e "show databases;"
```

---

## Web UI 访问地址

| 服务          | 地址                       |
| ----------- | ------------------------ |
| HDFS Web UI | http://192.168.80.4:9870 |
| YARN Web UI | http://192.168.80.4:8088 |
