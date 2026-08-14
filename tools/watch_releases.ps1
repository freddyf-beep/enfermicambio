param(
  [string]$SourceDirectory = 'C:\Users\fredd\Desktop\EnfermiCambio-downloads',
  [string]$RemoteHost = 'udefret@100.77.234.112',
  [string]$RemoteDirectory = '/home/udefret/server-dashboard/public/enfermicambio/releases',
  [string]$PublicBaseUrl = 'https://invisible-tiffany-improvements-compound.trycloudflare.com',
  [string]$SshKey = 'C:\Users\fredd\.ssh\enfermicambio_release_sync'
)

$ErrorActionPreference = 'Continue'
$publisher = Join-Path $PSScriptRoot 'publish_releases.ps1'

function Publish-Now {
  & $publisher `
    -SourceDirectory $SourceDirectory `
    -RemoteHost $RemoteHost `
    -RemoteDirectory $RemoteDirectory `
    -PublicBaseUrl $PublicBaseUrl `
    -SshKey $SshKey
}

Publish-Now

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDirectory
$watcher.Filter = '*.*'
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true
$sources = @(
  (Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier 'EnfermiCambioReleaseCreated'),
  (Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier 'EnfermiCambioReleaseChanged'),
  (Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier 'EnfermiCambioReleaseRenamed')
)

$pending = $false
$lastChange = Get-Date
try {
  while ($true) {
    $event = Wait-Event -Timeout 5
    if ($null -ne $event) {
      Remove-Event -EventIdentifier $event.EventIdentifier -ErrorAction SilentlyContinue
      $pending = $true
      $lastChange = Get-Date
    }
    if ($pending -and ((Get-Date) - $lastChange).TotalSeconds -ge 3) {
      Publish-Now
      $pending = $false
    }
  }
} finally {
  foreach ($source in $sources) {
    Unregister-Event -SourceIdentifier $source.Name -ErrorAction SilentlyContinue
  }
  $watcher.Dispose()
}
