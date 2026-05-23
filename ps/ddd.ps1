#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ล้างรายการ Registry ที่เก็บประวัติการใช้งาน Windows (ตามรายการในรูป)

.DESCRIPTION
    ลบ/ล้างค่าใน AppCompatFlags, MuiCache, Explorer history, BAM ฯลฯ
    รันด้วยสิทธิ์ Administrator

.EXAMPLE
    .\Clear-WindowsActivityRegistry.ps1
    .\Clear-WindowsActivityRegistry.ps1 -Backup
    .\Clear-WindowsActivityRegistry.ps1 -WhatIf
#>

[CmdletBinding()]
param(
    [switch]$Backup,
    [switch]$WhatIf,
    [string]$BackupPath = (Join-Path $env:USERPROFILE "Desktop\RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step([string]$Message) {
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "    OK: $Message" -ForegroundColor Green
}

function Write-Skip([string]$Message) {
    Write-Host "    SKIP: $Message" -ForegroundColor Yellow
}

function Write-Fail([string]$Message) {
    Write-Host "    FAIL: $Message" -ForegroundColor Red
}

function Write-WhatIfAction([string]$Message) {
    Write-Host "    WHATIF: $Message" -ForegroundColor Magenta
}

function Get-ActiveControlSet {
    try {
        $current = (Get-ItemProperty -Path 'HKLM:\SYSTEM\Select' -Name 'Current' -ErrorAction Stop).Current
        return "ControlSet{0:D3}" -f $current
    }
    catch {
        return 'ControlSet001'
    }
}

function Export-RegistryKeyIfExists {
    param(
        [string]$Path,
        [string]$OutFile
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    & reg.exe export $Path $OutFile /y 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
}

function Remove-RegistryKeyTree {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Skip "ไม่พบ $Path"
        return
    }
    if ($WhatIf) {
        Write-WhatIfAction "ลบคีย์ $Path"
        return
    }
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    Write-Ok "ลบคีย์ $Path"
}

function Clear-RegistryValues {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Skip "ไม่พบ $Path"
        return
    }

    $item = Get-Item -LiteralPath $Path
    $props = @($item.Property | Where-Object { $_ -notmatch '^PS' })
    if ($props.Count -eq 0) {
        Write-Skip "ไม่มี values ใน $Path"
        return
    }
    if ($WhatIf) {
        Write-WhatIfAction "ล้าง $($props.Count) values ใน $Path"
        return
    }
    foreach ($name in $props) {
        Remove-ItemProperty -LiteralPath $Path -Name $name -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "ล้าง values ใน $Path ($($props.Count) รายการ)"
}

function Clear-FileExtsHistory {
    param([string]$Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts')
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Skip "ไม่พบ $Path"
        return
    }

    $subkeys = @(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue)
    $removed = 0

    foreach ($sub in $subkeys) {
        foreach ($name in @('OpenWithList', 'OpenWithProgids', 'UserChoice', 'MRUList', 'MRUListEx')) {
            $childPath = Join-Path $sub.PSPath $name
            if (-not (Test-Path -LiteralPath $childPath)) { continue }
            if ($WhatIf) {
                Write-WhatIfAction "ลบ $childPath"
            }
            else {
                Remove-Item -LiteralPath $childPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            $removed++
        }

        if (-not $WhatIf) {
            $item = Get-Item -LiteralPath $sub.PSPath
            $props = @($item.Property | Where-Object { $_ -notmatch '^PS' })
            foreach ($prop in $props) {
                Remove-ItemProperty -LiteralPath $sub.PSPath -Name $prop -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if ($WhatIf) {
        Write-WhatIfAction "ล้างประวัติ FileExts ($($subkeys.Count) นามสกุล)"
    }
    else {
        Write-Ok "ล้างประวัติ FileExts ($removed คีย์ย่อยที่เกี่ยวข้อง)"
    }
}

function Stop-BamServiceSafe {
    $svc = Get-Service -Name 'bam' -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Skip 'ไม่พบ service bam'
        return $false
    }
    if ($svc.Status -eq 'Running') {
        if ($WhatIf) {
            Write-WhatIfAction 'หยุด service bam'
            return $true
        }
        Stop-Service -Name 'bam' -Force -ErrorAction Stop
        Write-Ok 'หยุด service bam แล้ว'
        return $true
    }
    Write-Skip 'service bam ไม่ได้รันอยู่'
    return $false
}

function Start-BamServiceSafe {
    if ($WhatIf) { return }
    $svc = Get-Service -Name 'bam' -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    if ($svc.Status -ne 'Running') {
        Start-Service -Name 'bam' -ErrorAction SilentlyContinue
        Write-Ok 'เริ่ม service bam แล้ว'
    }
}

function Clear-BamUserSettings {
    param([string]$ControlSet)

    $base = "HKLM:\SYSTEM\$ControlSet\Services\bam\State\UserSettings"
    if (-not (Test-Path -LiteralPath $base)) {
        Write-Skip "ไม่พบ $base"
        return
    }

    $stopped = Stop-BamServiceSafe
    try {
        if ($WhatIf) {
            $sidKeys = @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)
            foreach ($sid in $sidKeys) {
                Write-WhatIfAction "ลบ BAM SID: $($sid.PSChildName)"
            }
            Write-WhatIfAction "ล้าง values ใน $base"
            return
        }

        foreach ($sid in @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $sid.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Ok "ลบ BAM SID: $($sid.PSChildName)"
        }
        Clear-RegistryValues -Path $base
    }
    finally {
        if ($stopped) {
            Start-BamServiceSafe
        }
    }
}

# --- Main ---

Write-Host ''
Write-Host '=== ล้าง Registry ประวัติการใช้งาน Windows ===' -ForegroundColor White
if ($WhatIf) { Write-Host '(โหมด WhatIf - ไม่มีการลบจริง)' -ForegroundColor Magenta }
Write-Host ''

if (-not (Test-IsAdmin)) {
    Write-Fail 'ต้องรันสคริปต์ด้วยสิทธิ์ Administrator (คลิกขวา -> Run as administrator)'
    exit 1
}

$controlSet = Get-ActiveControlSet
Write-Step "ใช้ Control Set: $controlSet"

if ($Backup -and -not $WhatIf) {
    Write-Step "สำรอง Registry ไปที่: $BackupPath"
    $keysToBackup = @(
        'HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags',
        'HKCU\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache',
        'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer',
        'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\TypedPaths',
        "HKLM\SYSTEM\$controlSet\Services\bam\State\UserSettings"
    )
    $i = 0
    foreach ($regPath in $keysToBackup) {
        $i++
        $out = Join-Path $BackupPath ("backup_{0:D2}.reg" -f $i)
        if (Export-RegistryKeyIfExists -Path $regPath -OutFile $out) {
            Write-Ok "สำรอง $regPath -> $out"
        }
        else {
            Write-Skip "ข้ามสำรอง $regPath"
        }
    }
}

Write-Step '1. AppCompatFlags - Compatibility Assistant Store'
Remove-RegistryKeyTree -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store'

Write-Step '2. MuiCache'
Remove-RegistryKeyTree -Path 'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'

Write-Step '3. AppCompatFlags - Compatibility (values)'
Clear-RegistryValues -Path 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility'

Write-Step '4. Explorer - FileExts (ประวัติเท่านั้น)'
Clear-FileExtsHistory

Write-Step '5. Explorer - FeatureUsage\AppSwitched'
Remove-RegistryKeyTree -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched'

Write-Step '6. BAM - UserSettings'
Clear-BamUserSettings -ControlSet $controlSet

Write-Step '7. Explorer - FeatureUsage\ShowJumpView'
Remove-RegistryKeyTree -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\ShowJumpView'

Write-Step '8. Explorer - FileExts.CT'
Remove-RegistryKeyTree -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts.CT'

Write-Step '9. Explorer - RecentDocs.CT'
Remove-RegistryKeyTree -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs.CT'

Write-Step '10. TypedPaths'
Clear-RegistryValues -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\TypedPaths'

Write-Step '11. BAM - SID เฉพาะ (ถ้ายังเหลือ)'
$sidPath = "HKLM:\SYSTEM\$controlSet\Services\bam\State\UserSettings\S-1-5-21-3989500955-3772826868-2583967028-1001"
if (Test-Path -LiteralPath $sidPath) {
    $stopped = Stop-BamServiceSafe
    try {
        Remove-RegistryKeyTree -Path $sidPath
    }
    finally {
        if ($stopped) { Start-BamServiceSafe }
    }
}
else {
    Write-Skip 'ไม่พบ SID ที่ระบุ (อาจถูกลบในขั้นตอน BAM แล้ว)'
}

Write-Host ''
Write-Host '=== เสร็จสิ้น ===' -ForegroundColor White
Write-Host 'หมายเหตุ: Windows อาจสร้างรายการใหม่หลังใช้งานต่อ หรือรีสตาร์ท' -ForegroundColor DarkGray
Write-Host ''
