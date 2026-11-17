<#
  Bật máy chủ "Cú Brain" trên máy tính cho máy tính bảng (cắm cáp USB hoặc cùng Wi-Fi).

  .\run_backend.ps1          → tự chọn AI: có khóa trong backend\.env thì dùng (DeepSeek, Gemini,
                               OpenRouter, Claude – theo thứ tự đó), không có khóa thì GIẢ LẬP (miễn phí)
  .\run_backend.ps1 -Mock    → luôn chạy GIẢ LẬP
  .\run_backend.ps1 -ShowQr  → mở ảnh mã QR để máy tính bảng quét (dist\ma-qr-cu-to-mo.png)

  Thêm/đổi khóa trong backend\.env rồi chạy lại lệnh này: máy chủ tự khởi động lại với AI mới.
#>
param([switch]$Mock, [switch]$ShowQr, [switch]$Restart, [int]$Port = 8090)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$py = Join-Path $root 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $py)) { throw "Chưa có backend\.venv – xem backend\README.md" }

# ---- Chọn AI theo khóa có trong backend\.env ----
$envFile = Join-Path $root 'backend\.env'
$keys = @{}
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile -Encoding UTF8) {
        if ($line -match '^\s*([A-Z_]+)\s*=\s*(\S+)\s*$' -and -not $Matches[2].EndsWith('...')) { $keys[$Matches[1]] = $Matches[2] }
    }
}
$ai = 'mock'
if (-not $Mock) {
    foreach ($pair in @(@('deepseek', 'DEEPSEEK_API_KEY'), @('gemini', 'GEMINI_API_KEY'),
                        @('openrouter', 'OPENROUTER_API_KEY'), @('anthropic', 'ANTHROPIC_API_KEY'))) {
        if ($keys.ContainsKey($pair[1])) { $ai = $pair[0]; break }
    }
}
$aiName = @{ mock = 'GIẢ LẬP – miễn phí'; deepseek = 'DeepSeek'; gemini = 'Google Gemini';
             openrouter = 'OpenRouter'; anthropic = 'Claude' }[$ai]

# APP_SHARED_SECRET phải trùng app_secret khi build APK (mặc định cutomo-local).
$setup = "`$env:APP_SHARED_SECRET='cutomo-local'; `$env:PYTHONIOENCODING='utf-8'; `$env:DEFAULT_PROVIDER='$ai';" +
         " `$env:SOLVER_PROVIDER='$ai'; `$env:TUTOR_PROVIDER='$ai'; `$env:CHECKER_PROVIDER='$ai'; `$env:GUARD_PROVIDER='$ai';"
$title = "Cu Brain - $ai - cong $Port"
$cmd = "$setup `$Host.UI.RawUI.WindowTitle='$title'; Set-Location '$root\backend'; " +
       "& '$py' -m uvicorn app.main:app --host 0.0.0.0 --port $Port"

$current = $null
try { $current = (Invoke-RestMethod -TimeoutSec 2 "http://127.0.0.1:$Port/v1/health").default_provider } catch {}
if ($current -and ($current -ne $ai -or $Restart)) {
    # Đổi AI (hoặc -Restart sau khi cập nhật code) → tắt máy chủ cũ (chỉ tiến trình uvicorn của Cú) rồi bật lại.
    Write-Host "Khởi động lại máy chủ (AI: $current → $ai)…" -ForegroundColor Yellow
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($conn.OwningProcess)"
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)"
        foreach ($x in @($p, $parent)) { if ($x -and $x.CommandLine -match 'uvicorn app\.main:app') { Stop-Process -Id $x.ProcessId -Force -ErrorAction SilentlyContinue } }
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'Cu Brain' } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    }
    Start-Sleep 2
    $current = $null
}
if ($current) {
    Write-Host "Máy chủ đã chạy sẵn – không mở thêm cửa sổ." -ForegroundColor Yellow
} else {
    Start-Process powershell -ArgumentList '-NoExit', '-Command', $cmd
}

$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2\d|3[01]))' } |
    Select-Object -ExpandProperty IPAddress
$ok = $false
for ($i = 0; $i -lt 30 -and -not $ok; $i++) {
    Start-Sleep -Milliseconds 700
    try { $ok = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$Port/v1/health").StatusCode -eq 200 } catch {}
}
Write-Host ""
if (-not $ok) {
    Write-Host "Backend CHƯA chạy được – xem thông báo lỗi trong cửa sổ '$title'." -ForegroundColor Red
    return
}
Write-Host "Máy chủ Cú đang chạy – AI: $aiName. Ảnh bài tập được OCR trên máy." -ForegroundColor Green
if ($ai -eq 'mock') { Write-Host "  (Muốn AI thật: dán khóa vào backend\.env rồi chạy lại lệnh này)" -ForegroundColor Yellow }
foreach ($ip in $ips) { Write-Host "  Mở trên máy tính bảng (Chrome): http://${ip}:$Port" -ForegroundColor Cyan }

# Máy tính bảng cắm cáp USB (đã bật Gỡ lỗi USB) → nối đường cáp: 127.0.0.1:8090 trên tablet = máy chủ này.
$adb = 'D:\tools\platform-tools\adb.exe'
if (Test-Path $adb) {
    $dev = (& $adb devices) | Where-Object { $_ -match '\sdevice\s*$' }
    if ($dev) {
        & $adb reverse "tcp:$Port" "tcp:$Port" | Out-Null
        Write-Host "  Đã nối cáp USB với máy tính bảng – app dùng được cả khi khác mạng Wi-Fi." -ForegroundColor Cyan
    }
    # Chạy ngầm: mỗi lần cắm lại cáp thì tự nối lại (adb reverse mất khi rút cáp).
    $watching = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -match 'cu-usb-watch' }
    if (-not $watching) {
        $loop = "# cu-usb-watch`n while (`$true) { & '$adb' wait-for-device; & '$adb' reverse tcp:$Port tcp:$Port | Out-Null; & '$adb' wait-for-disconnect; Start-Sleep 1 }"
        Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $loop
        Write-Host "  Tự nối cáp USB mỗi khi cắm máy tính bảng (chạy ngầm)." -ForegroundColor Cyan
    }
}

# Mã QR cho máy tính bảng quét – tạo lại theo IP hiện tại; IP đổi thì tự mở ảnh QR mới.
$ip = @($ips)[0]
if ($ip) {
    $dist = Join-Path $root 'dist'
    $qr = Join-Path $dist 'ma-qr-cu-to-mo.png'
    $lastFile = Join-Path $dist 'last_ip.txt'
    $last = if (Test-Path $lastFile) { (Get-Content $lastFile -Raw).Trim() } else { '' }
    if ($last -ne $ip -or -not (Test-Path $qr)) {
        & $py (Join-Path $root 'backend\scripts\make_qr.py') "http://${ip}:$Port" $qr
        Set-Content -Path $lastFile -Value $ip
    }
    Write-Host "  Mã QR: $qr"
    if ($ShowQr -or $last -ne $ip) { Start-Process $qr }
}
if (-not (Test-Path (Join-Path $root 'app\build\web\index.html'))) {
    Write-Host "  (Chưa có bản web – build: cd app; D:\flutter\bin\flutter.bat build web --release --no-web-resources-cdn --dart-define=APP_SECRET=cutomo-local)" -ForegroundColor Yellow
}
Write-Host "Tắt backend: đóng cửa sổ PowerShell có tiêu đề '$title'."
