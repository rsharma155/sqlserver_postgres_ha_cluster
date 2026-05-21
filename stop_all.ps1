$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pgDir = Join-Path $rootDir "Postgres_HA_docker"
$sqlDir = Join-Path $rootDir "SQL_Server_HA_Docker"
$webDir = Join-Path $rootDir "web_app"

function Write-Color($text, $color) { Write-Host $text -ForegroundColor $color }

# Clean up generated docker-compose override files
$pgOverride = Join-Path $pgDir "docker-compose.override.yml"
$sqlOverride = Join-Path $sqlDir "docker-compose.override.yml"
if (Test-Path $pgOverride) { Remove-Item $pgOverride -Force; Write-Color "  Removed PG override" Gray }
if (Test-Path $sqlOverride) { Remove-Item $sqlOverride -Force; Write-Color "  Removed SQL override" Gray }

$pidFile = Join-Path $webDir "app.pid"
if (Test-Path $pidFile) {
    Write-Color "  Stopping web app (PID: $(Get-Content $pidFile))..." Yellow
    Stop-Process -Id (Get-Content $pidFile) -Force -ErrorAction SilentlyContinue
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    Write-Color "  [+] Web app stopped" Green
} else { Write-Color "  Web app: not running" Gray }

Write-Color "  Stopping PostgreSQL HA..." Yellow
Push-Location $pgDir; docker-compose down 2>$null; Pop-Location
Write-Color "  [+] PostgreSQL HA stopped" Green

Write-Color "  Stopping SQL Server HA..." Yellow
Push-Location $sqlDir; docker-compose down 2>$null; Pop-Location
Write-Color "  [+] SQL Server HA stopped" Green

Write-Color "`n[+] All servers stopped." Green
