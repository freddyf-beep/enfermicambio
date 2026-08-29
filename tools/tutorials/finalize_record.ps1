param(
    [string]$Tmp,
    [string]$Dest
)

if (-not $Tmp) { throw 'Falta -Tmp (archivo temporal de scrcpy)' }
if (-not $Dest) { throw 'Falta -Dest (ruta destino final)' }

$destFull = [System.IO.Path]::GetFullPath($Dest)
$destDir = Split-Path -Parent $destFull
if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

if (Test-Path -LiteralPath $destFull) {
    Remove-Item -LiteralPath $destFull -Force
}

if (-not (Test-Path -LiteralPath $Tmp)) {
    throw "El archivo temporal no existe: $Tmp"
}

Move-Item -LiteralPath $Tmp -Destination $destFull -Force
Write-Output ("FINALIZADO en " + $destFull + " (" + (Get-Item $destFull).Length + " bytes)")
