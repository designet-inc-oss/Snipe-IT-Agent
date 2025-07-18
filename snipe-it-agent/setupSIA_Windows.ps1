# ---- �Z�b�g�A�b�v�c�[���ނ̔z�u�� ----
$username = $env:USERNAME
$setupToolPath = "C:\Users\$username\Desktop\snipe-it-agent"

# ---- Python3�ƕK�v�\�t�g�E�F�A�_�E�����[�h ----
$username = $env:USERNAME
$localAppPath = "C:\Users\$username\AppData\Local\Programs\Python\Python313"

# Python�����[�J���ɒu�����C���X�g�[���[���g���ă_�E�����[�h
$installerPath = "$setupToolPath\python-3.13.0-amd64.exe"

# �T�C�����g�C���X�g�[���i���[�U�[�̈�ɃC���X�g�[���j----
Start-Process -FilePath $installerPath -ArgumentList `
    "/quiet", `
    "InstallAllUsers=0", `
    "PrependPath=1", `
    "TargetDir=$localAppPath", `
    "Include_launcher=1" `
    -Wait

# �p�X���ēx�ǉ��i���̃Z�b�V�����Ŏg����悤�Ɂj
$env:Path += ";$localAppPath;$localAppPath\Scripts"
$pythonExe = "$localAppPath\python.exe"

# requests, psutil ���C���X�g�[�� ----
Start-Process -FilePath $pythonExe -ArgumentList "-m pip install --upgrade pip" -Wait
Start-Process -FilePath $pythonExe -ArgumentList "-m pip install requests psutil" -Wait

# �o�[�W�����m�F�i�I�v�V�����j
& $pythonExe --version
& $pythonExe -m pip list



# ---- Snipe-IT-Agent������s�^�X�N�쐬 ----
$taskName = "Snipe-IT-Agent"
$taskDescription = "Snipe-IT-Agent������s"
$computername = $env:COMPUTERNAME
$fullUserId = "$computername\$username"
$pythonPath = "C:\Users\$username\AppData\Local\Programs\Python\Python313\python.exe"
$scriptArgs = "snipe-it-agent.py --model-id 2 --fieldset-id 2"
$startIn = "$setupToolPath\"
# ���[�U�[�m�F�i�I�v�V�����j
Write-Host "���[�U�[: $fullUserId"

# XML�𕶎���Ƃ��č\�z�i�ϐ��W�J�܂ށj
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

# �ۑ��p�X
$xmlPath = "$env:TEMP\SnipeITAgentTask.xml"

# �ۑ��Ɠo�^
$taskXml | Out-File -Encoding Unicode -FilePath $xmlPath
Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $xmlPath | Out-String) -Force

# ��Еt��
Remove-Item $xmlPath