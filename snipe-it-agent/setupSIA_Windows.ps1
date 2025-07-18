# ---- セットアップツール類の配置先 ----
$username = $env:USERNAME
$setupToolPath = "C:\Users\$username\Desktop\snipe-it-agent"

# ---- Python3と必要ソフトウェアダウンロード ----
$username = $env:USERNAME
$localAppPath = "C:\Users\$username\AppData\Local\Programs\Python\Python313"

# Pythonをローカルに置いたインストーラーを使ってダウンロード
$installerPath = "$setupToolPath\python-3.13.0-amd64.exe"

# サイレントインストール（ユーザー領域にインストール）----
Start-Process -FilePath $installerPath -ArgumentList `
    "/quiet", `
    "InstallAllUsers=0", `
    "PrependPath=1", `
    "TargetDir=$localAppPath", `
    "Include_launcher=1" `
    -Wait

# パスを再度追加（このセッションで使えるように）
$env:Path += ";$localAppPath;$localAppPath\Scripts"
$pythonExe = "$localAppPath\python.exe"

# requests, psutil をインストール ----
Start-Process -FilePath $pythonExe -ArgumentList "-m pip install --upgrade pip" -Wait
Start-Process -FilePath $pythonExe -ArgumentList "-m pip install requests psutil" -Wait

# バージョン確認（オプション）
& $pythonExe --version
& $pythonExe -m pip list



# ---- Snipe-IT-Agent定期実行タスク作成 ----
$taskName = "Snipe-IT-Agent"
$taskDescription = "Snipe-IT-Agent定期実行"
$computername = $env:COMPUTERNAME
$fullUserId = "$computername\$username"
$pythonPath = "C:\Users\$username\AppData\Local\Programs\Python\Python313\python.exe"
$scriptArgs = "snipe-it-agent.py --model-id 2 --fieldset-id 2"
$startIn = "$setupToolPath\"
# ユーザー確認（オプション）
Write-Host "ユーザー: $fullUserId"

# XMLを文字列として構築（変数展開含む）
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>{0}</Date>
    <Author>{1}</Author>
    <Description>{2}</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>{3}</UserId>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>{3}</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>{4}</Command>
      <Arguments>{5}</Arguments>
      <WorkingDirectory>{6}</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@ -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ss"), $username, $taskDescription, $fullUserId, $pythonPath, $scriptArgs, $startIn

# 保存パス
$xmlPath = "$env:TEMP\SnipeITAgentTask.xml"

# 保存と登録
$taskXml | Out-File -Encoding Unicode -FilePath $xmlPath
Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $xmlPath | Out-String) -Force

# 後片付け
Remove-Item $xmlPath