# Define the event log and event ID you want to monitor

$versionUrl = "https://ransomSHIELD.github.io//version.txt"
$taskName = "ransomSHIELD"

while ($true) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Encoding = [System.Text.Encoding]::UTF8
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
                }
        } 
    }
    catch {
        Write-Host "something went wrong with web fetch... trying later!"
    }
    Start-Sleep -Seconds 300
}