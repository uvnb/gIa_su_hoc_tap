<#
  Bật backend "Cú Brain" trên máy tính để máy tính bảng (cùng Wi-Fi) kết nối tới.

  .\run_backend.ps1          → chế độ GIẢ LẬP: miễn phí, không cần khóa API (Cú hỏi theo mẫu có sẵn)
  .\run_backend.ps1 -Real    → AI THẬT theo backend\.env (cần ANTHROPIC_API_KEY, tốn phí)

  Lần đầu Windows có thể hỏi "Cho phép truy cập mạng?" → chọn Mạng riêng (Private) → Cho phép.
#>
param([switch]$Real, [int]$Port = 8090)

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
Start-Process powershell -ArgumentList '-NoExit', '-Command', $cmd

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
foreach ($ip in $ips) { Write-Host "  Địa chỉ cho máy tính bảng: http://${ip}:$Port" -ForegroundColor Cyan }
Write-Host "  Kiểm tra trên tablet: mở Chrome → http://<địa chỉ trên>/v1/health"
Write-Host "Tắt backend: đóng cửa sổ PowerShell có tiêu đề '$title'."
