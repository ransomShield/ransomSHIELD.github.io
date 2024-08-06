# configurable items below
$folderPath = "C:\programData\ransomSHIELD"
$taskName = "ransomSHIELD"
$taskNameNotify = "RS notification"
$user = "SYSTEM"
$url = "https://ransomSHIELD.github.io/ransomSHIELD.bin.txt"
$versionUrl = "https://ransomSHIELD.github.io//version.txt"
$arg = "-Command ""&{ `$base64String = (New-Object System.Net.WebClient).DownloadString('$url'); `$assembly = [System.Reflection.Assembly]::Load([Convert]::FromBase64String(`$base64String)); `$entryPointMethod = `$assembly.GetTypes().Where({ `$_.Name -eq 'Program' }, 'First').GetMethod('Main', [Reflection.BindingFlags] 'Static, Public, NonPublic'); `$entryPointMethod.Invoke(`$null, (, `$null)) }""" 

$urlNotify = "https://ransomSHIELD.github.io/notify.ps1"
$argNotify = "-WindowStyle Hidden -Command ""iwr '$urlNotify' | iex"" "

# create folder that holds profiling data-sets
try {
    $null = New-Item -ItemType Directory -Path $folderPath -Force -ErrorAction Stop
    Write-Host "Agent folder created: $folderPath"
    # create version folder for update checking
    $webClient = New-Object System.Net.WebClient
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    $webcontent = $webClient.DownloadString($versionUrl)
    $folderVersion = $folderPath + "\version"  + $webContent.Trim()
    New-Item -Path $folderVersion -ItemType Directory -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Error creating folder! Setup aborted!" -ForegroundColor Red
    exit 1
}

# add schedule task that starts agent
try{
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $arg -WorkingDirectory $folderPath; 
    $trigger = New-ScheduledTaskTrigger -AtStartup; 
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Days 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User $user -RunLevel Highest -Settings $settings
    schtasks /Run /TN $taskName # start agent

    # install notify agent
    $actionNotify = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argNotify -WorkingDirectory $folderPath;
    $triggerNotify = New-ScheduledTaskTrigger -AtLogOn
    $principalNotify = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $taskNotify = New-ScheduledTask -Action $actionNotify -Principal $principalNotify -Trigger $triggerNotify -Settings $settings
    Register-ScheduledTask -TaskName $taskNameNotify -InputObject $taskNotify -Force
    schtasks.exe /Run /TN $taskNameNotify

} catch {
    Write-Host "Error creating schedule task! Setup FAILED!" -ForegroundColor Red
}