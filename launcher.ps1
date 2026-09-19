#Requires -Version 5.0

<#
.SYNOPSIS
    ICMP Tunnel Lab — Windows Launcher

.DESCRIPTION
    1. Self-elevates to Administrator
    2. Checks Python / Npcap / Scapy
    3. Installs missing dependencies
    4. Opens Receiver and Sender PowerShell windows
#>


# ============================================================================
# SELF-ELEVATE TO ADMINISTRATOR
# ============================================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

$IsAdministrator = $CurrentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdministrator) {

    Write-Host ""
    Write-Host "[*] Requesting Administrator privileges (UAC)..." -ForegroundColor Yellow
    Write-Host ""

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    Exit 0
}


# ============================================================================
# GLOBAL SETTINGS
# ============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$ErrorActionPreference = "Continue"


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Banner {

    Clear-Host

    Write-Host ""
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host "       ICMP Tunnel Lab - Windows Launcher" -ForegroundColor Cyan
    Write-Host "       Blue Team Training Lab" -ForegroundColor Cyan
    Write-Host "  ==================================================" -ForegroundColor Cyan
    Write-Host ""
}


function Write-Step {

    param(
        [string]$Message
    )

    Write-Host "[*] $Message" -ForegroundColor Yellow
}


function Write-OK {

    param(
        [string]$Message
    )

    Write-Host "[+] $Message" -ForegroundColor Green
}


function Write-Err {

    param(
        [string]$Message
    )

    Write-Host "[-] $Message" -ForegroundColor Red
}


function Write-Info {

    param(
        [string]$Message
    )

    Write-Host "    $Message" -ForegroundColor Gray
}


function Write-HR {

    Write-Host "  --------------------------------------------------" -ForegroundColor DarkGray
}


# ============================================================================
# FIND PYTHON
# ============================================================================

function Get-PythonExe {

    foreach ($Command in @("python", "py", "python3")) {

        try {

            $null = & $Command --version 2>&1

            if ($LASTEXITCODE -eq 0) {

                return $Command
            }

        }
        catch {
        }
    }

    return $null
}


# ============================================================================
# CHECK NPCAP
# ============================================================================

function Test-NpcapInstalled {

    $RegPaths = @(
        "HKLM:\SOFTWARE\Npcap",
        "HKLM:\SOFTWARE\WOW6432Node\Npcap"
    )

    foreach ($Path in $RegPaths) {

        if (Test-Path $Path) {

            return $true
        }
    }

    if (Test-Path "C:\Program Files\Npcap") {

        return $true
    }

    if (Test-Path "C:\Program Files (x86)\Npcap") {

        return $true
    }

    return $false
}


# ============================================================================
# CHECK SCAPY
# ============================================================================

function Test-ScapyInstalled {

    param(
        [string]$PyExe
    )

    try {

        $Result = & $PyExe -c "import scapy; print('SCAPY_OK')" 2>&1

        return ($Result -match "SCAPY_OK")

    }
    catch {

        return $false
    }
}


# ============================================================================
# DOWNLOAD FILE WITH PROGRESS
# ============================================================================

function Download-WithProgress {

    param(
        [string]$Url,
        [string]$Dest
    )

    Write-Info "URL  : $Url"
    Write-Info "Dest : $Dest"

    try {

        # ------------------------------------------------------------
        # Try BITS first
        # ------------------------------------------------------------

        Write-Info "Trying BITS download..."

        $Job = Start-BitsTransfer `
            -Source $Url `
            -Destination $Dest `
            -Asynchronous `
            -ErrorAction Stop

        while (
            ($Job.JobState -eq "Transferring") -or
            ($Job.JobState -eq "Connecting")
        ) {

            if ($Job.BytesTotal -gt 0) {

                $Percent = [int](
                    ($Job.BytesTransferred / $Job.BytesTotal) * 100
                )

            }
            else {

                $Percent = 0
            }

            Write-Host `
                "`r    Downloading... $Percent%" `
                -NoNewline `
                -ForegroundColor Gray

            Start-Sleep -Milliseconds 500
        }

        Complete-BitsTransfer -BitsJob $Job

        Write-Host ""
        Write-OK "Download complete."

    }
    catch {

        # ------------------------------------------------------------
        # Fallback to WebClient
        # ------------------------------------------------------------

        Write-Host ""
        Write-Info "BITS download failed."
        Write-Info "Falling back to WebClient..."

        try {

            $WebClient = New-Object System.Net.WebClient

            $WebClient.DownloadFile(
                $Url,
                $Dest
            )

            Write-OK "Download complete."

        }
        catch {

            throw $_
        }
    }
}


# ============================================================================
# CHECK REQUIRED LAB FILES
# ============================================================================

function Test-LabFiles {

    $Receiver = Join-Path $ScriptDir "receiver.py"
    $Sender   = Join-Path $ScriptDir "sender.py"

    $Missing = $false

    if (-not (Test-Path $Receiver)) {

        Write-Err "receiver.py was not found:"
        Write-Info $Receiver

        $Missing = $true
    }

    if (-not (Test-Path $Sender)) {

        Write-Err "sender.py was not found:"
        Write-Info $Sender

        $Missing = $true
    }

    if ($Missing) {

        Write-Host ""
        Write-Err "Required lab files are missing."
        Write-Host ""

        return $false
    }

    return $true
}


# ============================================================================
# LAUNCH PYTHON WINDOW
# ============================================================================

function Start-LabWindow {

    param(
        [string]$Title,
        [string]$PythonFile,
        [string]$BackgroundColor,
        [string]$HeaderColor
    )

    $FullPath = Join-Path $ScriptDir $PythonFile

    $Command = @"
`$host.UI.RawUI.WindowTitle = '$Title'
`$host.UI.RawUI.BackgroundColor = '$BackgroundColor'
Clear-Host

Write-Host ''
Write-Host '  ==================================================' -ForegroundColor $HeaderColor
Write-Host '       $Title' -ForegroundColor $HeaderColor
Write-Host '  ==================================================' -ForegroundColor $HeaderColor
Write-Host ''

Set-Location '$ScriptDir'

Write-Host '[*] Starting $PythonFile ...' -ForegroundColor Yellow
Write-Host ''

& '$pyExe' '$FullPath'

Write-Host ''
Write-Host '--------------------------------------------------' -ForegroundColor DarkGray
Write-Host 'The Python process has exited.' -ForegroundColor Yellow
Write-Host 'Press Enter to close this window.' -ForegroundColor Gray

Read-Host
"@

    Start-Process `
        -FilePath "powershell.exe" `
        -WorkingDirectory $ScriptDir `
        -ArgumentList @(
            "-NoExit"
            "-ExecutionPolicy"
            "Bypass"
            "-Command"
            $Command
        )
}


# ============================================================================
# START
# ============================================================================

Write-Banner


# ============================================================================
# STEP 1 - PYTHON
# ============================================================================

Write-Host "  Step 1 / 3 : Python" -ForegroundColor White
Write-HR

$pyExe = Get-PythonExe


if ($null -eq $pyExe) {

    Write-Err "Python is NOT installed."
    Write-Host ""

    Write-Host "  Python must be installed manually:" -ForegroundColor Yellow

    Write-Host "  1. Go to https://www.python.org/downloads/" -ForegroundColor Cyan
    Write-Host "  2. Download Python 3.11 or newer" -ForegroundColor Cyan
    Write-Host "  3. IMPORTANT: Enable 'Add Python to PATH'" -ForegroundColor Red
    Write-Host "  4. Restart the terminal" -ForegroundColor Cyan
    Write-Host "  5. Run start_lab.bat again" -ForegroundColor Cyan

    Write-Host ""

    $Open = Read-Host "  Open Python download page now? (Y/N)"

    if ($Open -match "^[Yy]$") {

        Start-Process "https://www.python.org/downloads/"
    }

    Exit 1
}
else {

    $PythonVersion = (& $pyExe --version 2>&1).ToString().Trim()

    Write-OK "Found: $PythonVersion"
    Write-Info "Command: $pyExe"
}


Write-Host ""


# ==========================================
# Npcap Check / Installation
# ==========================================

Write-Host ""
Write-Host "[*] Checking Npcap..." -ForegroundColor Cyan

$npcapService = Get-Service -Name "npcap" -ErrorAction SilentlyContinue

if ($npcapService) {

    Write-Host "[+] Npcap is already installed." -ForegroundColor Green

}
else {

    Write-Host "[!] Npcap was not detected." -ForegroundColor Yellow
    Write-Host "[*] Downloading Npcap installer..." -ForegroundColor Cyan

    $npcapUrl = "https://npcap.com/dist/npcap-1.79.exe"
    $npcapInstaller = Join-Path $env:TEMP "npcap-installer.exe"

    try {

        Invoke-WebRequest `
            -Uri $npcapUrl `
            -OutFile $npcapInstaller `
            -UseBasicParsing

        Write-Host "[+] Npcap installer downloaded." -ForegroundColor Green

    }
    catch {

        Write-Host "[ERROR] Failed to download Npcap." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        exit 1
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host " Npcap installation required" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Npcap is required for ICMP packet capture." -ForegroundColor White
    Write-Host ""
    Write-Host "The Npcap installer will now open." -ForegroundColor White
    Write-Host "Please complete the installation normally." -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "Enable loopback traffic support if the installer provides that option." -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Press ENTER to start the Npcap installer"

    # IMPORTANT:
    # No /quiet
    # No /S
    # No silent installation
    Start-Process `
        -FilePath $npcapInstaller `
        -Wait

    Write-Host ""
    Write-Host "[*] Npcap installer closed." -ForegroundColor Cyan
    Write-Host "[*] Checking Npcap installation..." -ForegroundColor Cyan

    Start-Sleep -Seconds 2

    $npcapService = Get-Service -Name "npcap" -ErrorAction SilentlyContinue

    if ($npcapService) {

        Write-Host "[+] Npcap installed successfully." -ForegroundColor Green

    }
    else {

        Write-Host ""
        Write-Host "[ERROR] Npcap was not detected after installation." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install Npcap and run the launcher again." -ForegroundColor Yellow

        exit 1
    }
}

# ============================================================================
# STEP 3 - SCAPY
# ============================================================================

Write-Host "  Step 3 / 3 : Scapy" -ForegroundColor White
Write-HR


if (Test-ScapyInstalled -PyExe $pyExe) {

    $ScapyVersion = (
        & $pyExe -c "import scapy; print(scapy.__version__)" 2>&1
    ).ToString().Trim()

    Write-OK "Scapy is installed."
    Write-Info "Version: $ScapyVersion"

}
else {

    Write-Step "Scapy not found."
    Write-Step "Installing Scapy via pip..."

    & $pyExe -m pip install --upgrade scapy 2>&1 |
        ForEach-Object {

            Write-Info $_
        }


    if ($LASTEXITCODE -eq 0) {

        Write-OK "Scapy installed successfully."

    }
    else {

        Write-Err "pip install failed."

        Write-Info "Try manually:"
        Write-Info "$pyExe -m pip install scapy"

        Exit 1
    }
}


Write-Host ""


# ============================================================================
# CHECK LAB FILES
# ============================================================================

Write-Step "Checking lab files..."

if (-not (Test-LabFiles)) {

    Write-Host ""
    Write-Err "Lab startup aborted."
    Write-Host ""

    Read-Host "Press Enter to close"

    Exit 1
}

Write-OK "receiver.py found."
Write-OK "sender.py found."

Write-Host ""


# ============================================================================
# ALL DEPENDENCIES READY
# ============================================================================

Write-Host "  ==================================================" -ForegroundColor Green
Write-Host "       All dependencies verified!" -ForegroundColor Green
Write-Host "       Launching ICMP Tunnel Lab..." -ForegroundColor Green
Write-Host "  ==================================================" -ForegroundColor Green

Write-Host ""

Write-Host "  Wireshark filter:" -ForegroundColor Yellow
Write-Host "    icmp[4:2] == 0x4c42" -ForegroundColor White

Write-Host ""

Write-Host "  Capture interface:" -ForegroundColor Yellow
Write-Host "    Npcap Loopback Adapter" -ForegroundColor White

Write-Host ""

Start-Sleep -Seconds 1


# ============================================================================
# TERMINAL 1 - RECEIVER
# ============================================================================

Write-Step "Opening Terminal 1 - RECEIVER..."

Start-LabWindow `
    -Title "ICMP Lab - RECEIVER" `
    -PythonFile "receiver.py" `
    -BackgroundColor "DarkBlue" `
    -HeaderColor "Cyan"

Write-OK "Receiver window opened."


# ============================================================================
# WAIT
# ============================================================================

Write-Step "Waiting 3 seconds before opening Sender..."

Start-Sleep -Seconds 3


# ============================================================================
# TERMINAL 2 - SENDER
# ============================================================================

Write-Step "Opening Terminal 2 - SENDER..."

Start-LabWindow `
    -Title "ICMP Lab - SENDER" `
    -PythonFile "sender.py" `
    -BackgroundColor "DarkRed" `
    -HeaderColor "Yellow"

Write-OK "Sender window opened."


# ============================================================================
# INSTRUCTIONS
# ============================================================================

Write-Host ""

Write-Host "  ==================================================" -ForegroundColor DarkGray
Write-Host "                  LAB INSTRUCTIONS" -ForegroundColor DarkGray
Write-Host "  ==================================================" -ForegroundColor DarkGray

Write-Host ""

Write-Host "  1. In SENDER window:" -ForegroundColor Gray
Write-Host "     Press Enter twice to use defaults." -ForegroundColor Gray

Write-Host ""

Write-Host "     Target IP = 127.0.0.1" -ForegroundColor White
Write-Host "     File      = secret.txt" -ForegroundColor White

Write-Host ""

Write-Host "  2. Watch the RECEIVER window." -ForegroundColor Gray
Write-Host "     Data should arrive in chunks." -ForegroundColor Gray

Write-Host ""

Write-Host "  3. Open Wireshark." -ForegroundColor Gray
Write-Host "     Select:" -ForegroundColor Gray
Write-Host "     Npcap Loopback Adapter" -ForegroundColor White

Write-Host ""

Write-Host "  4. Use this display filter:" -ForegroundColor Gray
Write-Host "     icmp[4:2] == 0x4c42" -ForegroundColor White

Write-Host ""

Write-Host "  ==================================================" -ForegroundColor DarkGray

Write-Host ""


# ============================================================================
# KEEP LAUNCHER OPEN
# ============================================================================

Read-Host "  Press Enter to close this launcher"
