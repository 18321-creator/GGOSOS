#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('1', '2', 'Quick', 'Deep', '')]
    [string]$Mode = ''
)

$ErrorActionPreference = "SilentlyContinue"

$script:TargetSid = $null
$script:HkcuRoot = 'HKCU:'

[Console]::Title = "JETT.EXE ON TOP"

# =========================
# HEADER / UI
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
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    switch ($Type) {
        "SUCCESS" {
            Write-Host "  [+] " -NoNewline -ForegroundColor Magenta
            Write-Host $Message -ForegroundColor White
        }
        "SUCCES" {
            Write-Host "  [+] " -NoNewline -ForegroundColor Magenta
            Write-Host $Message -ForegroundColor White
        }
        "NO KEY" {
            Write-Host "  [-] " -NoNewline -ForegroundColor Red
            Write-Host $Message -ForegroundColor White
        }
        "ERROR" {
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

# =========================
# HELPERS
# =========================

function Get-SidFromAccountName {
    param([string]$AccountName)
    if ($AccountName -notmatch '\\') { $AccountName = ".\$AccountName" }
    $nt = New-Object System.Security.Principal.NTAccount($AccountName)
    return $nt.Translate([System.Security.Principal.SecurityIdentifier]).Value
}

function Get-InteractiveAccountName {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        if ($cs.UserName) { return $cs.UserName }
    } catch { }
    try {
        $p = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop | Select-Object -First 1
        if ($p.Owner) { return $p.Owner }
    } catch { }
    return "$env:USERDOMAIN\$env:USERNAME"
}

function Resolve-TargetUserHive {
    $account = Get-InteractiveAccountName
    $script:TargetSid = Get-SidFromAccountName -AccountName $account
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $hive = "Registry::HKEY_USERS\$script:TargetSid"

    if (-not $isAdmin -and $currentSid -eq $script:TargetSid) {
        $script:HkcuRoot = 'HKCU:'
        return
    }
    if (Test-Path -LiteralPath $hive) {
        $script:HkcuRoot = $hive
        Write-Console "Hive: HKEY_USERS\$($script:TargetSid)" "INFO"
    } else {
        $script:HkcuRoot = 'HKCU:'
        Write-Console "Warning: using HKCU fallback" "NO KEY"
    }
}

function Get-HkcuPath {
    param([string]$SubKey)
    $sub = $SubKey -replace '^HKCU:\\', '' -replace '^\\', ''
    if ($script:HkcuRoot -eq 'HKCU:') { return "HKCU:\$sub" }
    return "$($script:HkcuRoot)\$sub"
}

function Invoke-QuickRegistryClean {
    Resolve-TargetUserHive
    Write-Console "QUICK REGISTRY CLEAN..." "INFO"

    $RegistryJobs = @(
        @{ Path = "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store"; Type = "Tree" }
        @{ Path = "SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"; Type = "Tree" }
        @{ Path = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility"; Type = "Values" }
        @{ Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"; Type = "Tree" }
        @{ Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\ShowJumpView"; Type = "Tree" }
        @{ Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts.CT"; Type = "Tree" }
        @{ Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs.CT"; Type = "Tree" }
        @{ Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\TypedPaths"; Type = "Values" }
    )

    foreach ($job in $RegistryJobs) {
        $Key = Get-HkcuPath $job.Path
        if (-not (Test-Path -LiteralPath $Key)) { continue }
        if ($job.Type -eq "Tree") {
            Remove-Item -Path $Key -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            $props = (Get-Item -LiteralPath $Key).Property | Where-Object { $_ -notmatch '^PS' }
            foreach ($p in $props) {
                Remove-ItemProperty -LiteralPath $Key -Name $p -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $fileExts = Get-HkcuPath "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"
    if (Test-Path -LiteralPath $fileExts) {
        Get-ChildItem -LiteralPath $fileExts -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($n in @('OpenWithList','OpenWithProgids','UserChoice','MRUList','MRUListEx')) {
                $c = Join-Path $_.PSPath $n
                if (Test-Path $c) { Remove-Item $c -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Stop-Service -Name "bam" -Force -ErrorAction SilentlyContinue
        $bamSid = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\$script:TargetSid"
        if (Test-Path $bamSid) { Remove-Item $bamSid -Recurse -Force -ErrorAction SilentlyContinue }
        Start-Service -Name "bam" -ErrorAction SilentlyContinue
    }
}

# =========================
# CHOICE 2 = CLEAN (โครงสร้างเดิม + syshost + deep)
# =========================

function Invoke-DeepCleanChoice2 {

    Clear-Host
    Show-Header

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Console "Please run this script as Administrator!" "ERROR"
        Pause
        return
    }

    Resolve-TargetUserHive

    Write-Console "CLEANING..." "INFO"

    # --- จากโค้ด JETT: หยุด syshost + ลบไฟล์ temp ---
    Stop-Process -Name "syshost" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\syshost.exe" -Force -ErrorAction SilentlyContinue

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

    $TargetSidForTask = $script:TargetSid
    $SystemScriptBlock = {
        $TargetSid = '___TARGET_SID___'
        $BamPaths = @(
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bam\UserSettings",
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dam\UserSettings",
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings",
            "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
        )
        foreach ($RootPath in $BamPaths) {
            $sidKey = Join-Path $RootPath $TargetSid
            if (Test-Path -LiteralPath $sidKey) {
                Remove-Item -LiteralPath $sidKey -Recurse -Force -ErrorAction SilentlyContinue
            }
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
                            if (-not (Test-Path $CleanPath) -and $CleanPath -ne "") {
                                Remove-ItemProperty -Path $UserKeyPath -Name $ValueName -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
            }
        }
    }

    $SystemScriptText = $SystemScriptBlock.ToString().Replace('___TARGET_SID___', $TargetSidForTask)
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($SystemScriptText)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    $TaskName = "BAM_DAM_DeepClean"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $EncodedCommand"
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    $Task = Register-ScheduledTask -TaskName $TaskName -Action $Action -Principal $Principal -Force -ErrorAction SilentlyContinue
    if ($Task) {
        Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
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
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Map Network Drive MRU",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store",
        "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\ShowJumpView",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts.CT",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs.CT"
    )

    foreach ($Key in $RegistryKeys) {
        $RealKey = Get-HkcuPath $Key
        if (Test-Path $RealKey) { Remove-Item -Path $RealKey -Recurse -Force -ErrorAction SilentlyContinue }
    }

    $compat = Get-HkcuPath "SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility"
    if (Test-Path $compat) {
        (Get-Item -LiteralPath $compat).Property | Where-Object { $_ -notmatch '^PS' } | ForEach-Object {
            Remove-ItemProperty -LiteralPath $compat -Name $_ -Force -ErrorAction SilentlyContinue
        }
    }
    $fileExts = Get-HkcuPath "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"
    if (Test-Path $fileExts) {
        Get-ChildItem -LiteralPath $fileExts -ErrorAction SilentlyContinue | ForEach-Object {
            foreach ($n in @('OpenWithList','OpenWithProgids','UserChoice','MRUList','MRUListEx')) {
                $c = Join-Path $_.PSPath $n
                if (Test-Path $c) { Remove-Item $c -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    Start-Service -Name "EventLog" -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Console "CLEAN ALL TRACES SUCCESS" "SUCCES"
    Write-Host ""
    if ($script:HkcuRoot -ne 'HKCU:') {
        Write-Console "Check regedit: HKEY_USERS\$script:TargetSid" "INFO"
    }
    Pause
}

# =========================
# MAIN — JETT UI + เมนู
# =========================

# รันตรงจาก -Mode Deep / Quick (ข้าม key + เมนู)
if ($Mode -in '2', 'Deep') {
    Invoke-DeepCleanChoice2
    exit
}
if ($Mode -in '1', 'Quick') {
    Show-Header
    Invoke-QuickRegistryClean
    Write-Host ""
    Write-Console "QUICK CLEAN SUCCESS" "SUCCESS"
    Pause
    exit
}

# --- JETT flow ---
Show-Header

Write-Host ""
Write-Host "              E N T E R  K E Y" -ForegroundColor White
Write-Host ""
Write-Host "  [>] " -NoNewline -ForegroundColor Magenta
$key = $Host.UI.ReadLine()

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host ""
    Write-Console "NO KEY" "NO KEY"
    Start-Sleep 2
    exit
}

Write-Host ""
Write-Console "SUCCESS" "SUCCESS"
Start-Sleep 1

while ($true) {
    Show-Header

    Write-Console "1. QUICK" "INFO"
    Write-Console "2. CLEAN" "INFO"
    Write-Console "0. EXIT" "INFO"

    Write-Host ""
    Write-Console "SELECT : " "INPUT"
    $choice = $Host.UI.ReadLine()

    if ($choice -eq "1") {
        Clear-Host
        Show-Header
        Invoke-QuickRegistryClean
        Write-Host ""
        Write-Console "QUICK CLEAN SUCCESS" "SUCCESS"
        Write-Host ""
        Pause
    }
    elseif ($choice -eq "2") {
        Invoke-DeepCleanChoice2
    }
    elseif ($choice -eq "0") {
        exit
    }
}
