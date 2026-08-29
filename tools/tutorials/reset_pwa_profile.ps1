$ErrorActionPreference = 'Stop'

# Ruta fija y verificada, dentro del perfil del usuario (no workspace), no generada en runtime.
$target = Join-Path $env:USERPROFILE '.enfermicambio-pwa-profile'
$target = [System.IO.Path]::GetFullPath($target)
$base = [System.IO.Path]::GetFullPath($env:USERPROFILE)

# Solo borrar si está dentro del home del usuario (verificación de seguridad).
if (-not $target.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Ruta fuera de rango: $target"
}

if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
    Write-Output "Perfil $target borrado"
} else {
    Write-Output "Perfil $target no existe"
}
