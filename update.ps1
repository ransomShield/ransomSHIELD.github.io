# Define the event log and event ID you want to monitor

$versionUrl = "https://ransomSHIELD.github.io//version.txt"
$taskName = "ransomSHIELD"
$taskNameUI = "RS UI"
$webClient = New-Object System.Net.WebClient
$webClient.Encoding = [System.Text.Encoding]::UTF8
$i = 0;
while ($true) {
    try {
        if($i++ -lt 100) {
            $task = Get-ScheduledTask -TaskName $taskName
            Write-host $task.State
            # Check if the task is currently running
            if ($task.State -ne "Running") {
                # Task is not running, start it
                Start-ScheduledTask -InputObject $task
                Write-Host "Scheduled task '$taskName' started."
            }
        }
        else {
            $i = 0
            $webcontent = $webClient.DownloadString($versionUrl)
            $folderName = "version" + $webContent.Trim()
            if($folderName -ne "") {
                # Check if the local folder exists
                    if (Test-Path -Path $folderName -PathType Container) {
                        Write-Host "'$folderName' is latest version."
                    } else {
                        Write-Host "Updating to '$folderName'..."
                        Get-ChildItem -Directory -Filter ".\version*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                        New-Item -Path $folderName -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                        # restart sch task
                        schtasks /End /TN $taskName
                        schtasks /Run /TN $taskName
                        schtasks /End /TN $taskNameUI
                        schtasks /Run /TN $taskNameUI
                    }
            } 
        }
    }
    catch {
        Write-Host "something went wrong with web fetch... trying later!"
    }
    Start-Sleep -Seconds 10
}