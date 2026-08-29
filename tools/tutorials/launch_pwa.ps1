$ErrorActionPreference = 'Stop'

$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
# Perfil sin espacios para evitar problemas de escaping al pasar argumentos.
$profile = "$env:USERPROFILE\.enfermicambio-pwa-profile"
$url = 'https://enfermicambio-98b5a.web.app/'

if (-not (Test-Path -LiteralPath $chrome)) {
    throw "No se encontró Chrome en $chrome"
}

# Crea el perfil dedicado si no existe.
if (-not (Test-Path -LiteralPath $profile)) {
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
}

# Lanza Chrome en modo app (PWA) con tamaño móvil y título identificable.
# --app crea una ventana standalone sin toolbar, ideal para capturar la PWA.
$args = @(
    "--user-data-dir=$profile"
    '--new-window'
    '--window-size=430,860'
    "--app=$url"
)

Start-Process -FilePath $chrome -ArgumentList $args

Write-Output "Chrome lanzado apuntando a $url"
