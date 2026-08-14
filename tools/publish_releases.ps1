param(
  [string]$SourceDirectory = 'C:\Users\fredd\Desktop\EnfermiCambio-downloads',
  [string]$RemoteHost = 'udefret@100.77.234.112',
  [string]$RemoteDirectory = '/home/udefret/server-dashboard/public/enfermicambio/releases',
  [string]$PublicBaseUrl = 'https://invisible-tiffany-improvements-compound.trycloudflare.com',
  [string]$SshKey = 'C:\Users\fredd\.ssh\enfermicambio_release_sync'
)

$ErrorActionPreference = 'Stop'
$stateDirectory = Join-Path $env:LOCALAPPDATA 'EnfermiCambio'
$statePath = Join-Path $stateDirectory 'release-publisher-state.json'

function Invoke-ScpUpload {
  param(
    [Parameter(Mandatory = $true)][string]$LocalPath,
    [Parameter(Mandatory = $true)][string]$RemotePath
  )

  $arguments = @(
    '-q',
    '-i', $SshKey,
    '-o', 'IdentitiesOnly=yes',
    '-o', 'BatchMode=yes',
    '-o', 'ConnectTimeout=15',
    $LocalPath,
    "$RemoteHost`:$RemotePath"
  )
  & scp @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "No se pudo subir $LocalPath al servidor Ubuntu."
  }
}

function Wait-FileStable {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

  for ($attempt = 0; $attempt -lt 6; $attempt++) {
    $first = (Get-Item -LiteralPath $File.FullName).Length
    Start-Sleep -Milliseconds 500
    $second = (Get-Item -LiteralPath $File.FullName).Length
    if ($first -eq $second) { return }
  }
  throw "El archivo todavía está cambiando: $($File.Name)"
}

function Get-ReleaseRecord {
  param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)

  $match = [regex]::Match(
    $File.BaseName,
    'EnfermiCambio-(?<version>\d+\.\d+\.\d+)-build(?<build>\d+)',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  )
  if (-not $match.Success) { return $null }

  $platform = switch ($File.Extension.ToLowerInvariant()) {
    '.apk' { 'android' }
    '.ipa' { 'ios' }
    default { return $null }
  }
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName).Hash
  [pscustomobject]@{
    platform = $platform
    version = $match.Groups['version'].Value
    build = [int]$match.Groups['build'].Value
    fileName = $File.Name
    localPath = $File.FullName
    sha256 = $hash
  }
}

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
  throw "No existe la carpeta de publicación: $SourceDirectory"
}
if (-not (Test-Path -LiteralPath $SshKey -PathType Leaf)) {
  throw "No existe la clave SSH de publicación: $SshKey"
}

New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$state = if (Test-Path -LiteralPath $statePath) {
  try { Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json } catch { [pscustomobject]@{} }
} else {
  [pscustomobject]@{}
}

$files = Get-ChildItem -LiteralPath $SourceDirectory -File |
  Where-Object { $_.Extension -in '.apk', '.ipa' }
$records = @()
$nextState = [ordered]@{}

foreach ($file in $files) {
  $record = Get-ReleaseRecord -File $file
  if ($null -eq $record) {
    Write-Warning "Se omite $($file.Name): el nombre debe incluir versión y build."
    continue
  }

  $previous = $null
  if ($state.PSObject.Properties.Name -contains $record.fileName) {
    $previous = $state.($record.fileName)
  }
  if ($null -eq $previous -or $previous.sha256 -ne $record.sha256) {
    Wait-FileStable -File $file
    Invoke-ScpUpload -LocalPath $record.localPath -RemotePath "$RemoteDirectory/$($record.fileName)"
    Write-Output "Subido: $($record.fileName)"
  }
  $nextState[$record.fileName] = [ordered]@{ sha256 = $record.sha256 }
  $records += $record
}

if ($records.Count -eq 0) {
  throw 'No hay APK o IPA con nombre de versión válido para publicar.'
}

function Select-Latest([object[]]$Items) {
  $Items |
    Sort-Object `
      @{ Expression = { [version]$_.version }; Descending = $true }, `
      @{ Expression = { [int]$_.build }; Descending = $true } |
    Select-Object -First 1
}

$platformManifest = [ordered]@{}
foreach ($platform in 'android', 'ios') {
  $latest = Select-Latest ($records | Where-Object platform -eq $platform)
  if ($null -eq $latest) { continue }
  $relativePath = "/enfermicambio/releases/$([uri]::EscapeDataString($latest.fileName))"
  $platformManifest[$platform] = [ordered]@{
    version = $latest.version
    build = $latest.build
    fileName = $latest.fileName
    downloadUrl = "$($PublicBaseUrl.TrimEnd('/'))$relativePath"
    sha256 = $latest.sha256
  }
}

$manifest = [ordered]@{
  schema = 1
  app = 'EnfermiCambio'
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  platforms = $platformManifest
}
$manifestPath = Join-Path $env:TEMP "enfermicambio-latest-$([guid]::NewGuid().ToString('N')).json"
[System.IO.File]::WriteAllText(
  $manifestPath,
  ($manifest | ConvertTo-Json -Depth 8),
  [System.Text.UTF8Encoding]::new($false)
)
try {
  Invoke-ScpUpload -LocalPath $manifestPath -RemotePath "$RemoteDirectory/latest.json"
} finally {
  Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
}

($nextState | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $statePath -Encoding UTF8
Write-Output "Manifest actualizado: $($PublicBaseUrl.TrimEnd('/'))/enfermicambio/releases/latest.json"
