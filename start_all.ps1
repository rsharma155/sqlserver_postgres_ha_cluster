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
    if (Test-Path $pyScript) {
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
    elseif ($ramGB -ge 8) { $scale = 0.30 }
    else { $scale = 0.15 }

    return [PSCustomObject]@{
        total_ram_gb           = $ramGB
        scale                  = $scale
        pg_patroni_mem         = "$([Math]::Max([Math]::Round(2 * $scale, 1), 0.5))g"
        pg_etcd_mem            = "$([Math]::Max([int](256 * $scale), 128))m"
        pg_haproxy_mem         = "$([Math]::Max([int](128 * $scale), 64))m"
        pg_backup_mem          = "$([Math]::Max([int](512 * $scale), 256))m"
        pg_seaweed_mem         = "$([Math]::Max([int](512 * $scale), 256))m"
        sql_node_mem           = "$([Math]::Max([Math]::Round(6 * $scale, 1), 1))g"
        sql_node3_mem          = "$([Math]::Max([Math]::Round(4 * $scale, 1), 1))g"
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

# ── ODBC Driver check & auto-install (Windows) ─────────────────
function Ensure-OdbcDriver {
    Write-Color "  Checking SQL Server ODBC driver..." Cyan
    $drivers = @()
    try {
        $regPath = "HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers"
        $drivers = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name }
    } catch {}

    foreach ($candidate in @("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
                             "ODBC Driver 13.1 for SQL Server", "ODBC Driver 13 for SQL Server",
                             "ODBC Driver 11 for SQL Server")) {
        if ($drivers -contains $candidate) {
            Write-Color "  [+] SQL Server ODBC driver found: $candidate" Green
            return $true
        }
    }
    try {
        $pyCheck = & python -c "import pyodbc; print([d for d in pyodbc.drivers() if 'SQL Server' in d or 'FreeTDS' in d])" 2>&1
        if ($pyCheck -match "SQL Server|FreeTDS") {
            Write-Color "  [+] SQL Server ODBC driver found (via pyodbc): $pyCheck" Green
            return $true
        }
    } catch {}

    Write-Color "  [~] SQL Server ODBC driver not found. Attempting auto-install..." Yellow
    try {
        $wingetCheck = winget list Microsoft.ODBCDriver18 --accept-source-agreements 2>&1
        if ($wingetCheck -match "Microsoft.ODBCDriver18") {
            Write-Color "  [+] ODBC Driver 18 already installed (winget)" Green
            return $true
        }
    } catch {}
    try {
        Write-Color "  Installing ODBC Driver 18 via winget..." Yellow
        $proc = Start-Process -FilePath "winget" -ArgumentList "install Microsoft.ODBCDriver18 --accept-source-agreements --accept-package-agreements --silent" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            Write-Color "  [+] ODBC Driver 18 installed successfully" Green
            return $true
        }
    } catch { Write-Color "  winget failed, trying direct download..." Yellow }

    $msiPath = Join-Path $env:TEMP "msodbcsql.msi"
    $downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2293326&clcid=0x409&culture=en-us&country=us"
    try {
        Write-Color "  Downloading ODBC Driver 18 installer..." Yellow
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
        Write-Color "  Running installer..." Yellow
        $proc = Start-Process -FilePath "msiexec" -ArgumentList "/i `"$msiPath`" /quiet /norestart IACCEPTMSODBCSQLLICENSETERMS=YES" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) {
            Write-Color "  [+] ODBC Driver 18 installed successfully" Green
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            return $true
        }
    } catch { Write-Color "  [!] Install failed: $_" Red }
    finally { Remove-Item $msiPath -Force -ErrorAction SilentlyContinue }

    Write-Color "  [!] Could not auto-install ODBC Driver 18." Red
    Write-Color "  [!] Download from: https://go.microsoft.com/fwlink/?linkid=2293326" Red
    return $false
}

# ── Web App ─────────────────────────────────────────────────────
function Start-WebApp {
    param([string]$ActiveEnvs = "all")
    Write-Color "  Installing Python dependencies..." Gray
    pip install -r (Join-Path $webDir "requirements.txt") -q 2>$null

    $pidFile = Join-Path $webDir "app.pid"
    if (Test-Path $pidFile) {
        Stop-Process -Id (Get-Content $pidFile) -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    $logFile = Join-Path $webDir "app.log"
    $env:FLASK_APP = "app.py"
    $env:FLASK_ENV = "development"
    $env:ACTIVE_ENVS = $ActiveEnvs

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "python"
    $psi.Arguments = "-m flask run --host=0.0.0.0 --port=5002"
    $psi.WorkingDirectory = $webDir
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables["FLASK_APP"] = "app.py"
    $psi.EnvironmentVariables["FLASK_ENV"] = "development"
    $psi.EnvironmentVariables["ACTIVE_ENVS"] = $ActiveEnvs

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($proc) {
        $proc.Id | Out-File -FilePath $pidFile -Encoding ASCII
        Start-Sleep -Seconds 2
        Write-Color "  [+] Web app starting on http://localhost:5002" Green
        Write-Color "  [+] PID: $($proc.Id) | Logs: $logFile" Gray
    } else { Write-Color "  [!] Failed to start web app" Red }
}

function Stop-WebApp {
    $pidFile = Join-Path $webDir "app.pid"
    if (Test-Path $pidFile) {
        Stop-Process -Id (Get-Content $pidFile) -Force -ErrorAction SilentlyContinue
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        Write-Color "  [+] Web app stopped" Green
    }
}

function Show-Status {
    Write-Color "=== Status ===" Cyan
    foreach ($pair in @(@("PostgreSQL HA", $pgDir), @("SQL Server HA", $sqlDir))) {
        $name = $pair[0]; $dir = $pair[1]
        Write-Color "  $($name):" White
        Push-Location $dir
        docker-compose ps 2>$null | Select-Object -Skip 2 | ForEach-Object { Write-Color "    $_" Gray }
        Pop-Location
    }
    $pidFile = Join-Path $webDir "app.pid"
    if (Test-Path $pidFile) {
        Write-Color "  Web App: running (PID: $(Get-Content $pidFile))" Green
    } else { Write-Color "  Web App: not running" Gray }
}

function Stop-All {
    Write-Color "`n=== Stopping All Servers ===" Cyan
    Write-Color "  Stopping PostgreSQL HA..." Gray
    Push-Location $pgDir; docker-compose down 2>$null; Pop-Location
    Write-Color "  Stopping SQL Server HA..." Gray
    Push-Location $sqlDir; docker-compose down 2>$null; Pop-Location
    Stop-WebApp
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

# Generate override files for engines that will be started
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

if (-not $SkipSqlServer) { Ensure-OdbcDriver; Write-Host "" }

if (-not $SkipPostgres) {
    Write-Color "[1/3] Starting PostgreSQL HA Cluster (Patroni)..." Yellow
    Push-Location $pgDir; docker-compose up -d; Pop-Location
    Write-Color "  [+] PostgreSQL HA cluster started`n" Green
}

if (-not $SkipSqlServer) {
    Write-Color "[2/3] Starting SQL Server HA Cluster..." Yellow
    Push-Location $sqlDir; docker-compose up -d; Pop-Location
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
    if ($Background) {
        Write-Color "[3/3] Starting CRUD Web App (background mode)..." Yellow
        Start-WebApp -ActiveEnvs $activeEnvs
        Write-Color "  Use .\stop_all.ps1 to stop all services." Gray
        Write-Host ""
    } else {
        Write-Color "[3/3] Starting CRUD Web App (foreground mode)..." Yellow
        Write-Color "  Open http://localhost:5002 in your browser." White
        Write-Color "  Press Ctrl+C to stop the web app (containers keep running)." Yellow
        Write-Host "---"
        $env:FLASK_APP = "app.py"
        $env:FLASK_ENV = "development"
        $env:ACTIVE_ENVS = $activeEnvs
        Push-Location $webDir
        try {
            & python -m flask run --host=0.0.0.0 --port=5002
        } finally {
            Pop-Location
        }
        Write-Host ""
        Write-Color "Web app stopped." Yellow
        Write-Color "Containers are still running. To stop them:" Gray
        Write-Color "  .\stop_all.ps1" Gray
    }
}
