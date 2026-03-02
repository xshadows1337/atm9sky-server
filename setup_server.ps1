<#
.SYNOPSIS
    ATM9 Sky Server Setup Script
.DESCRIPTION
    Downloads and installs Forge 1.20.1-47.4.0, then copies mods, configs,
    kubejs, and defaultconfigs from the local CurseForge client instance.
    Run this once before starting the server for the first time.
#>

$ServerDir   = $PSScriptRoot
$ClientDir   = "C:\Users\xshad\curseforge\minecraft\Instances\All the Mods 9 - To the Sky - atm9sky"
$ForgeVer    = "1.20.1-47.4.0"
$ForgeJar    = "forge-$ForgeVer-installer.jar"
$ForgeUrl    = "https://maven.minecraftforge.net/net/minecraftforge/forge/$ForgeVer/$ForgeJar"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ATM9 Sky Server Setup" -ForegroundColor Cyan
Write-Host "  Forge $ForgeVer  |  MC 1.20.1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Verify Java ────────────────────────────────────────────────────────────
Write-Host "[1/5] Checking Java..." -ForegroundColor Yellow
try {
    $javaVer = & java -version 2>&1 | Select-String "version"
    Write-Host "      Found: $javaVer" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Java not found. Install Java 17+ and add it to PATH." -ForegroundColor Red
    exit 1
}

# ── 2. Download Forge Installer ───────────────────────────────────────────────
$installerPath = Join-Path $ServerDir $ForgeJar
if (Test-Path $installerPath) {
    Write-Host "[2/5] Forge installer already present, skipping download." -ForegroundColor Green
} else {
    Write-Host "[2/5] Downloading Forge $ForgeVer installer..." -ForegroundColor Yellow
    Write-Host "      URL: $ForgeUrl" -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $ForgeUrl -OutFile $installerPath -UseBasicParsing
        Write-Host "      Downloaded: $ForgeJar" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download Forge installer." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# ── 3. Install Forge Server ───────────────────────────────────────────────────
$runBat = Join-Path $ServerDir "run.bat"
if (Test-Path $runBat) {
    Write-Host "[3/5] Forge already installed (run.bat exists), skipping." -ForegroundColor Green
} else {
    Write-Host "[3/5] Installing Forge server (this may take a few minutes)..." -ForegroundColor Yellow
    Push-Location $ServerDir
    try {
        & java -jar $ForgeJar --installServer
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Forge installer exited with code $LASTEXITCODE." -ForegroundColor Red
            Pop-Location; exit 1
        }
        Write-Host "      Forge server installed." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to run Forge installer." -ForegroundColor Red
        Write-Host $_.Exception.Message
        Pop-Location; exit 1
    }
    Pop-Location
}

# ── 4. Copy Mods ─────────────────────────────────────────────────────────────
Write-Host "[4/5] Syncing mods from client instance..." -ForegroundColor Yellow
$modsTarget = Join-Path $ServerDir "mods"
New-Item -ItemType Directory -Force -Path $modsTarget | Out-Null
$modsSource = Join-Path $ClientDir "mods"
if (Test-Path $modsSource) {
    $files = Get-ChildItem $modsSource -Filter "*.jar"
    $copied = 0
    foreach ($f in $files) {
        $dest = Join-Path $modsTarget $f.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $f.FullName $dest
            $copied++
        }
    }
    Write-Host "      Copied $copied new mod(s). Total: $(($files).Count) mods." -ForegroundColor Green
} else {
    Write-Host "WARNING: Client mods folder not found at: $modsSource" -ForegroundColor DarkYellow
}

# ── 5. Copy Config / KubeJS / DefaultConfigs ─────────────────────────────────
Write-Host "[5/5] Syncing configs and scripts..." -ForegroundColor Yellow

$foldersToSync = @("config", "defaultconfigs", "kubejs")
foreach ($folder in $foldersToSync) {
    $src = Join-Path $ClientDir $folder
    $dst = Join-Path $ServerDir $folder
    if (Test-Path $src) {
        Write-Host "      Copying $folder..." -ForegroundColor DarkGray
        # Robocopy: /E = all subdirs, /NFL /NDL /NJH /NJS = quiet, /XO = skip older
        robocopy $src $dst /E /XO /NFL /NDL /NJH /NJS | Out-Null
        Write-Host "      $folder done." -ForegroundColor Green
    } else {
        Write-Host "      Skipping $folder (not found in client)." -ForegroundColor DarkGray
    }
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "  Run start_server.bat to launch the server." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Edit server\server.properties to adjust port, MOTD, etc." -ForegroundColor Cyan
Write-Host "      EULA has been pre-accepted in eula.txt." -ForegroundColor Cyan
