$ErrorActionPreference = 'Stop'
$watcher = Join-Path $PSScriptRoot 'watch_releases.ps1'
$taskName = 'EnfermiCambio Release Publisher'
$arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $watcher
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
  -ExecutionTimeLimit (New-TimeSpan -Days 3650) `
  -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1) `
  -MultipleInstances IgnoreNew
Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -User $env:USERNAME `
  -RunLevel Limited `
  -Force | Out-Null
Write-Output "Tarea instalada: $taskName"
