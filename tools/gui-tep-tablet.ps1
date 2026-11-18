# Gửi tệp xuống máy tính bảng qua cáp USB – kéo thả tệp vào cửa sổ (hoặc thả lên biểu tượng ngoài Desktop).
# Tệp nằm trong: Bộ nhớ trong / Download / TuMayTinh  (mở bằng ứng dụng "Tệp" / "Files" trên máy tính bảng).
# Tệp .apk → tự CÀI ĐẶT luôn. Cần: cắm cáp, đã bật "Gỡ lỗi USB" (USB debugging).
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Files)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- tìm adb
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    foreach ($p in @('D:\tools\platform-tools\adb.exe', "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe")) {
        if (Test-Path $p) { $adb = $p; break }
    }
}
$dest = '/sdcard/Download/TuMayTinh'

function Get-Tablet {
    if (-not $adb) { return $null }
    $lines = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
    if ($lines) { return ($lines | Select-Object -First 1).Split("`t")[0] }
    return $null
}

# ---- giao diện
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gửi tệp xuống máy tính bảng'
$form.Size = New-Object System.Drawing.Size(640, 560)
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 248, 236)
$form.AllowDrop = $true
$form.Font = New-Object System.Drawing.Font('Segoe UI', 11)

$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(20, 14)
$status.Size = New-Object System.Drawing.Size(590, 30)
$status.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($status)

$drop = New-Object System.Windows.Forms.Label
$drop.Location = New-Object System.Drawing.Point(20, 50)
$drop.Size = New-Object System.Drawing.Size(585, 170)
$drop.BorderStyle = 'FixedSingle'
$drop.BackColor = [System.Drawing.Color]::FromArgb(227, 240, 255)
$drop.TextAlign = 'MiddleCenter'
$drop.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$drop.Text = "📥  KÉO THẢ TỆP VÀO ĐÂY`n`n(ảnh, video, PDF, nhạc, thư mục… · tệp .apk sẽ được cài luôn)"
$drop.AllowDrop = $true
$form.Controls.Add($drop)

$btnPick = New-Object System.Windows.Forms.Button
$btnPick.Text = '📂 Chọn tệp…'
$btnPick.Location = New-Object System.Drawing.Point(20, 232)
$btnPick.Size = New-Object System.Drawing.Size(180, 44)
$form.Controls.Add($btnPick)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = '📱 Mở thư mục trên tablet'
$btnOpen.Location = New-Object System.Drawing.Point(210, 232)
$btnOpen.Size = New-Object System.Drawing.Size(240, 44)
$form.Controls.Add($btnOpen)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = '🔄 Kiểm tra cáp'
$btnRefresh.Location = New-Object System.Drawing.Point(460, 232)
$btnRefresh.Size = New-Object System.Drawing.Size(145, 44)
$form.Controls.Add($btnRefresh)

$log = New-Object System.Windows.Forms.ListBox
$log.Location = New-Object System.Drawing.Point(20, 288)
$log.Size = New-Object System.Drawing.Size(585, 210)
$log.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$form.Controls.Add($log)

function Write-Log([string]$msg) {
    $log.Items.Insert(0, "$(Get-Date -Format 'HH:mm:ss')  $msg")
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-Status {
    if (-not $adb) {
        $status.Text = '❌ Không tìm thấy adb (D:\tools\platform-tools\adb.exe)'
        $status.ForeColor = [System.Drawing.Color]::Firebrick
        return $false
    }
    $t = Get-Tablet
    if ($t) {
        $status.Text = "✅ Đã nối máy tính bảng ($t) – tệp sẽ vào Download/TuMayTinh"
        $status.ForeColor = [System.Drawing.Color]::SeaGreen
        return $true
    }
    $status.Text = '⚠️ Chưa thấy máy tính bảng: cắm cáp USB, mở khóa màn hình, bấm "Cho phép" nếu được hỏi'
    $status.ForeColor = [System.Drawing.Color]::DarkOrange
    return $false
}

function Send-Files([string[]]$paths) {
    if (-not (Update-Status)) { Write-Log '⚠️ Chưa nối máy tính bảng – chưa gửi được.'; return }
    & $adb shell mkdir -p $dest 2>$null | Out-Null
    foreach ($p in $paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $name = Split-Path $p -Leaf
        $form.Cursor = 'WaitCursor'
        if ($p.ToLower().EndsWith('.apk')) {
            Write-Log "⏳ Đang cài ứng dụng $name …"
            $out = & $adb install -r "$p" 2>&1 | Out-String
            if ($out -match 'Success') { Write-Log "✅ Đã cài: $name" } else { Write-Log "❌ Cài lỗi: $name – $($out.Trim() -replace '\s+', ' ')" }
        } else {
            $size = if ((Get-Item -LiteralPath $p).PSIsContainer) { 'thư mục' } else { '{0:N1} MB' -f ((Get-Item -LiteralPath $p).Length / 1MB) }
            Write-Log "⏳ Đang gửi $name ($size) …"
            $out = & $adb push "$p" "$dest/" 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                # báo cho máy biết có tệp mới → hiện ngay trong Thư viện ảnh / Tệp
                & $adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$dest/$name" 2>$null | Out-Null
                Write-Log "✅ Đã gửi: $name → Download/TuMayTinh"
            } else {
                Write-Log "❌ Gửi lỗi: $name – $($out.Trim() -replace '\s+', ' ')"
            }
        }
        $form.Cursor = 'Default'
    }
}

$onEnter = { param($s, $e) if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = 'Copy' } }
$onDrop = { param($s, $e) Send-Files ($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)) }
$form.Add_DragEnter($onEnter); $form.Add_DragDrop($onDrop)
$drop.Add_DragEnter($onEnter); $drop.Add_DragDrop($onDrop)

$btnPick.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Multiselect = $true
    $dlg.Title = 'Chọn tệp gửi xuống máy tính bảng'
    if ($dlg.ShowDialog() -eq 'OK') { Send-Files $dlg.FileNames }
})
$btnRefresh.Add_Click({ [void](Update-Status) })
$btnOpen.Add_Click({
    if (-not (Update-Status)) { return }
    # mở ứng dụng Tệp trên máy tính bảng tại thư mục TuMayTinh
    & $adb shell am start -a android.intent.action.VIEW -t 'vnd.android.document/directory' `
        -d 'content://com.android.externalstorage.documents/document/primary%3ADownload%2FTuMayTinh' 2>$null | Out-Null
    Write-Log '📱 Đã mở thư mục TuMayTinh trên máy tính bảng.'
})

$form.Add_Shown({
    [void](Update-Status)
    if ($Files) { Send-Files $Files }   # thả tệp lên biểu tượng ngoài Desktop
})
[void]$form.ShowDialog()
