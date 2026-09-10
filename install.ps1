# One-line bootstrap for the DB HA Cluster CRUD Load Generator.
#
#   irm https://raw.githubusercontent.com/rsharma155/sqlserver_postgres_ha_cluster/main/install.ps1 | iex
#
# Extra launcher flags (when saved as a file):
#   .\install.ps1 -SkipPostgres
#
# Environment:
#   HA_CLUSTER_HOME  Install directory (default: %USERPROFILE%\sqlserver_postgres_ha_cluster)
#   HA_CLUSTER_REF   Git branch / tag (default: main)
#   HA_CLUSTER_REPO  Git clone URL

# Works both as `irm | iex` (no param block) and as a downloaded script with $args.
$ErrorActionPreference = "Stop"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

$RepoUrl = if ($env:HA_CLUSTER_REPO) { $env:HA_CLUSTER_REPO } else { "https://github.com/rsharma155/sqlserver_postgres_ha_cluster.git" }
$RepoRef = if ($env:HA_CLUSTER_REF) { $env:HA_CLUSTER_REF } else { "main" }
$InstallDir = if ($env:HA_CLUSTER_HOME) { $env:HA_CLUSTER_HOME } else { Join-Path $HOME "sqlserver_postgres_ha_cluster" }
$ZipUrl = "https://github.com/rsharma155/sqlserver_postgres_ha_cluster/archive/refs/heads/$RepoRef.zip"
# tags / commits use a different archive path; also try the generic form
$ZipUrlAlt = "https://github.com/rsharma155/sqlserver_postgres_ha_cluster/archive/$RepoRef.zip"

function Write-Color($text, $color) { Write-Host $text -ForegroundColor $color }

function Test-Cmd($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

Write-Color "=== DB HA Cluster — one-line setup ===" Cyan
Write-Color "  Install dir: $InstallDir" Gray
Write-Color "  Ref:         $RepoRef" Gray
Write-Host ""

if (-not (Test-Cmd "docker")) {
    Write-Color "  [!] Docker is required. Install Docker Desktop, then re-run." Red
    exit 1
}
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Color "  [!] Docker is installed but not running. Start Docker Desktop and re-run." Red
    exit 1
}
Write-Color "  [+] Prerequisites OK (Docker)" Green

function Get-Repo {
    $parent = Split-Path -Parent $InstallDir
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path (Join-Path $InstallDir ".git")) {
        Write-Color "  [~] Existing git checkout found — updating..." Yellow
        if (Test-Cmd "git") {
            Push-Location $InstallDir
            try {
                git fetch --depth 1 origin $RepoRef 2>$null
                git checkout $RepoRef 2>$null
                git pull --ff-only origin $RepoRef 2>$null
            } catch {}
            finally { Pop-Location }
        }
        Write-Color "  [+] Updated $InstallDir" Green
        return
    }

    if (Test-Path (Join-Path $InstallDir "start_all.ps1")) {
        Write-Color "  [~] Directory already exists with launcher scripts — skipping download." Yellow
        return
    }

    if ((Test-Path $InstallDir) -and (Get-ChildItem $InstallDir -Force -ErrorAction SilentlyContinue)) {
        Write-Color "  [!] Directory exists and is not this project: $InstallDir" Red
        Write-Color "  [!] Set `$env:HA_CLUSTER_HOME to another path and retry." Red
        exit 1
    }

    if (Test-Cmd "git") {
        Write-Color "  Cloning $RepoUrl ..." Cyan
        git clone --depth 1 --branch $RepoRef $RepoUrl $InstallDir
        if ($LASTEXITCODE -ne 0) {
            git clone --depth 1 $RepoUrl $InstallDir
        }
        if (-not (Test-Path (Join-Path $InstallDir "start_all.ps1"))) {
            Write-Color "  [!] Clone succeeded but start_all.ps1 is missing." Red
            exit 1
        }
        Write-Color "  [+] Cloned into $InstallDir" Green
        return
    }

    Write-Color "  [~] git not found — downloading source zip..." Yellow
    $tmp = Join-Path $env:TEMP ("ha-cluster-" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zipPath = Join-Path $tmp "src.zip"
    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        Invoke-WebRequest -Uri $ZipUrlAlt -OutFile $zipPath -UseBasicParsing
    }
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    $extracted = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $extracted) {
        Write-Color "  [!] Failed to extract source archive." Red
        exit 1
    }
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path (Join-Path $extracted.FullName "*") -Destination $InstallDir -Recurse -Force
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Color "  [+] Extracted into $InstallDir" Green
}

Get-Repo

$launcher = Join-Path $InstallDir "start_all.ps1"
if (-not (Test-Path $launcher)) {
    Write-Color "  [!] Launcher missing after download: $launcher" Red
    exit 1
}

Write-Host ""
Write-Color "Launching clusters (this may take a few minutes on first run)..." Cyan
Write-Color "Web UI will be at http://localhost:5002" Cyan
Write-Host ""

$forward = @()
if ($args) { $forward = @($args) }
# irm | iex cannot pass script parameters; allow the same skips via env vars
if ($env:HA_CLUSTER_SKIP_POSTGRES -match '^(1|true|yes)$') { $forward += "-SkipPostgres" }
if ($env:HA_CLUSTER_SKIP_SQL -match '^(1|true|yes)$') { $forward += "-SkipSqlServer" }
if ($env:HA_CLUSTER_DETACH -match '^(1|true|yes)$') { $forward += "-Background" }
if ($env:HA_CLUSTER_NO_WEB -match '^(1|true|yes)$') { $forward += "-NoWebApp" }
& $launcher @forward
