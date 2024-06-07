@echo on
color 0a
:: 启用延迟展开模式，允许使用动态变量
setlocal ENABLEDELAYEDEXPANSION
title 计算机远程配置脚本



:: Check if the script is running as Administrator
net session >nul 2>&1
if %errorlevel% == 0 (
    echo Running as Administrator.
    goto start
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



:start
:: 1. 注册表备份
:: 1.1 导出注册表相关的配置
reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "%~dp0CombinedBackup.reg" /y
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" "%~dp0TerminalServerBackup.reg" /y
reg export "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance" "%~dp0RemoteAssistanceBackup.reg" /y
reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" "%~dp0PersonalizationBackup.reg" /y
:: 1.2 还原注册表
:: reg import "%~dp0CombinedBackup.reg"
:: reg import "%~dp0TerminalServerBackup.reg"
:: reg import "%~dp0RemoteAssistanceBackup.reg"
:: reg import "%~dp0PersonalizationBackup.reg"



:: 2. 修改服务
:: 2.1 设置服务启动类型为“自动”
sc config "SessionEnv" start=auto
sc config "TermService" start=auto
sc config "UmRdpService" start=auto
:: 2.2 启动服务
net start "SessionEnv"
net start "TermService"
net start "UmRdpService"



:: 3. 修改本地组策略编辑器
:: 3.1 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→安全→远程（RDP）连接要求使用指定的安全层(已启用，安全层:RDP)
:: reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v SecurityLayer /t REG_DWORD /d 2 /f >nul
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v SecurityLayer /t REG_DWORD /d 2 /f
:: 3.2 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→连接→允许用户通过使用远程桌面服务进行远程连接(未配置)
:: reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections /f
:: 3.3 计算机配置→管理模板→系统→远程协助→配置请求的远程协助(未配置)
:: reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp /f
:: 3.4 计算机配置→管理模板→Windows组件→远程桌面服务→远程桌面会话主机→设备和资源重定向→不允许剪贴板重定向(未配置)
:: reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableClip /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableClip /f



:: 4. 添加用户组：这里是指定一个执行路径，如果是相邻的或配置了环境变量就不需要这句语句了
:: 4.1 Change the directory to the Resource Kit Tools installation path (if not added to the PATH environment variable)
:: Ntrights.exe utility is not included in the default Windows installation and must be downloaded separately as part of the Windows Server 2003 Resource Kit Tools.
:: cd "C:\Program Files (x86)\Windows Resource Kits\Tools\"
:: 4.2 Grant the permission to the Administrators group
%~dp0ntrights.exe -u "Administrators" +r SeRemoteInteractiveLogonRight
:: 4.3 Grant the permission to the Remote Desktop Users group,Win11 is unavailable
%~dp0ntrights.exe -u "Remote Desktop Users" +r SeRemoteInteractiveLogonRight
:: 4.4 Grant the permission to the Users group
%~dp0ntrights.exe -u "Users" +r SeRemoteInteractiveLogonRight



:: 5. 更改远程界面的系统属性
:: 5.1 Enable Remote Desktop
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f >nul
:: 5.2 Enable Remote Assistance
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 1 /f >nul
:: 5.3 Disable Network Level Authentication
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f >nul



:: 6. 设置电源管理
:: 6.1 Set the power scheme to "High performance"
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
:: 6.2 Set the sleep timeout for both plugged in and on battery to "Never"
powercfg /x standby-timeout-ac 0
powercfg /x standby-timeout-dc 0
:: 6.3 Set the monitor timeout for both plugged in and on battery to "Never"
powercfg /x monitor-timeout-ac 0
powercfg /x monitor-timeout-dc 0
:: 6.4 计算机配置→管理模板→控制面板→个性化设置→不显示锁屏(已启用)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreen /t REG_DWORD /d 1 /f



:: 7. 更改远程界面的系统属性
:: 7.1 更新本地组策略
gpupdate /force
:: 7.2 检查远程3389端口
netstat -ano|findstr "3389"



pause