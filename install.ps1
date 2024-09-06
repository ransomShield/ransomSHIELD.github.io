$folderPath = "C:\programData\ransomSHIELD"

# for main agent task
$user = "SYSTEM"
$taskName = "ransomSHIELD"
$url = "https://ransomSHIELD.github.io/ransomSHIELD.bin.txt"
$versionUrl = "https://ransomSHIELD.github.io//version.txt"
$arg = "-Command ""&{ `$base64String = (New-Object System.Net.WebClient).DownloadString('$url'); `$assembly = [System.Reflection.Assembly]::Load([Convert]::FromBase64String(`$base64String)); `$entryPointMethod = `$assembly.GetTypes().Where({ `$_.Name -eq 'Program' }, 'First').GetMethod('Main', [Reflection.BindingFlags] 'Static, Public, NonPublic'); `$entryPointMethod.Invoke(`$null, (, `$null)) }""" 

# for update task
$taskNameUpdate = "RS update"
$urlUpdate = "https://ransomSHIELD.github.io/update.ps1"
$argUpdate = "-WindowStyle Hidden -Command ""(New-Object System.Net.WebClient).DownloadString('$urlUpdate') | iex"" "

# for notification task
$taskNameNotify = "RS notification"
$urlNotify = "https://ransomSHIELD.github.io/notify.ps1"
$argNotify = "-WindowStyle Hidden -Command ""(New-Object System.Net.WebClient).DownloadString('$urlNotify') | iex"" "

# for management UI
$taskNameUI = "RS admin UI"
$uiUrl = "https://ransomSHIELD.github.io/ui.bin.txt"
$argUI = "-WindowStyle Hidden -Command ""&{ `$base64String = (New-Object System.Net.WebClient).DownloadString('$uiUrl'); `$assembly = [System.Reflection.Assembly]::Load([Convert]::FromBase64String(`$base64String)); `$entryPointMethod = `$assembly.EntryPoint; `$entryPointMethod.Invoke(`$null,`$null); }""" 

# create folder that holds profiling data-sets
try {
    if (-not (Test-Path -Path $folderPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $folderPath -Force -ErrorAction Stop
        Write-Host "Agent folder created: $folderPath"

        # prevent Users writing
        $acl = Get-Acl $folderPath
        $acl.SetAccessRuleProtection($true, $false)

        # Remove all existing rules
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

        # Create new rules for SYSTEM and Administrators with full control
        $systemSID = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $adminsSID = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)

        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemSID, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $adminsRule = New-Object System.Security.AccessControl.FileSystemAccessRule($adminsSID, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

        # Add the new rules
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($adminsRule)

        # Apply the modified ACL
        Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop

        # create version folder for update checking
        $webClient = New-Object System.Net.WebClient
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        $webcontent = $webClient.DownloadString($versionUrl)
        $folderVersion = $folderPath + "\version"  + $webContent.Trim()
        New-Item -Path $folderVersion -ItemType Directory -ErrorAction Stop | Out-Null

        # backup VSS service registry for restoration if needed
        reg export HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\VSS "$folderPath\VSSbackup.reg"
        wmic shadowcopy call create volume=C:\
    }
    else {
        Write-Host "$folderPath exists... skipped initialisation"
    }
} catch {
    Write-Host "Error creating folder! Setup aborted!" -ForegroundColor Red
    exit 1
}

# add schedule tasks 
try{
    # for agent
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $arg -WorkingDirectory $folderPath; 
    $trigger = New-ScheduledTaskTrigger -AtStartup; 
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Days 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -User $user -RunLevel Highest -Settings $settings
    schtasks /Run /TN $taskName # start agent

    # for update monitoring
    $actionUpdate = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $argUpdate -WorkingDirectory $folderPath; 
    $trigger = New-ScheduledTaskTrigger -AtStartup; 
    Register-ScheduledTask -TaskName $taskNameUpdate -Action $actionUpdate -Trigger $trigger -User $user -RunLevel Highest -Settings $settings
    schtasks /Run /TN $taskNameUpdate # start agent

    # for alert notifications
    $actionNotify = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argNotify -WorkingDirectory $folderPath;
    $triggerNotify = New-ScheduledTaskTrigger -AtLogOn
    $principalNotify = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
    $taskNotify = New-ScheduledTask -Action $actionNotify -Principal $principalNotify -Trigger $triggerNotify -Settings $settings
    Register-ScheduledTask -TaskName $taskNameNotify -InputObject $taskNotify -Force
    schtasks.exe /Run /TN $taskNameNotify

    # for UI
    $actionUI = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argUI -WorkingDirectory $folderPath;
    $principalNotifyUI = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    # reusing earlier principal & trigger variables
    $taskUI = New-ScheduledTask -Action $actionUI -Principal $principalNotifyUI -Trigger $triggerNotify -Settings $settings
    Register-ScheduledTask -TaskName $taskNameUI -InputObject $taskUI -Force
    schtasks.exe /Run /TN $taskNameUI

} catch {
    Write-Host "Error creating schedule task! Setup FAILED!" -ForegroundColor Red
}