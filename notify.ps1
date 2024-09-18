# Define the event log and event ID you want to monitor
$logName = "Application"
$eventId = 6666  # Replace with the event ID you're interested in

# Function to write timestamped log messages
function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $message"
}

function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "RansomSHIELD Agent"
    $Toast.Group = "RansomSHIELD Agent"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("RansomSHIELD")
    $Notifier.Show($Toast);
}


# Define the action to take when the event is detected
$action = {
    param($sourceObject, $event)
    Write-Log "Event detected. Analyzing..."
    
    # Log the entire event object for debugging
    Write-Log ("Full event object:`n" + ($event | Format-List | Out-String))
    if ($event.EventRecord) {
        $eventRecord = $event.EventRecord
        Show-Notification -ToastTitle "Threat Neutralised" -ToastText "Please review with RansomSHIELD Tasktray UI with local admin account."
        write-log ($eventRecord.Properties | Format-List | Out-String)
        Write-Log "Event ID: "
        Write-Log "Event Log Name: $($eventRecord.LogName)"
        Write-Log "Event Message: $($eventRecord.Message)"
    }
}

Write-Log "Creating event query..."
$query = [System.Diagnostics.Eventing.Reader.EventLogQuery]::new($logName, [System.Diagnostics.Eventing.Reader.PathType]::LogName, "*[System[EventID=$eventId or EventID=6667]]")

Write-Log "Creating event watcher..."
$subscription = [System.Diagnostics.Eventing.Reader.EventLogWatcher]::new($query)

Write-Log "Registering event..."
$job = Register-ObjectEvent -InputObject $subscription -EventName EventRecordWritten -Action $action

Write-Log "Enabling watcher..."
$subscription.Enabled = $true

Write-Log "Monitoring $logName for EventID $eventId. Press Ctrl+C to exit."

try {
    while ($true) {
        Start-Sleep -Milliseconds 500
        #Write-Log "$i Watcher state: $($subscription.Enabled)"
        #Read-Host -Prompt "Please enter a key"
    }
}
finally {
    Write-Log "Cleaning up..."
    $subscription.Dispose()
    Unregister-Event -SourceIdentifier $job.Name
    Remove-Job -Job $job -Force
}