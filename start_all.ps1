param(
    [switch]$SkipPostgres,
    [switch]$SkipSqlServer,
    [switch]$NoWebApp,
    [switch]$Status,
    [switch]$Stop,
    [switch]$Background
)

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pgDir = Join-Path $rootDir "Postgres_HA_docker"
$sqlDir = Join-Path $rootDir "SQL_Server_HA_Docker"
$webDir = Join-Path $rootDir "web_app"

function Write-Color($text, $color) {
    Write-Host $text -ForegroundColor $color
}

# ── Resource Advisor ─────────────────────────────────────────────
function Get-ResourceSettings {
    $pyScript = Join-Path $webDir "resource_advisor.py"
    if ((Test-Path $pyScript) -and (Get-Command python -ErrorAction SilentlyContinue)) {
        try {
            $json = & python $pyScript 2>$null
            if ($json) { return $json | ConvertFrom-Json }
        } catch { }
    }
    # Fallback: detect via WMI
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    } catch {
        $ramGB = 8.0
    }
    return Get-FallbackSettings $ramGB
}

function Get-FallbackSettings($ramGB) {
    if ($ramGB -ge 32) { $scale = 1.0 }
    elseif ($ramGB -ge 16) { $scale = 0.5 }
    elseif ($ramGB -ge 8) { $scale = 0.35 }
    else { $scale = 0.25 }

    return [PSCustomObject]@{
        total_ram_gb           = $ramGB
        scale                  = $scale
        pg_patroni_mem         = "$([Math]::Max([Math]::Round(2 * $scale, 1), 0.5))g"
        pg_etcd_mem            = "$([Math]::Max([int](256 * $scale), 128))m"
        pg_haproxy_mem         = "$([Math]::Max([int](128 * $scale), 64))m"
        pg_backup_mem          = "$([Math]::Max([int](512 * $scale), 256))m"
        pg_seaweed_mem         = "$([Math]::Max([int](512 * $scale), 256))m"
        sql_node_mem           = "$([Math]::Max([Math]::Round(6 * $scale, 1), 2))g"
        sql_node3_mem          = "$([Math]::Max([Math]::Round(4 * $scale, 1), 2))g"
        pg_shared_buffers      = "$([Math]::Max([int](512 * $scale), 64))MB"
        pg_effective_cache_size = "$([Math]::Max([int](1536 * $scale), 192))MB"
    }
}

function Show-ResourcePlan($s) {
    Write-Color "  System: $($s.total_ram_gb) GB RAM | Scale: $($s.scale)" Gray
    Write-Color "  PostgreSQL: $($s.pg_patroni_mem)/node, shared_buffers=$($s.pg_shared_buffers), effective_cache=$($s.pg_effective_cache_size)" Gray
    Write-Color "  SQL Server: $($s.sql_node_mem)/node (sql1,sql2), $($s.sql_node3_mem) (sql3)" Gray
}

function Generate-PgOverride($s) {
    $path = Join-Path $pgDir "docker-compose.override.yml"
@"
services:
  patroni1:
    mem_limit: $($s.pg_patroni_mem)
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: $($s.pg_shared_buffers)
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: $($s.pg_effective_cache_size)
  patroni2:
    mem_limit: $($s.pg_patroni_mem)
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: $($s.pg_shared_buffers)
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: $($s.pg_effective_cache_size)
  patroni3:
    mem_limit: $($s.pg_patroni_mem)
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: $($s.pg_shared_buffers)
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: $($s.pg_effective_cache_size)
  etcd:
    mem_limit: $($s.pg_etcd_mem)
  haproxy:
    mem_limit: $($s.pg_haproxy_mem)
  pg_backup:
    mem_limit: $($s.pg_backup_mem)
  seaweedfs:
    mem_limit: $($s.pg_seaweed_mem)
"@ | Out-File -FilePath $path -Encoding ASCII
    Write-Color "  [+] Generated PG override: $path" Green
}

function Generate-SqlOverride($s) {
    $path = Join-Path $sqlDir "docker-compose.override.yml"
@"
services:
  sql1:
    mem_limit: $($s.sql_node_mem)
  sql2:
    mem_limit: $($s.sql_node_mem)
  sql3:
    mem_limit: $($s.sql_node3_mem)
"@ | Out-File -FilePath $path -Encoding ASCII
    Write-Color "  [+] Generated SQL override: $path" Green
}

function Remove-OverrideFiles {
    $pgOverride = Join-Path $pgDir "docker-compose.override.yml"
    $sqlOverride = Join-Path $sqlDir "docker-compose.override.yml"
    if (Test-Path $pgOverride) { Remove-Item $pgOverride -Force; Write-Color "  Removed PG override" Gray }
    if (Test-Path $sqlOverride) { Remove-Item $sqlOverride -Force; Write-Color "  Removed SQL override" Gray }
}

# ── Engine Choice Prompt ────────────────────────────────────────
function Prompt-EngineChoice {
    Write-Color "`n=== Engine Selection ===" Cyan
    Write-Color "  Which database engine(s) would you like to start?" White
    Write-Color "    [1] Both PostgreSQL and SQL Server (recommended)" White
    Write-Color "    [2] PostgreSQL only" White
    Write-Color "    [3] SQL Server only" White
    Write-Color "    [4] Exit`n" White

    $choice = Read-Host "  Enter choice (1-4)"
    switch ($choice) {
        '1' { return @($false, $false, "all") }
        '2' { return @($true, $false,  "postgres") }
        '3' { return @($false, $true,  "sqlserver") }
        '4' { Write-Color "  Exiting." Gray; exit 0 }
        default { Write-Color "  [!] Invalid choice. Please enter 1-4.`n" Red; return Prompt-EngineChoice }
    }
}

# ── Web app (Docker) ────────────────────────────────────────────
function Get-WebComposeArgs {
    $files = @("-f", (Join-Path $webDir "docker-compose.yml"))
    docker volume inspect sqloptima_wal_archive 2>$null | Out-Null
    if ((-not $SkipPostgres) -and ($LASTEXITCODE -eq 0)) {
        $files += @("-f", (Join-Path $webDir "docker-compose.pg.yml"))
    }
    return $files
}

function Start-WebApp {
    param([string]$ActiveEnvs = "all")
    $env:ACTIVE_ENVS = $ActiveEnvs
    Write-Color "  Building and starting web app container..." Gray
    $files = Get-WebComposeArgs
    docker compose @files up -d --build
    Start-Sleep -Seconds 2
    $running = docker ps --format "{{.Names}}" | Select-String -Pattern "^sqloptima_web$"
    if ($running) {
        Write-Color "  [+] Web app starting on http://localhost:5002 (container: sqloptima_web)" Green
    } else {
        Write-Color "  [!] Web app container failed to start. Check: docker logs sqloptima_web" Red
    }
}

function Stop-WebApp {
    docker compose -f (Join-Path $webDir "docker-compose.yml") down 2>$null | Out-Null
    docker rm -f sqloptima_web 2>$null | Out-Null
    Write-Color "  [+] Web app stopped" Green
}

function Show-Status {
    Write-Color "=== Status ===" Cyan
    foreach ($pair in @(@("PostgreSQL HA", $pgDir), @("SQL Server HA", $sqlDir))) {
        $name = $pair[0]; $dir = $pair[1]
        Write-Color "  $($name):" White
        Push-Location $dir
        docker compose ps 2>$null | Select-Object -Skip 1 | ForEach-Object { Write-Color "    $_" Gray }
        Pop-Location
    }
    Write-Color "  Web App:" White
    docker compose -f (Join-Path $webDir "docker-compose.yml") ps 2>$null | Select-Object -Skip 1 | ForEach-Object { Write-Color "    $_" Gray }
}

function Stop-All {
    Write-Color "`n=== Stopping All Servers ===" Cyan
    Stop-WebApp
    Write-Color "  Stopping PostgreSQL HA..." Gray
    Push-Location $pgDir; docker compose down 2>$null; Pop-Location
    Write-Color "  Stopping SQL Server HA..." Gray
    Push-Location $sqlDir; docker compose down 2>$null; Pop-Location
    Remove-OverrideFiles
    Write-Color "`n[+] All servers stopped" Green
}

# ── Main ────────────────────────────────────────────────────────
if ($Status) { Show-Status; return }
if ($Stop) { Stop-All; return }

# ── Engine Selection ─────────────────────────────────────────────
$hasFlags = $SkipPostgres -or $SkipSqlServer
$activeEnvs = "all"
if (-not $hasFlags) {
    $result = Prompt-EngineChoice
    $SkipPostgres = $result[1]
    $SkipSqlServer = $result[0]
    $activeEnvs = $result[2]
} elseif ($SkipPostgres -and -not $SkipSqlServer) {
    $activeEnvs = "sqlserver"
} elseif ($SkipSqlServer -and -not $SkipPostgres) {
    $activeEnvs = "postgres"
}

# ── Resource Detection & Override Generation ─────────────────────
Write-Color "`n=== Resource Detection ===" Cyan
$settings = Get-ResourceSettings
Show-ResourcePlan $settings

if (-not $SkipPostgres) {
    Generate-PgOverride $settings
}
if (-not $SkipSqlServer) {
    Generate-SqlOverride $settings
}
Write-Host ""

# ── Start Servers ────────────────────────────────────────────────
docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Color "  [!] Docker is not running." Red; exit 1 }

if (-not $SkipPostgres) {
    Write-Color "[1/3] Starting PostgreSQL HA Cluster (Patroni)..." Yellow
    Push-Location $pgDir; docker compose up -d --build; Pop-Location
    Write-Color "  [+] PostgreSQL HA cluster started`n" Green
}

if (-not $SkipSqlServer) {
    Write-Color "[2/3] Starting SQL Server HA Cluster..." Yellow
    Push-Location $sqlDir; docker compose up -d --build; Pop-Location
    Write-Color "  [+] SQL Server HA cluster started`n" Green
}

Write-Color "[*] Waiting for containers to initialize (60s)..." Yellow
Start-Sleep -Seconds 60

Write-Color "`n============================================" Cyan
Write-Color "  All services started!" Cyan
Write-Color "============================================" Cyan
Write-Color "  Postgres HA:   localhost:5043 (direct), localhost:5000 (HAProxy write)" White
Write-Color "  SQL Server:    localhost:14331 (sql1), 14332 (sql2), 14333 (sql3)" White
Write-Color "  Web App:       http://localhost:5002" White
Write-Color "============================================" Cyan
Write-Host ""

if (-not $NoWebApp) {
    $env:ACTIVE_ENVS = $activeEnvs
    if ($Background) {
        Write-Color "[3/3] Starting CRUD Web App (background mode)..." Yellow
        Start-WebApp -ActiveEnvs $activeEnvs
        Write-Color "  Use .\stop_all.ps1 to stop all services." Gray
        Write-Host ""
    } else {
        Write-Color "[3/3] Starting CRUD Web App (foreground mode)..." Yellow
        Write-Color "  Open http://localhost:5002 in your browser." White
        Write-Color "  Press Ctrl+C to stop the web app (database containers keep running)." Yellow
        Write-Host "---"
        $files = Get-WebComposeArgs
        docker compose @files up --build
        Write-Host ""
        Write-Color "Web app stopped." Yellow
        Write-Color "Containers are still running. To stop them:" Gray
        Write-Color "  .\stop_all.ps1" Gray
    }
}
