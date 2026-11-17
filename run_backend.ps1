<#
  Bật backend "Cú Brain" trên máy tính để máy tính bảng (cùng Wi-Fi) kết nối tới.

  .\run_backend.ps1          → chế độ GIẢ LẬP: miễn phí, không cần khóa API (Cú hỏi theo mẫu có sẵn)
  .\run_backend.ps1 -Real    → AI THẬT theo backend\.env (cần ANTHROPIC_API_KEY, tốn phí)
  .\run_backend.ps1 -ShowQr  → mở ảnh mã QR để máy tính bảng quét (dist\ma-qr-cu-to-mo.png)

  Lần đầu Windows có thể hỏi "Cho phép truy cập mạng?" → chọn Mạng riêng (Private) → Cho phép.
#>
param([switch]$Real, [switch]$ShowQr, [int]$Port = 8090)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$py = Join-Path $root 'backend\.venv\Scripts\python.exe'
if (-not (Test-Path $py)) { throw "Chưa có backend\.venv – xem backend\README.md" }

# APP_SHARED_SECRET phải trùng giá trị app_secret khi build APK trên GitHub (mặc định cutomo-local).
$setup = "`$env:APP_SHARED_SECRET='cutomo-local'; `$env:PYTHONIOENCODING='utf-8';"
if (-not $Real) {
    $setup += " `$env:DEFAULT_PROVIDER='mock'; `$env:SOLVER_PROVIDER='mock'; `$env:TUTOR_PROVIDER='mock';" +
              " `$env:CHECKER_PROVIDER='mock'; `$env:GUARD_PROVIDER='mock';"
}
$title = "Cu Brain - $(if ($Real) {'AI that'} else {'gia lap'}) - cong $Port"
$cmd = "$setup `$Host.UI.RawUI.WindowTitle='$title'; Set-Location '$root\backend'; " +
       "& '$py' -m uvicorn app.main:app --host 0.0.0.0 --port $Port"
$running = $false
try { $running = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$Port/v1/health").StatusCode -eq 200 } catch {}
if ($running) {
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
Write-Host "Backend đang chạy ($(if ($Real) {'AI THẬT – tốn phí'} else {'GIẢ LẬP – miễn phí'}))." -ForegroundColor Green
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
