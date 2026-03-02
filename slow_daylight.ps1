<#
.SYNOPSIS
    ATM9 Sky Day/Night Cycle Slowdown via RCON
.DESCRIPTION
    Connects to the Minecraft server via RCON and slows the day/night cycle
    to 1 hour (3x normal 20-minute cycle) by manually advancing time.
#>

param(
    [string]$Host_ = "localhost",
    [int]$Port = 25575,
    [string]$Password = "Hackers11!@",
    [int]$TargetCycleMins = 60  # 1 hour per full MC day
)

# --- RCON Protocol Implementation ---
function New-RconPacket([int]$RequestId, [int]$Type, [string]$Payload) {
    $payloadBytes = [System.Text.Encoding]::ASCII.GetBytes($Payload)
    $length = 4 + 4 + $payloadBytes.Length + 2  # reqId + type + payload + 2 null bytes
    $packet = New-Object byte[] ($length + 4)  # +4 for the length field itself
    [BitConverter]::GetBytes([int]$length).CopyTo($packet, 0)
    [BitConverter]::GetBytes([int]$RequestId).CopyTo($packet, 4)
    [BitConverter]::GetBytes([int]$Type).CopyTo($packet, 8)
    $payloadBytes.CopyTo($packet, 12)
    $packet[12 + $payloadBytes.Length] = 0
    $packet[12 + $payloadBytes.Length + 1] = 0
    return $packet
}

function Read-RconResponse([System.Net.Sockets.NetworkStream]$Stream) {
    $lenBuf = New-Object byte[] 4
    $Stream.Read($lenBuf, 0, 4) | Out-Null
    $length = [BitConverter]::ToInt32($lenBuf, 0)
    $bodyBuf = New-Object byte[] $length
    $totalRead = 0
    while ($totalRead -lt $length) {
        $read = $Stream.Read($bodyBuf, $totalRead, $length - $totalRead)
        if ($read -eq 0) { break }
        $totalRead += $read
    }
    $reqId = [BitConverter]::ToInt32($bodyBuf, 0)
    $type = [BitConverter]::ToInt32($bodyBuf, 4)
    $payload = ""
    if ($length -gt 10) {
        $payload = [System.Text.Encoding]::ASCII.GetString($bodyBuf, 8, $length - 10)
    }
    return @{ RequestId = $reqId; Type = $type; Payload = $payload }
}

function Send-RconCommand([System.Net.Sockets.NetworkStream]$Stream, [string]$Command, [int]$ReqId) {
    $packet = New-RconPacket -RequestId $ReqId -Type 2 -Payload $Command
    $Stream.Write($packet, 0, $packet.Length)
    $Stream.Flush()
    return Read-RconResponse -Stream $Stream
}

# --- Main ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ATM9 Sky Day/Night Cycle Controller" -ForegroundColor Cyan
Write-Host "  Target: $TargetCycleMins minutes per MC day" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Connect
Write-Host "Connecting to RCON at ${Host_}:${Port}..." -ForegroundColor Yellow
try {
    $client = New-Object System.Net.Sockets.TcpClient($Host_, $Port)
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    $stream.WriteTimeout = 5000
} catch {
    Write-Host "ERROR: Could not connect to RCON. Is the server running?" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Login
Write-Host "Authenticating..." -ForegroundColor Yellow
$loginPacket = New-RconPacket -RequestId 1 -Type 3 -Payload $Password
$stream.Write($loginPacket, 0, $loginPacket.Length)
$stream.Flush()
$loginResp = Read-RconResponse -Stream $stream

if ($loginResp.RequestId -eq -1) {
    Write-Host "ERROR: RCON authentication failed. Check your password." -ForegroundColor Red
    $client.Close()
    exit 1
}
Write-Host "Authenticated successfully!" -ForegroundColor Green

# Disable vanilla daylight cycle
Write-Host "Disabling vanilla daylight cycle..." -ForegroundColor Yellow
$resp = Send-RconCommand -Stream $stream -Command "gamerule doDaylightCycle false" -ReqId 2
Write-Host "  Server: $($resp.Payload)" -ForegroundColor Gray

# Calculate tick rate
# Normal: 24000 ticks in 20 min = 20 ticks/sec
# Target: 24000 ticks in $TargetCycleMins min
$ticksPerSecond = 24000.0 / ($TargetCycleMins * 60)
$intervalMs = 1000  # run every 1 second
$ticksPerInterval = [math]::Max(1, [math]::Round($ticksPerSecond * ($intervalMs / 1000.0)))

Write-Host ""
Write-Host "Day cycle active: adding $ticksPerInterval tick(s) per second" -ForegroundColor Green
Write-Host "  (~$([math]::Round(24000 / $ticksPerSecond / 60, 1)) real minutes per MC day)" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop (daylight cycle will remain off)" -ForegroundColor Yellow
Write-Host ""

$reqId = 10
$tickCount = 0

try {
    while ($true) {
        $resp = Send-RconCommand -Stream $stream -Command "time add $ticksPerInterval" -ReqId $reqId
        $reqId++
        $tickCount += $ticksPerInterval
        
        # Show status every 60 seconds
        if ($reqId % 60 -eq 0) {
            $mcTime = $tickCount % 24000
            $hours = [math]::Floor($mcTime / 1000 + 6) % 24
            $mins = [math]::Floor(($mcTime % 1000) / 1000 * 60)
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] MC Time: ~$($hours.ToString('00')):$($mins.ToString('00')) | Total ticks added: $tickCount" -ForegroundColor DarkGray
        }
        
        Start-Sleep -Milliseconds $intervalMs
    }
} catch {
    if ($_.Exception -is [System.Management.Automation.PipelineStoppedException] -or 
        $_.Exception.InnerException -is [System.IO.IOException]) {
        Write-Host "`nStopped." -ForegroundColor Yellow
    } else {
        Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    }
} finally {
    Write-Host "Closing RCON connection..." -ForegroundColor Yellow
    if ($stream) { $stream.Close() }
    if ($client) { $client.Close() }
    Write-Host "To re-enable normal daylight cycle, run: /gamerule doDaylightCycle true" -ForegroundColor Cyan
}
