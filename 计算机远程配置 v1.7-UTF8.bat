@echo on
color 0a
:: 启用延迟展开模式，允许使用动态变量
setlocal ENABLEDELAYEDEXPANSION
title 计算机远程配置脚本 v1.7
:: 打印当前脚本文件夹文件结构
cd /D "%~dp0"
tree /F
echo 计算机远程配置脚本 v1.7



:: Check if the script is running as Administrator
net session >nul 2>&1
if %errorlevel% == 0 (
    echo Running as Administrator.
    goto initlization
) else (
    echo Not running as Administrator.
)
:: Create a temporary VBScript file to elevate privileges
set "temp_vbs=%temp%\elevate.vbs"
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp_vbs%"
echo UAC.ShellExecute "%~f0", "", "", "runas", 1 >> "%temp_vbs%"
:: Run the VBScript file to elevate the batch file
cscript //nologo "%temp_vbs%"
del "%temp_vbs%"
exit



:initlization
:: ------------------------------------------------------------------------------------------------------------------------
:: 1. 新建备份文件夹
set "backup_dir=%~dp0Backup"
if not exist "%backup_dir%" (
    mkdir "%backup_dir%"
    echo 注册表备份文件夹已创建: %backup_dir%
) else (
    echo 注册表备份文件夹已存在: %backup_dir%
)
:: 2. 选取操作系统
:: 2.1 获取操作系统信息
for /f "tokens=2 delims==" %%G in ('wmic os get version /value') do set OS_VERSION=%%G
for /f "tokens=2 delims==" %%G in ('wmic os get buildnumber /value') do set OS_BUILDNUMBER=%%G
:: 2.2 判断 Windows 10和 Windows 11
if "%OS_VERSION:~0,3%" == "10." (
    if %OS_BUILDNUMBER% LSS 22000 (
        set OS_NAME=Windows10
    ) else (
        set OS_NAME=Windows11
    )
)
:: 2.3 判断 Windows 7和 Windows XP
if "%OS_VERSION:~0,3%" == "6.1" set OS_NAME=Windows7
if "%OS_VERSION:~0,3%" == "5.1" set OS_NAME=WindowsXP
:: 2.4 打印判断结果
echo [Windows NT 内核版本]:"%OS_VERSION%",[操作系统内部版本号]:"%OS_BUILDNUMBER%",[操作系统]:"%OS_NAME%"
:: 2.5 判断执行条件并跳转
if not defined OS_NAME (
    echo Unsupported Windows version
    goto NoSupport
)
if "%OS_NAME%" == "Windows11" (
    echo Windows11 is not supported
    goto NoSupport
)
if "%OS_NAME%" == "Windows10" (
    echo Running Windows 10 code
    goto Windows10
)
if "%OS_NAME%" == "Windows7" (
    echo Running Windows 7 code
    goto Windows7
)
if "%OS_NAME%" == "WindowsXP" (
    echo Running Windows XP code
    goto WindowsXP
)
:: ------------------------------------------------------------------------------------------------------------------------



:Windows10
:: ------------------------------------------------------------------------------------------------------------------------
:: 1. 注册表备份
:: 1.1 导出注册表相关的配置
reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "%~dp0Backup\CombinedBackup.reg" /y
reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" "%~dp0Backup\PersonalizationBackup.reg" /y
:: 1.2 还原注册表
:: reg import "%~dp0Backup\CombinedBackup.reg"
:: reg import "%~dp0Backup\PersonalizationBackup.reg"



:: 2. 替换系统文件
:: 2.1 备份系统文件路径GroupPolicy
xcopy "C:\Windows\System32\GroupPolicy" "%~dp0Backup\GroupPolicy" /E /Y /I
:: 2.2 替换系统文件路径GroupPolicy
xcopy "%~dp0system\GroupPolicy" "C:\Windows\System32\GroupPolicy" /E /Y /I
:: 2.3 执行注册表reg文件
reg import "%~dp0system\Microsoft_output.reg"



:: 3. 修改服务
:: 3.1 设置服务启动类型为“自动”
sc config "SessionEnv" start=auto
sc config "TermService" start=auto
sc config "UmRdpService" start=auto
:: 3.2 启动服务
net start "SessionEnv"
net start "TermService"
net start "UmRdpService"



:: 4. 修改本地组策略编辑器（Windows 10 神州版 不起作用，但依然执行一次）
:: 4.1 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→安全→远程（RDP）连接要求使用指定的安全层(已启用，安全层:RDP)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v SecurityLayer /t REG_DWORD /d 2 /f
:: 4.2 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→连接→允许用户通过使用远程桌面服务进行远程连接(未配置)
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections
if %errorlevel%==0 (
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections /f
) else (
    echo [ERROR] 4.2 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→连接→允许用户通过使用远程桌面服务进行远程连接(未配置)
)
:: 4.3 计算机配置→管理模板→系统→远程协助→配置请求的远程协助(未配置)
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp
if %errorlevel%==0 (
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp /f
) else (
    echo [ERROR] 4.3 计算机配置→管理模板→系统→远程协助→配置请求的远程协助(未配置)
)
:: 4.4 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→设备和资源重定向→不允许剪贴板重定向(未配置)
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableClip
if %errorlevel%==0 (
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableClip /f
) else (
    echo [ERROR] 4.4 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→设备和资源重定向→不允许剪贴板重定向(未配置)
)
:: 4.5 计算机配置→管理模板→控制面板→个性化设置→不显示锁屏(已启用)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f



:: 5. 添加用户组
:: 5.1 Grant the permission to the Administrators group
"%~dp0tools\ntrights.exe" -u "Administrators" +r SeRemoteInteractiveLogonRight
:: 5.2 Grant the permission to the Remote Desktop Users group,Win11 is unavailable
"%~dp0tools\ntrights.exe" -u "Remote Desktop Users" +r SeRemoteInteractiveLogonRight
:: 5.3 Grant the permission to the Users group
"%~dp0tools\ntrights.exe" -u "Users" +r SeRemoteInteractiveLogonRight



:: 6. 关闭防火墙
netsh advfirewall set allprofiles state off
netsh advfirewall show allprofiles

goto verify
:: ------------------------------------------------------------------------------------------------------------------------



:WindowsXP
:: ------------------------------------------------------------------------------------------------------------------------
:: 1. 启动服务："Remote Desktop Help Session Manager" 和 "Telnet"
:: 1.1 设置服务启动类型为“自动”
sc config helpsvc start=auto
sc config TlntSvr start=auto
:: 1.2 启动服务
net start helpsvc
net start TlntSvr



:: 2. 注册表备份
:: 2.1 导出注册表相关的配置
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\Root\RDPDR" "%~dp0Backup\RDPDRBackup.reg" /y
:: 2.2 还原注册表
:: reg import "%~dp0Backup\RDPDRBackup.reg"



:: 3.1 打开注册表，找到 HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\Root\RDPDR ，在RDPDR上点击右键，选择“权限”，改变“everyone”的权限为“完全控制”
"%~dp0tools\subinacl.exe" /subkeyreg "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\Root\RDPDR" /grant=everyone=f
:: 3.2 导入注册表
reg import "%~dp0system\windows_xp_ghost.reg"



:: 4. 关闭防火墙
netsh firewall set opmode disable
netsh firewall show state

goto verify
:: ------------------------------------------------------------------------------------------------------------------------



:Windows7
:: ------------------------------------------------------------------------------------------------------------------------
:: 1. 关闭防火墙
netsh advfirewall set allprofiles state off
netsh advfirewall show allprofiles

goto verify
:: ------------------------------------------------------------------------------------------------------------------------



:verify
:: ------------------------------------------------------------------------------------------------------------------------
:: 1. 注册表备份
:: 1.1 导出注册表相关的配置
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" "%~dp0Backup\TerminalServerBackup.reg" /y
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance" "%~dp0Backup\RemoteAssistanceBackup.reg" /y
:: 1.2 还原注册表
:: reg import "%~dp0Backup\TerminalServerBackup.reg"
:: reg import "%~dp0Backup\RemoteAssistanceBackup.reg"



:: 2. 更改远程界面的系统属性
:: 2.1 Enable Remote Desktop
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
:: 2.2 Enable Remote Assistance
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 1 /f
:: 2.3 Disable Network Level Authentication
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f



:: 3. 设置电源管理以去除休眠
:: 3.1 Set the power scheme to "High performance"
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
:: 3.2 Set the sleep timeout for both plugged in and on battery to "Never"
powercfg /x standby-timeout-ac 0
powercfg /x standby-timeout-dc 0
:: 3.3 Set the monitor timeout for both plugged in and on battery to "Never"
powercfg /x monitor-timeout-ac 0
powercfg /x monitor-timeout-dc 0



:: 4. 更改远程界面的系统属性
:: 4.1 更新本地组策略
gpupdate /force
:: 4.2 检查远程3389端口
netstat -ano | findstr "3389"
:: ------------------------------------------------------------------------------------------------------------------------



:NoSupport
pause
