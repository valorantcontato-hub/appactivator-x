# Auto-generated download repair
$Host.UI.RawUI.WindowTitle = "Correcao de download"
$apiBase = "https://revenda.shadowkeys.com.br"
$authApiBase = "https://revenda.shadowkeys.com.br"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


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


function Get-ManifestStateDir([string]$SteamRoot) {
  $dir = Join-Path $SteamRoot 'opensteamtool\manifest-state'
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
  }
  return $dir
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

function Get-SteamRootOrFail {
  $steamRoot = Get-SteamPathFromRegistry
  if ($steamRoot -and (Test-SteamFsPath $steamRoot)) { return $steamRoot }
  throw "Nao foi possivel localizar a pasta da Steam."
}

function Get-SkApiHeaders {
  return @{
    Accept = 'application/json'
    'User-Agent' = 'sk-ost/1.0'
    'X-SK-Version' = 'sk-ost'
  }
}

function Get-HubcapDownloadHeaders {
  return @{
    Accept = 'application/zip, application/octet-stream, */*'
    'User-Agent' = 'shadow-keys-client'
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
  try {
    return Invoke-RestMethod @params
  } catch {
    $message = $_.Exception.Message
    $response = $null
    try { $response = $_.Exception.Response } catch {}
    if ($response) {
      $statusCode = 0
      try { $statusCode = [int]$response.StatusCode } catch {}
      $raw = ''
      try {
        $stream = $response.GetResponseStream()
        if ($stream) {
          $reader = New-Object System.IO.StreamReader($stream)
          $raw = [string]$reader.ReadToEnd()
          $reader.Close()
        }
      } catch {}
      if ($raw.TrimStart().StartsWith('{') -or $raw.TrimStart().StartsWith('[')) {
        try {
          $parsed = $raw | ConvertFrom-Json
          if ($parsed.code -eq 'NO_ACTIVATION') {
            throw "Este jogo nao esta ativo nesta conta Steam."
          }
          if ($parsed.message) { throw [string]$parsed.message }
        } catch {
          if ($_.Exception.Message -ne $message) { throw $_.Exception.Message }
        }
      }
      if ($statusCode -eq 404) { throw '__SK_HTTP_404__' }
      if ($statusCode -eq 429 -or $statusCode -eq 503) {
        throw "O limite diario acabou, avise o suporte"
      }
    }
    if ($message -match '\(404\)|404|Not Found') { throw '__SK_HTTP_404__' }
    if ($message -match '\(429\)|\(503\)') {
      throw "O limite diario acabou, avise o suporte"
    }
    throw $message
  }
}

function Test-ZipArchive([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  try {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 4) { return $false }
    return ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04)
  } catch {
    return $false
  }
}

function Download-ManifestArchive {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [hashtable]$Headers = @{ }
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
    $statusCode = 0
    try { $statusCode = [int]$resp.StatusCode } catch {}
    if ($statusCode -eq 429 -or $statusCode -eq 503) {
      $resp.Close()
      throw "O limite diario acabou, avise o suporte"
    }
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
    return ((Test-Path -LiteralPath $OutFile) -and (Test-ZipArchive $OutFile))
  } catch {
    $detail = $_.Exception.Message
    try {
      $ex = $_.Exception
      if ($ex.InnerException) { $ex = $ex.InnerException }
      if ($ex -is [System.Net.WebException] -and $ex.Response) {
        $http = [System.Net.HttpWebResponse]$ex.Response
        $code = [int]$http.StatusCode
        if ($code -eq 429 -or $code -eq 503) {
          throw "O limite diario acabou, avise o suporte"
        }
        $reader = New-Object System.IO.StreamReader($http.GetResponseStream())
        $raw = [string]$reader.ReadToEnd()
        $reader.Close()
        if ($raw.TrimStart().StartsWith('{')) {
          $parsed = $raw | ConvertFrom-Json
          if ($parsed.message -match 'limite|429|quota|indispon') {
            throw "O limite diario acabou, avise o suporte"
          }
          if ($parsed.message) { throw [string]$parsed.message }
        }
      }
    } catch {
      if ($_.Exception.Message -and $_.Exception.Message -ne $detail) {
        throw $_.Exception.Message
      }
    }
    if ($detail -match '429|503|limite diario|Limite') {
      throw "O limite diario acabou, avise o suporte"
  }
  return $false
}
}

function Get-RedeemedGames {
  param([Parameter(Mandatory = $true)][string]$SteamId)
  if (-not $authApiBase) {
    throw "Servico indisponivel no momento."
  }
  $url = $authApiBase.TrimEnd('/') + '/api/steam-keys/reactivate'
  $body = @{ steamId = $SteamId } | ConvertTo-Json -Compress
  $response = Invoke-SkApiJson -Url $url -Method POST -Body $body
  return @($response.games)
}

function Sort-RedeemedGames {
  param([Parameter(Mandatory = $true)][array]$Games)
  return @(
    $Games |
      Sort-Object @{ Expression = { ([string]$_.name).ToLowerInvariant() } }, @{ Expression = { [string]$_.appId } }
  )
}

function Resolve-RedeemedSelection {
  param(
    [Parameter(Mandatory = $true)][array]$Games,
    [Parameter(Mandatory = $true)][string]$InputValue
  )
  $trimmed = [string]$InputValue
  if ($trimmed -match '^\d+$') {
    foreach ($game in $Games) {
      if ([string]$game.appId -eq $trimmed) { return $game }
    }
    return $null
  }
  return $null
}

function New-HubcapPackageInfo {
  param([Parameter(Mandatory = $true)][string]$AppId)
  return [pscustomobject]@{
    appId = $AppId
    manifestUrl = ($apiBase.TrimEnd('/') + '/api/manifest/hubcap/' + $AppId + '.zip')
    manifestHeaders = (Get-HubcapDownloadHeaders)
    error = $null
  }
}

function Request-ManifestPackage {
  param(
    [Parameter(Mandatory = $true)][string]$SteamId,
    [Parameter(Mandatory = $true)][string]$AppId
  )
  if (-not $authApiBase) {
    throw "Servico indisponivel no momento."
  }
  $url = $authApiBase.TrimEnd('/') + '/api/steam-keys/internet-repair'
  $body = @{ steamId = $SteamId; appId = $AppId } | ConvertTo-Json -Compress
  try {
    $response = Invoke-SkApiJson -Url $url -Method POST -Body $body
    if (-not $response -or -not $response.game) {
      throw "Nao foi possivel obter os arquivos do jogo."
    }
    return $response.game
  } catch {
    if ([string]$_.Exception.Message -eq '__SK_HTTP_404__') {
      return New-HubcapPackageInfo -AppId $AppId
    }
    throw
  }
}

function Download-AuthorizedGamePackage {
  param(
    [Parameter(Mandatory = $true)][string]$SteamId,
    [Parameter(Mandatory = $true)][string]$AppId,
    [Parameter(Mandatory = $true)][string]$OutFile
  )
  $game = Request-ManifestPackage -SteamId $SteamId -AppId $AppId
  $manifestUrl = [string]$game.manifestUrl
  if (-not $manifestUrl) {
    $detail = [string]$game.error
    if ($detail -match '429|limite|quota|indispon') {
      throw "O limite diario acabou, avise o suporte"
    }
    if ($detail) { throw $detail }
    throw "Manifest não encontrado nesta fonte."
  }
  $headers = @{}
  if ($game.manifestHeaders) {
    foreach ($prop in $game.manifestHeaders.PSObject.Properties) {
      $headers[$prop.Name] = [string]$prop.Value
    }
  }
  if (-not $headers['User-Agent']) {
    $headers['User-Agent'] = (Get-HubcapDownloadHeaders)['User-Agent']
  }
  if (-not $headers['Accept']) {
    $headers['Accept'] = (Get-HubcapDownloadHeaders)['Accept']
  }
  if (-not (Download-ManifestArchive -Url $manifestUrl -OutFile $OutFile -Headers $headers)) {
    throw "Nao foi possivel baixar os arquivos do jogo."
  }
  $zipBytes = 0
  try { $zipBytes = [int64](Get-Item -LiteralPath $OutFile).Length } catch {}
  if ($zipBytes -lt 10000) {
    throw "Pacote invalido para este AppID."
  }
  return $true
}

function Repair-SelectedGame {
  param(
    [Parameter(Mandatory = $true)][string]$SteamRoot,
    [Parameter(Mandatory = $true)][string]$SteamId,
    [Parameter(Mandatory = $true)]$SelectedGame
  )
  $appId = [string]$SelectedGame.appId
  $gameName = [string]$SelectedGame.name
  if (-not $gameName) { $gameName = $appId }

  $zipPath = Join-Path $env:TEMP ("sk-repair-" + $appId + "-" + [guid]::NewGuid().ToString('N') + ".zip")
  try {
    if (-not (Download-AuthorizedGamePackage -SteamId $steamId -AppId $appId -OutFile $zipPath)) {
      throw "Nao foi possivel baixar os arquivos do jogo."
    }
    if (-not (Test-ZipArchive $zipPath)) {
      throw "Pacote invalido para este AppID."
    }

    $depotIds = @(Get-HubcapZipManifestDepotIds -ArchivePath $zipPath)
    Clear-SteamAppHubcapState -SteamRoot $steamRoot -AppId $appId -DepotIds $depotIds | Out-Null

    $install = Install-HubcapZipFromArchive -SteamRoot $steamRoot -AppId $appId -ArchivePath $zipPath
    if (-not $install.LuaInstalled) {
      $installError = [string]$install.Error
      if ($installError) { throw $installError }
      throw "Pacote invalido para este AppID."
    }
    $luaPath = Join-Path $steamRoot ("config\lua\{0}.lua" -f $appId)
    $luaText = ""
    if (Test-Path -LiteralPath $luaPath) {
      $luaText = [System.IO.File]::ReadAllText($luaPath)
    }
    if ($install.ManifestCount -le 0 -or -not (Test-LuaHasManifestPins $luaText)) {
      throw "Pacote incompleto para este jogo. Avise o suporte para atualizar os manifests."
    }
    if ($SelectedGame.manifestVersion -ne $null) {
      $syncVersion = [int64]$SelectedGame.manifestVersion
      if ($syncVersion -gt 0) {
        Set-LocalManifestVersion -SteamRoot $steamRoot -AppId $appId -Version $syncVersion | Out-Null
      }
    }
  } finally {
    if (Test-Path -LiteralPath $zipPath) {
      Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
    }
  }
}

function Test-LuaHasManifestPins([string]$LuaText) {
  if (-not $LuaText) { return $false }
  return [bool]([regex]::Match($LuaText, '(?m)^\s*setManifestid\s*\(').Success)
}

# ================= Entry point nao-interativo =================
# Uso: script2-correcao-download.ps1 -AppId <appid>
param([string]$AppId = "")

try {
  $steamRoot = Get-SteamRootOrFail
  $steamId = Get-SteamId64 $steamRoot
  if (-not $steamId) {
    throw "Nao foi possivel identificar a conta Steam logada."
  }

  $targetAppId = $AppId
  if (-not $targetAppId) {
    $redeemedGames = @(Sort-RedeemedGames -Games @(Get-RedeemedGames -SteamId $steamId))
    if ($redeemedGames.Count -le 0) {
      throw "Nenhum jogo resgatado nesta conta Steam. Resgate uma key primeiro."
    }
    $targetAppId = [string]$redeemedGames[0].appId
  }

  $redeemed = @(Get-RedeemedGames -SteamId $steamId)
  $selectedGame = Resolve-RedeemedSelection -Games $redeemed -InputValue $targetAppId
  if (-not $selectedGame) {
    throw "Este jogo nao esta resgatado nesta conta Steam."
  }

  Repair-SelectedGame -SteamRoot $steamRoot -SteamId $steamId -SelectedGame $selectedGame
  exit 0
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
