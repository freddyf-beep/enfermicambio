Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$publicDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\public'))
$logoDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\assets\logos'))
$variants = @{
  pulse = @{ Source = 'logo-default.png'; Background = '#0A96C5' }
  ember = @{ Source = 'logo-red-transparent.png'; Background = '#0A84FF' }
  ocean = @{ Source = 'logo-medical-cropped.png'; Background = '#12AFC0' }
  night = @{ Source = 'logo-red-cropped.png'; Background = '#087DAF' }
}

function Write-HeritageIcon([string]$source, [int]$size, [string]$background, [string]$destination) {
  $image = [System.Drawing.Image]::FromFile($source)
  try {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
      $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml($background))
      $ratio = [Math]::Min($size / $image.Width, $size / $image.Height)
      $width = [int][Math]::Round($image.Width * $ratio)
      $height = [int][Math]::Round($image.Height * $ratio)
      $x = [int][Math]::Floor(($size - $width) / 2)
      $y = [int][Math]::Floor(($size - $height) / 2)
      $graphics.DrawImage($image, $x, $y, $width, $height)
      $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $graphics.Dispose()
      $bitmap.Dispose()
    }
  } finally {
    $image.Dispose()
  }
}

foreach ($entry in $variants.GetEnumerator()) {
  $source = Join-Path $logoDir $entry.Value.Source
  if (-not (Test-Path -LiteralPath $source)) { throw "Missing historical logo: $source" }
  foreach ($size in @(180, 192, 512)) {
    $file = Join-Path $publicDir ("icon-{0}-{1}.png" -f $entry.Key, $size)
    Write-HeritageIcon $source $size $entry.Value.Background $file
  }
}

Copy-Item -LiteralPath (Join-Path $publicDir 'icon-pulse-180.png') -Destination (Join-Path $publicDir 'icon-180.png') -Force
Copy-Item -LiteralPath (Join-Path $publicDir 'icon-pulse-192.png') -Destination (Join-Path $publicDir 'icon-192.png') -Force
Copy-Item -LiteralPath (Join-Path $publicDir 'icon-pulse-512.png') -Destination (Join-Path $publicDir 'icon-512.png') -Force
