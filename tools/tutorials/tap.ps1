param(
  [Parameter(ParameterSetName='XY', Mandatory=$true)]
  [int]$X,
  [Parameter(ParameterSetName='XY', Mandatory=$true)]
  [int]$Y,
  [Parameter(ParameterSetName='Text', Mandatory=$true)]
  [string]$Text,
  [double]$SlowMs = 0.8
)

$ErrorActionPreference = 'SilentlyContinue'
$adb = 'C:\Users\fredd\AppData\Local\Android\Sdk\platform-tools\adb.exe'

$ui = '/sdcard/ui.xml'

function Get-Dump {
  & $adb -s emulator-5554 shell uiautomator dump $ui 2>$null | Out-Null
  return (& $adb -s emulator-5554 shell cat $ui 2>$null | Out-String)
}

function Find-Center([string]$xml, [string]$needle, [string]$attr) {
  # Busca un nodo cuyo attribute contenga needle y extrae bounds.
  # Se construye el patron con comillas dobles literales (no escapadas).
  $attrVal = [regex]::Escape($attr)
  $dq = [char]34
  $pat = $attrVal + $dq + '[^' + $dq + ']*' + $needle + '[^' + $dq + ']*' + $dq + '[^>]*bounds=' + $dq + '\[(\d+),(\d+)\]\[(\d+),(\d+)\]' + $dq
  $m = [regex]::Match($xml, $pat)
  if (-not $m.Success) { return $null }
  $x1=[int]$m.Groups[1].Value; $y1=[int]$m.Groups[2].Value
  $x2=[int]$m.Groups[3].Value; $y2=[int]$m.Groups[4].Value
  return ,@([int](($x1+$x2)/2), [int](($y1+$y2)/2))
}

if ($PSCmdlet.ParameterSetName -eq 'XY') {
  & $adb -s emulator-5554 shell input tap $X $Y 2>$null
  Write-Output ("tap xy -> (" + $X + "," + $Y + ")")
} else {
  $xml = Get-Dump
  if (-not $xml) { Write-Output 'NO_UI_DUMP'; exit 1 }
  $needle = [regex]::Escape($Text)
  $center = Find-Center $xml $needle 'text'
  if (-not $center) { $center = Find-Center $xml $needle 'content-desc' }
  if (-not $center) {
    Write-Output ("NO_MATCH: " + $Text)
    exit 2
  }
  & $adb -s emulator-5554 shell input tap $center[0] $center[1] 2>$null
  Write-Output ("tap " + $Text + " -> (" + $center[0] + "," + $center[1] + ")")
}

Start-Sleep -Milliseconds ([int]($SlowMs * 1000))
