$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pgDir = Join-Path $rootDir "Postgres_HA_docker"
$sqlDir = Join-Path $rootDir "SQL_Server_HA_Docker"
$webDir = Join-Path $rootDir "web_app"

function Write-Color($text, $color) { Write-Host $text -ForegroundColor $color }

$pgOverride = Join-Path $pgDir "docker-compose.override.yml"
$sqlOverride = Join-Path $sqlDir "docker-compose.override.yml"
if (Test-Path $pgOverride) { Remove-Item $pgOverride -Force; Write-Color "  Removed PG override" Gray }
if (Test-Path $sqlOverride) { Remove-Item $sqlOverride -Force; Write-Color "  Removed SQL override" Gray }

Write-Color "  Stopping web app..." Yellow
docker compose -f (Join-Path $webDir "docker-compose.yml") down 2>$null | Out-Null
docker rm -f sqloptima_web 2>$null | Out-Null
Write-Color "  [+] Web app stopped" Green

Write-Color "  Stopping PostgreSQL HA..." Yellow
Push-Location $pgDir; docker compose down 2>$null; Pop-Location
Write-Color "  [+] PostgreSQL HA stopped" Green

Write-Color "  Stopping SQL Server HA..." Yellow
Push-Location $sqlDir; docker compose down 2>$null; Pop-Location
Write-Color "  [+] SQL Server HA stopped" Green

Write-Color "`n[+] All servers stopped." Green
