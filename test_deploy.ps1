param(
    [string]$Url = "https://agent-production-4ebf.up.railway.app"
)

$Url = $Url.TrimEnd('/')
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Testing deploy URL: $Url" -ForegroundColor Cyan
Write-Host "=================================================="

$DeployApiKey = ""
if (Test-Path ".env") {
    Get-Content .env | ForEach-Object {
        if ($_ -match "^DEPLOY_API_KEY=(.*)$") {
            $DeployApiKey = $matches[1].Trim().Trim('"').Trim("'")
        }
        if (-not $DeployApiKey -and $_ -match "^AGENT_API_KEY=(.*)$") {
            $DeployApiKey = $matches[1].Trim().Trim('"').Trim("'")
        }
    }
}

Write-Host "`n[1] GET /health (Liveness) - expected: 200 {status: ok}" -ForegroundColor Yellow
try {
    $res = Invoke-RestMethod -Uri "$Url/health" -Method Get
    Write-Host "Status: 200 OK" -ForegroundColor Green
    $res | ConvertTo-Json
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n[2] GET /ready (Readiness) - expected: 200 {status: ready, redis: True}" -ForegroundColor Yellow
try {
    $res = Invoke-RestMethod -Uri "$Url/ready" -Method Get
    Write-Host "Status: 200 OK" -ForegroundColor Green
    $res | ConvertTo-Json
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n[3] POST /ask (No API key) - expected: 401 Unauthorized" -ForegroundColor Yellow
try {
    $body = @{ question = "Hello" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$Url/ask" -Method Post -Body $body -ContentType "application/json"
    Write-Host "Failed: expected 401 but got 200" -ForegroundColor Red
} catch {
    Write-Host "Correctly returned error (expected 401): $_" -ForegroundColor Green
}

if ($DeployApiKey) {
    Write-Host "`n[4] POST /ask (With valid API key) - expected: 200" -ForegroundColor Yellow
    try {
        $body = @{ question = "Docker la gi?" } | ConvertTo-Json
        $headers = @{
            "X-API-Key" = $DeployApiKey
            "X-User-Id" = "sv01"
        }
        $res = Invoke-RestMethod -Uri "$Url/ask" -Method Post -Body $body -ContentType "application/json" -Headers $headers
        Write-Host "Status: 200 OK" -ForegroundColor Green
        $res | ConvertTo-Json
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n[!] No DEPLOY_API_KEY found in .env" -ForegroundColor DarkYellow
}
