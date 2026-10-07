@echo off
echo make sure you have Internet
pause
set TARGET_USER=hx
set TARGET_IP=192.168.80.6
set TARGET_DIR=~/
set FILES_TO_SEND=.\hadoop-3.3.6.tar.gz .\*.sh README.md

:: ===== 2. 清理 known_hosts 里旧的主机指纹（应对快照回退后指纹变化） =====
ssh-keygen -R %TARGET_IP% >nul 2>&1

:: ===== 3. 本地没密钥才生成（已有则跳过，不覆盖） =====
if not exist "%USERPROFILE%\.ssh\id_rsa.pub" (
    echo Generating SSH keypair...
    ssh-keygen -t rsa -N "" -f "%USERPROFILE%\.ssh\id_rsa" >nul
)

:: ===== 4. 每次运行都推送公钥（应对快照回退后 authorized_keys 丢失） =====
:: 首次或回退后需要输一次密码；已配好则直接秒过
echo Ensuring passwordless login (enter password ONCE if prompted)...
type "%USERPROFILE%\.ssh\id_rsa.pub" | ssh %TARGET_USER%@%TARGET_IP% "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

:: ===== 5. 检查并下载 Hadoop =====
if not exist "hadoop-3.3.6.tar.gz" (
    if exist "..\file-master\hadoop-3.3.6.tar.gz" (
        echo Copying from file-master...
        copy /y "..\file-master\hadoop-3.3.6.tar.gz" "."
    ) else (
        echo Downloading Hadoop...
        aria2c -d "." -o hadoop-3.3.6.tar.gz -x 16 -s 16 -k 1M -c --file-allocation=none https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
    )
) else (
    echo Hadoop package already exists, skipping.
)




:: ===== 7. 上传文件（免密生效后不再需要输密码） =====
scp %FILES_TO_SEND% %TARGET_USER%@%TARGET_IP%:%TARGET_DIR%

:: ===== 8. 远程转换换行符 =====
ssh %TARGET_USER%@%TARGET_IP% "sed -i 's/\r$//; 1s/^\xEF\xBB\xBF//' %TARGET_DIR%*.sh"

echo Done!
:: ===== 9. 直接进入 Ubuntu 交互式 shell =====
echo Entering Ubuntu interactive shell (type 'exit' to return to Windows)...
ssh -t %TARGET_USER%@%TARGET_IP% "cd ~ && source ~/.bashrc && echo 'Running: =====================bash -i setup_slave2.sh=====================' && bash -l"
pause