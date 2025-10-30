<#
.SYNOPSIS
  RTL8821CU WSL2 Fix Tool
.DESCRIPTION
  Configures Realtek RTL8821CU Wi-Fi adapter for WSL2 environments (Kali/Debian/Ubuntu)
  Handles driver setup, USB device attachment, and WSL2 configuration
.AUTHOR
  Znuzhg Onvyxpv
.VERSION
  1.0.0
.LAST-UPDATED
  2025-10-29
#>

# Load PROJECT_ROOT if provided by setup.ps1
$envFile = Join-Path $HOME "RTL8821CU_FixSuite/.env"

if (Test-Path $envFile) {
    Write-Host "Loading PROJECT_ROOT from .env..." -ForegroundColor Cyan
    Get-Content $envFile | ForEach-Object {
        if ($_ -match 'PROJECT_ROOT=(.*)') {
            $env:PROJECT_ROOT = $matches[1].Trim('"')
        }
    }
} else {
    # Fallback: use script directory if .env not found
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $env:PROJECT_ROOT = $scriptDir
    Write-Host "No .env found. Using script directory as PROJECT_ROOT." -ForegroundColor Yellow
}

Write-Host "PROJECT_ROOT = $env:PROJECT_ROOT" -ForegroundColor Green

function Start-Setup {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0)]
        [switch]$Help,
        [Parameter()]
        [switch]$DryRun,
        [Parameter()]
        [switch]$RunSmokeTest,
        [Parameter()]
        [switch]$AutoAttach,
        [string]$BusId,
        [string]$DistroName,
        [switch]$GitCommit,
        [switch]$Force
    )

    Write-Host "Setup script started in mode: $($PSBoundParameters.Keys -join ', ')" -ForegroundColor Cyan
}

# Script giriş noktası
Start-Setup @args


# Set strict mode and UTF-8 encoding
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Initialize script variables
$script:ForceMode = $Force
$script:LogDirParam = $LogDir
$script:SuiteRoot = $PSScriptRoot
$script:ProjectRoot = Split-Path -Parent $script:SuiteRoot
$script:LogsRoot = if ($script:LogDirParam) { $script:LogDirParam } else { Join-Path $script:SuiteRoot 'logs' }
$script:RunId = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:RunLogDir = Join-Path $script:LogsRoot $script:RunId
$script:LogFile = Join-Path $script:RunLogDir 'setup.log'
$script:StateDir = Join-Path $script:SuiteRoot '.state'
$script:StateFile = Join-Path $script:StateDir 'setup.ok'

# Ensure required directories exist
$null = New-Item -Path $script:RunLogDir -ItemType Directory -Force -ErrorAction SilentlyContinue
$null = New-Item -Path $script:StateDir -ItemType Directory -Force -ErrorAction SilentlyContinue

function Show-Help {
    [CmdletBinding()]
    param()
    Write-Host "RTL8821CU WSL2 Fix Tool" -ForegroundColor Cyan
    Write-Host "Usage: .\setup.ps1 [-Help] [-DryRun] [-RunSmokeTest] [-AutoAttach] [-BusId <id>]"
    Write-Host "                     [-DistroName <name>] [-GitCommit] [-Force] [-LogDir <path>]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help           Show this help message"
    Write-Host "  -DryRun         Show what would happen without making changes"
    Write-Host "  -RunSmokeTest   Run non-destructive tests"
    Write-Host "  -AutoAttach     Automatically attach the specified USB device"
    Write-Host "  -BusId          USB device bus ID (required with -AutoAttach)"
    Write-Host "  -DistroName     Target WSL2 distribution name"
    Write-Host "  -GitCommit      Create a git commit after successful setup"
    Write-Host "  -Force          Skip confirmation prompts"
    Write-Host "  -LogDir         Custom log directory"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\setup.ps1 -RunSmokeTest -DistroName Ubuntu-22.04"
    Write-Host "  .\setup.ps1 -AutoAttach -BusId 1-5 -DistroName kali-linux -Force"
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [hashtable]$Data
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($Data) {
        $logEntry += " | " + ($Data.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
    }
    try {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "Failed to write to log file: $_" -ForegroundColor Red
    }
    switch ($Level) {
        'INFO'  { Write-Host $logEntry -ForegroundColor Green }
        'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'DEBUG' { Write-Host $logEntry -ForegroundColor Gray }
    }
}

function Test-Admin {
    [CmdletBinding()]
    param()
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Confirm-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [switch]$DefaultYes
    )
    if ($script:ForceMode -or -not [Environment]::UserInteractive) {
        Write-Log -Level 'INFO' -Message "Auto-confirmed: $Message"
        return $true
    }
    if ($DefaultYes) {
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Proceed with the action'),
            [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Skip this action')
        )
        $defaultChoice = 0
    } else {
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Skip this action'),
            [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Proceed with the action')
        )
        $defaultChoice = 0
    }
    $result = $Host.UI.PromptForChoice('Confirmation', $Message, $choices, $defaultChoice)
    $confirmed = if ($DefaultYes) { $result -eq 0 } else { $result -eq 1 }
    if ($confirmed) {
        Write-Log -Level 'INFO' -Message "User confirmed: $Message"
    } else {
        Write-Log -Level 'INFO' -Message "User declined: $Message"
    }
    return $confirmed
}

function Backup-File {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log -Level 'DEBUG' -Message "File not found for backup" -Data @{ Path = $Path }
        return $null
    }
    $backupDir = Join-Path $script:SuiteRoot 'setup_old_versions'
    $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction SilentlyContinue
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $backupDir "$(Split-Path -Leaf $Path).$timestamp"
    try {
        if ($PSCmdlet.ShouldProcess($Path, "Backup to $backupFile")) {
            Copy-Item -LiteralPath $Path -Destination $backupFile -Force -ErrorAction Stop
            Write-Log -Level 'INFO' -Message "Backup created" -Data @{ Source = $Path; Backup = $backupFile }
            return $backupFile
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Backup failed" -Data @{ Path = $Path; Error = $_.Exception.Message }
        return $null
    }
}

function Set-WSLKernel {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$KernelPath
    )
    $kernelPath = $KernelPath.Trim('"\')
    if (-not (Test-Path -LiteralPath $kernelPath)) {
        Write-Log -Level 'ERROR' -Message "Kernel file not found" -Data @{ Path = $kernelPath }
        return $false
    }
    $wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
    $backupFile = Backup-File -Path $wslConfig
    $configContent = @"
[wsl2]
kernel=$($kernelPath -replace '\\', '\\')
"@
    try {
        if ($PSCmdlet.ShouldProcess($wslConfig, "Update WSL kernel configuration")) {
            $configContent | Set-Content -Path $wslConfig -Encoding UTF8 -Force
            Write-Log -Level 'INFO' -Message "WSL kernel configuration updated" -Data @{ Config = $wslConfig; Kernel = $kernelPath }
            return $true
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to update WSL config" -Data @{ Error = $_.Exception.Message }
        return $false
    }
}

function Copy-Toolset {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DistroName
    )
    $requiredFiles = @('ai_helper.py', 'rtl8821cu_wsl_fix.sh')
    $sourceDir = $script:SuiteRoot
    $targetDir = "\\wsl$\$DistroName\home\$(wsl -d $DistroName whoami)\rtl8821cu"
    try {
        $null = New-Item -Path $targetDir -ItemType Directory -Force -ErrorAction Stop
        foreach ($file in $requiredFiles) {
            $source = Join-Path $sourceDir $file
            $target = Join-Path $targetDir $file
            if (Test-Path -LiteralPath $source) {
                if ($PSCmdlet.ShouldProcess($target, "Copy $file")) {
                    Copy-Item -Path $source -Destination $target -Force
                    Write-Log -Level 'INFO' -Message "Copied file" -Data @{ Source = $source; Target = $target }
                }
            } else {
                Write-Log -Level 'WARN' -Message "Required file not found" -Data @{ File = $source }
            }
        }
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Failed to copy toolset" -Data @{ Error = $_.Exception.Message }
        return $false
    }
}

function Show-WSL-RestartSteps {
    [CmdletBinding()]
    param()
    Write-Host ""
    Write-Host "WSL Restart Steps:" -ForegroundColor Cyan
    Write-Host "1. Shutdown WSL: wsl --shutdown" -ForegroundColor White
    Write-Host "2. Restart WSL: wsl -d $DistroName" -ForegroundColor White
    Write-Host "3. Verify in WSL: lsusb | grep -i realtek" -ForegroundColor White
    Write-Host ""
}

function Attach-RTL8821CU {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$AutoAttach,
        [string]$BusId,
        [string]$DistroName,
        [switch]$Force
    )
    
    # Check if usbipd is available
    if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
        Write-Log -Level 'ERROR' -Message "usbipd not found. Please install usbipd-win."
        return $false
    }

    # Enumerate and parse USB devices
    Write-Log -Level 'INFO' -Message "Scanning for USB devices..."
    $rawList = & usbipd.exe list | Select-String -Pattern '^[0-9-]+\s+[0-9a-f:]+\s+.+?(Shared|Attached|Not shared)$'
    $devices = foreach ($l in $rawList) {
        if ($l -match '^(?<BusId>[0-9-]+)\s+(?<VidPid>[0-9a-f:]+)\s+(?<Device>.+?)\s+(?<State>Shared|Attached|Not shared)$') {
            [PSCustomObject]@{
                BusId  = $matches['BusId']
                VidPid = $matches['VidPid']
                Device = $matches['Device'].Trim()
                State  = $matches['State']
            }
        }
    }

    if ($AutoAttach -or $Force) {
        try {
            # Auto-select Realtek device if BusId not specified
            if ([string]::IsNullOrEmpty($BusId)) {
                $target = $devices | Where-Object { $_.VidPid -match '0bda:c811' } | Select-Object -First 1
                if (-not $target) { throw 'No Realtek RTL8821CU device found. Please connect the adapter and try again.' }
                $BusId = $target.BusId
                Write-Log -Level 'INFO' -Message "Auto-selected Realtek device with BusId: $BusId" -Data @{Device = $target.Device}
            } else {
                $target = $devices | Where-Object { $_.BusId -eq $BusId } | Select-Object -First 1
                if (-not $target) { throw "Device with BusId $BusId not found in usbipd list." }
            }

            Write-Host "[INFO] Found device: $($target.Device) (BusId: $($target.BusId), State: $($target.State))" -ForegroundColor Cyan
            
            # Skip confirmation if -Force is used
            if (-not $Force -and -not $PSCmdlet.ShouldProcess("Attach $($target.BusId) to WSL")) {
                return $false
            }

            # Detach if already attached
            if ($target.State -eq 'Attached') {
                Write-Host "[INFO] Device already attached — detaching first..." -ForegroundColor Yellow
                & usbipd.exe detach --busid $BusId | Out-Null
                Start-Sleep -Seconds 2
            }

            # Attach to WSL
            Write-Host "[INFO] Attaching device $BusId to WSL..." -ForegroundColor Cyan
            $attachOut = & usbipd.exe attach --busid $BusId --wsl 2>&1 | Tee-Object -Variable attachOut
            
            if ($LASTEXITCODE -ne 0) {
                throw "Attach failed: $attachOut"
            }
            
            Write-Log -Level 'INFO' -Message "Device attached to WSL" -Data @{ 
                BusId = $target.BusId
                Device = $target.Device
                State = 'Attached'
                Output = $attachOut
            }
            
            # Verify in WSL if DistroName is provided
            if (-not [string]::IsNullOrEmpty($DistroName)) {
                Write-Host "[INFO] Verifying device in WSL ($DistroName)..." -ForegroundColor Cyan
                $check = & wsl.exe -d $DistroName -- bash -c "lsusb | grep -i 0bda:c811" 2>$null
                if ($check) {
                    Write-Host "[OK] Realtek adapter detected in WSL: $check" -ForegroundColor Green
                    Write-Log -Level 'INFO' -Message "Realtek device detected in WSL" -Data @{ Output = $check }
                } else {
                    Write-Warning "Adapter not visible in WSL yet — try replugging or restarting WSL."
                    Write-Log -Level 'WARN' -Message "Realtek device not yet visible in WSL"
                }
            }
            
            return $true
            
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "[ERROR] $errorMsg" -ForegroundColor Red
            Write-Log -Level 'ERROR' -Message "Failed to attach device" -Data @{ Error = $errorMsg }
            return $false
        }
    } else {
        # Interactive mode - show device list
        Write-Host "`nAvailable USB devices:" -ForegroundColor Cyan
        $realtekDevices = $devices | Where-Object { $_.VidPid -match '0bda:c811' }
        
        if ($realtekDevices) {
            Write-Host "`nRealtek RTL8821CU devices:" -ForegroundColor Green
            $realtekDevices | ForEach-Object {
                Write-Host ("  [{0}] {1,-8} {2,-12} {3} {4}" -f $_.BusId, $_.VidPid, $_.State, $_.Device) -ForegroundColor White
            }
        } else {
            Write-Host "`nNo Realtek RTL8821CU devices found." -ForegroundColor Yellow
        }
        
        $otherDevices = $devices | Where-Object { $_.VidPid -notmatch '0bda:c811' }
        if ($otherDevices) {
            Write-Host "`nOther USB devices:" -ForegroundColor Gray
            $otherDevices | ForEach-Object {
                Write-Host ("  [{0}] {1,-8} {2,-12} {3}" -f $_.BusId, $_.VidPid, $_.State, $_.Device) -ForegroundColor Gray
            }
        }
        
        Write-Host "`nTo attach a device, use: .\setup.ps1 -AutoAttach -BusId X-Y [-DistroName DISTRO]" -ForegroundColor Cyan
        return $true
    }
}

function Test-Environment {
    [CmdletBinding()]
    param()
    $results = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        IsAdmin = Test-Admin
        UsbipdInstalled = [bool](Get-Command usbipd -ErrorAction SilentlyContinue)
        WslInstalled = [bool](Get-Command wsl -ErrorAction SilentlyContinue)
        RobocopyAvailable = [bool](Get-Command robocopy -ErrorAction SilentlyContinue)
        RequiredFiles = @{}
    }
    $requiredFiles = @('ai_helper.py', 'rtl8821cu_wsl_fix.sh')
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $script:SuiteRoot $file
        $results.RequiredFiles[$file] = Test-Path -LiteralPath $filePath
    }
    Write-Log -Level 'INFO' -Message "Environment check" -Data $results
    return $results
}

function Run-SmokeTest {
    [CmdletBinding()]
    param()
    Write-Host "Running smoke tests..." -ForegroundColor Cyan
    $env = Test-Environment
    $allPassed = $true
    if (-not $env.IsAdmin) {
        Write-Host "  [WARN] Not running as administrator" -ForegroundColor Yellow
    }
    if (-not $env.UsbipdInstalled) {
        Write-Host "  [FAIL] usbipd not found" -ForegroundColor Red
        $allPassed = $false
    }
    if (-not $env.WslInstalled) {
        Write-Host "  [FAIL] WSL not installed" -ForegroundColor Red
        $allPassed = $false
    }
    foreach ($file in $env.RequiredFiles.GetEnumerator()) {
        if (-not $file.Value) {
            Write-Host "  [FAIL] Missing required file: $($file.Key)" -ForegroundColor Red
            $allPassed = $false
        }
    }
    if ($allPassed) {
        Write-Host "All smoke tests passed!" -ForegroundColor Green
    } else {
        Write-Host "Some smoke tests failed. Check the logs for details." -ForegroundColor Red
    }
    return $allPassed
}

function Invoke-GitCommit {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log -Level 'WARN' -Message "Git not found, skipping commit"
        return $false
    }
    try {
        Push-Location $script:SuiteRoot
        if (-not (Test-Path -Path '.git')) {
            git init | Out-Null
        }
        git add setup.ps1
        if ($PSCmdlet.ShouldProcess("Commit changes to git")) {
            git commit -m "feat(setup): unify setup.ps1 — generated by SWE-1; author Znuzhg Onyvxpv"
            Write-Log -Level 'INFO' -Message "Changes committed to git"
            return $true
        }
    } catch {
        Write-Log -Level 'ERROR' -Message "Git commit failed" -Data @{ Error = $_.Exception.Message }
        return $false
    } finally {
        Pop-Location
    }
}

function Validate-Syntax {
    [CmdletBinding()]
    param()
    # Get script path in a cross-version compatible way
    $scriptPath = if ($PSScriptRoot) {
        $PSScriptRoot
    } elseif ($MyInvocation.MyCommand -is [System.Management.Automation.CommandInfo]) {
        Split-Path -Parent $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
    } else {
        Split-Path -Parent $MyInvocation.InvocationName -ErrorAction SilentlyContinue
    }
    
    if (-not $scriptPath) {
        $scriptPath = $PWD.Path
    }
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
        Write-Log -Level 'INFO' -Message "Syntax validation passed"
        return $true
    } catch {
        Write-Log -Level 'ERROR' -Message "Syntax validation failed" -Data @{ Error = $_.Exception.Message }
        return $false
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

# Validate syntax before proceeding
if (-not (Validate-Syntax)) {
    exit 1
}

# Run smoke test if requested
if ($RunSmokeTest) {
    $success = Run-SmokeTest
    exit $(if ($success) { 0 } else { 1 })
}

# Check for admin rights if needed
if (-not (Test-Admin)) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Red
    exit 1
}

# Main logic
try {
    Write-Log -Level 'INFO' -Message "Starting RTL8821CU setup" -Data @{ Timestamp = Get-Date }
    
    if ($AutoAttach) {
        $attached = Attach-RTL8821CU -AutoAttach -BusId $BusId -DistroName $DistroName
        if (-not $attached) {
            throw "Failed to attach device"
        }
        Show-WSL-RestartSteps
    }
    
    if ($GitCommit) {
        $committed = Invoke-GitCommit
        if (-not $committed) {
            Write-Log -Level 'WARN' -Message "Git commit was not successful"
        }
    }
    
    Write-Log -Level 'INFO' -Message "Setup completed successfully"
    Write-Host "Setup completed successfully!" -ForegroundColor Green
    Write-Host "Log file: $($script:LogFile)" -ForegroundColor Cyan
    exit 0
} catch {
    Write-Log -Level 'ERROR' -Message "Setup failed" -Data @{ Error = $_.Exception.Message }
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

function Show-Help {
    [CmdletBinding()]
    param()
    Write-Host "setup.ps1 — Unified RTL8821CU WSL tooling (Author: Znuzhg Onyvxpv)" -ForegroundColor Cyan
    Write-Host "Parameters:" -ForegroundColor Gray
    Write-Host "  -DistroName <name>     Target WSL distro name"
    Write-Host "  -AutoAttach            Attach Realtek device via usbipd non-interactively"
    Write-Host "  -BusId <id>            BusId from 'usbipd wsl list' (e.g., 1-5)"
    Write-Host "  -KernelPath <path>     Set WSL2 kernel path in user's .wslconfig"
    Write-Host "  -RunSmokeTest          Run non-destructive checks"
    Write-Host "  -GitCommit             Create a safe git commit (no push)"
    Write-Host "  -DryRun                Alias of -WhatIf for previewing actions"
    Write-Host "  -WhatIf / -Confirm     Standard PowerShell safety switches"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\setup.ps1 -DistroName \"Ubuntu-22.04\""
    Write-Host "  .\setup.ps1 -AutoAttach -BusId \"1-5\" -DistroName \"Ubuntu-22.04\""
    Write-Host "  .\setup.ps1 -KernelPath \"C:\\WSL\\kernel\\vmlinux-wsl2\""
    Write-Host "  .\setup.ps1 -RunSmokeTest -DistroName \"Ubuntu-22.04\""
}

 # One-line: initialize global paths and logging
 function Initialize-Context {
   [CmdletBinding()]
   param()
   $script:SuiteRoot   = $PSScriptRoot
   $script:ProjectRoot = Split-Path -Parent $SuiteRoot
   $script:LogsRoot    = Join-Path $SuiteRoot 'logs'
   $script:RunId       = Get-Date -Format 'yyyyMMdd_HHmmss'
   $script:RunLogDir   = Join-Path $LogsRoot $RunId
   $null = New-Item -Path $RunLogDir -ItemType Directory -Force -ErrorAction SilentlyContinue
   $script:LogFile     = Join-Path $RunLogDir 'setup.log'
 }

 # One-line: write structured log line and colored console output
 function Write-Log {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)] [ValidateSet('INFO','WARN','ERROR','DEBUG')] [string]$Level,
     [Parameter(Mandatory)] [string]$Message,
     [hashtable]$Data
   )
   $entry = [ordered]@{
     timestamp = (Get-Date).ToString('s')
     level     = $Level
     message   = $Message
     data      = $Data
   }
   try { $entry | ConvertTo-Json -Compress | Add-Content -Path $script:LogFile -Encoding UTF8 } catch {}
   switch ($Level) {
     'INFO'  { Write-Host "[INFO]  $Message" -ForegroundColor Green }
     'WARN'  { Write-Host "[WARN]  $Message" -ForegroundColor Yellow }
     'ERROR' { Write-Host "[ERROR] $Message" -ForegroundColor Red }
     'DEBUG' { Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray }
   }
 }

 # One-line: return true if current PowerShell has admin rights
 function Test-Admin {
   [CmdletBinding()]
   param()
   try {
     $id  = [Security.Principal.WindowsIdentity]::GetCurrent()
     $pri = New-Object Security.Principal.WindowsPrincipal($id)
     return $pri.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
   } catch { return $false }
 }

 # One-line: safe confirmation prompt with optional default yes
 function Confirm-Action {
   [CmdletBinding()]
   param(
     [Parameter(Mandatory)][string]$Message,
     [switch]$DefaultYes
   )
   if ($WhatIfPreference) {
     Write-Log -Level 'INFO' -Message "WhatIf: $Message (skipped)"
     return $false
   }
   $caption = "Confirm"
   $prompt  = "$Message"
   if ($PSBoundParameters['DefaultYes']) {
     $choices = @(
       (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Proceed"),
       (New-Object System.Management.Automation.Host.ChoiceDescription "&No","Cancel")
     )
     $default = 0
   } else {
     $choices = @(
       (New-Object System.Management.Automation.Host.ChoiceDescription "&No","Cancel"),
       (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Proceed")
     )
     $default = 0
   }
   $selection = $Host.UI.PromptForChoice($caption, $prompt, $choices, $default)
   return ($selection -eq 0 -and $DefaultYes) -or ($selection -eq 1 -and -not $DefaultYes)
 }

 # One-line: normalize and quote a Windows path
 function Normalize-Path {
   [CmdletBinding()]
   param([Parameter(Mandatory)][string]$Path)
   try {
     $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
   } catch {
     $full = [System.IO.Path]::GetFullPath($Path)
   }
   return $full
 }

 # One-line: create timestamped backup for a file
 function Backup-File {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param([Parameter(Mandatory)][string]$Path)
   if (-not (Test-Path -LiteralPath $Path)) { return $null }
   $dir  = Split-Path -Parent $Path
   $name = Split-Path -Leaf $Path
   $ts   = Get-Date -Format 'yyyyMMdd_HHmmss'
   $bak  = Join-Path $dir "$name.bak.$ts"
   if ($PSCmdlet.ShouldProcess($Path, "Backup to $bak")) {
     Copy-Item -LiteralPath $Path -Destination $bak -Force
     Write-Log -Level 'INFO' -Message "Backed up $name" -Data @{ backup=$bak }
   }
   return $bak
 }

 # One-line: copy using robocopy when available else Copy-Item
 function Invoke-RobustCopy {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param(
     [Parameter(Mandatory)][string]$Source,
     [Parameter(Mandatory)][string]$Destination
   )
   $src = Normalize-Path $Source
   $dst = Normalize-Path $Destination
   if ($PSCmdlet.ShouldProcess("$src -> $dst", "Copy")) {
     if (Get-Command robocopy.exe -ErrorAction SilentlyContinue) {
       $dstParent = (Test-Path -LiteralPath $dst -PathType Container) ? $dst : (Split-Path -Parent $dst)
       $null = New-Item -Path $dstParent -ItemType Directory -Force -ErrorAction SilentlyContinue
       $args = @("`"$src`"", "`"$dst`"", "/E", "/COPY:DAT", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XO")
       $proc = Start-Process -FilePath robocopy.exe -ArgumentList $args -NoNewWindow -Wait -PassThru
       $code = $proc.ExitCode
       if ($code -ge 8) { throw "Robocopy failed with code $code" }
     } else {
       if (Test-Path -LiteralPath $src -PathType Container) {
         $null = New-Item -Path $dst -ItemType Directory -Force -ErrorAction SilentlyContinue
         Copy-Item -LiteralPath $src\* -Destination $dst -Recurse -Force -ErrorAction Stop
       } else {
         $null = New-Item -Path (Split-Path -Parent $dst) -ItemType Directory -Force -ErrorAction SilentlyContinue
         Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
       }
     }
     Write-Log -Level 'INFO' -Message "Copied $src -> $dst"
   }
 }

 # One-line: backup any existing setup*.ps1 into setup_old_versions folder
 function Backup-ExistingSetupScripts {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param()
   $backupDir = Join-Path $script:SuiteRoot 'setup_old_versions'
   $null = New-Item -Path $backupDir -ItemType Directory -Force -ErrorAction SilentlyContinue
   $current = $MyInvocation.MyCommand.Path
   Get-ChildItem -Path $script:SuiteRoot -Filter 'setup*.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object {
     if ($_.FullName -eq $current) { return }
     $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
     $dest = Join-Path $backupDir ("{0}.{1}" -f $_.Name, $ts)
     if ($PSCmdlet.ShouldProcess($_.FullName, "Archive to $dest")) {
       Copy-Item -LiteralPath $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
       Write-Log -Level 'INFO' -Message "Archived prior setup script" -Data @{ source=$_.FullName; dest=$dest }
     }
   }
 }

 # One-line: show WSL restart steps on Windows host
 function Show-WSL-RestartSteps {
   [CmdletBinding()]
   param()
   Write-Host ""
   Write-Host "WSL Restart Steps (Windows host):" -ForegroundColor Cyan
   Write-Host "  1) wsl --shutdown" -ForegroundColor Gray
   Write-Host "  2) Start your distro again (e.g., 'wsl -d $($DistroName)')" -ForegroundColor Gray
   Write-Host "  3) Verify inside WSL: lsusb | grep -i -E '0bda|realtek'" -ForegroundColor Gray
   Write-Host ""
 }
 Set-Alias -Name Show-WSL-Restart-Steps -Value Show-WSL-RestartSteps -ErrorAction SilentlyContinue

 # One-line: verify PowerShell/admin and tools; check WSL distro and key files
 function Test-Environment {
   [CmdletBinding()]
   param([string]$Distro)
   $ok = $true
   $psv = $PSVersionTable.PSVersion
   if ($psv.Major -lt 5) {
     Write-Log -Level 'ERROR' -Message "PowerShell 5.1+ required"
     $ok = $false
   } else {
     Write-Log -Level 'INFO' -Message "PowerShell $($psv.ToString()) detected"
   }
   if (-not (Test-Admin)) {
     Write-Log -Level 'WARN' -Message "Not running with Administrator privileges"
   } else {
     Write-Log -Level 'INFO' -Message "Administrator privileges detected"
   }
   foreach ($exe in @('usbipd.exe','wsl.exe','robocopy.exe','git.exe')) {
     if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
       Write-Log -Level 'WARN' -Message "$exe not found in PATH"
       if ($exe -in @('usbipd.exe','wsl.exe')) { $ok = $false }
     } else {
       Write-Log -Level 'INFO' -Message "$exe available"
     }
   }
   $files = @('ai_helper.py','rtl8821cu_wsl_fix.sh') | ForEach-Object { Join-Path $script:SuiteRoot $_ }
   foreach ($f in $files) {
     if (-not (Test-Path -LiteralPath $f)) {
       Write-Log -Level 'ERROR' -Message "Required file missing" -Data @{ path=$f }
       $ok = $false
     } else {
       Write-Log -Level 'INFO' -Message "Found file" -Data @{ path=$f }
     }
   }
   if ($Distro) {
     try {
       $distros = & wsl.exe -l -q 2>$null | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
       if (-not ($distros -contains $Distro)) {
         Write-Log -Level 'ERROR' -Message "WSL distro not found" -Data @{ distro=$Distro }
         $ok = $false
       } else {
         Write-Log -Level 'INFO' -Message "WSL distro found" -Data @{ distro=$Distro }
       }
     } catch {
       Write-Log -Level 'WARN' -Message "Failed to query WSL distros"
       $ok = $false
     }
   }
   return $ok
 }

 # One-line: install or repair missing tools (WSL features, usbipd, Git, pwsh7)
 function Install-MissingTools {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param()
   $isAdmin = Test-Admin
   if (-not $isAdmin) {
     Write-Log -Level 'WARN' -Message "Admin rights required for installations"
     Write-Host "Some installations need Administrator. Re-run PowerShell as Administrator." -ForegroundColor Yellow
     return
   }

   # Enable WSL features safely
   $features = @("Microsoft-Windows-Subsystem-Linux","VirtualMachinePlatform")
   foreach ($f in $features) {
     try {
       $curr = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue
       if ($null -eq $curr -or $curr.State -ne "Enabled") {
         if (Confirm-Action -Message "Enable Windows feature '$f'?" -DefaultYes) {
           if ($PSCmdlet.ShouldProcess($f, "Enable-WindowsOptionalFeature")) {
             Enable-WindowsOptionalFeature -Online -FeatureName $f -All -NoRestart | Out-Null
             Write-Log -Level 'INFO' -Message "Enabled feature" -Data @{ feature=$f }
           }
         }
       } else {
         Write-Log -Level 'INFO' -Message "Feature already enabled" -Data @{ feature=$f }
       }
     } catch { Write-Log -Level 'WARN' -Message "Feature enable failed" -Data @{ feature=$f; error="$($_.Exception.Message)" } }
   }

   # Install usbipd-win via winget with GitHub fallback
   if (-not (Get-Command usbipd.exe -ErrorAction SilentlyContinue)) {
     if (Confirm-Action -Message "Install usbipd-win via winget?" -DefaultYes) {
       try {
         if (Get-Command winget -ErrorAction SilentlyContinue) {
           if ($PSCmdlet.ShouldProcess("usbipd-win", "winget install dorssel.usbipd-win")) {
             winget install dorssel.usbipd-win -e --accept-source-agreements --accept-package-agreements -h | Out-Null
             Write-Log -Level 'INFO' -Message "usbipd-win installation attempted via winget"
           }
         } else {
           Write-Log -Level 'WARN' -Message "winget not found; trying GitHub MSI"
           $url = "https://github.com/dorssel/usbipd-win/releases/latest/download/usbipd-win_x64.msi"
           $msi = Join-Path $env:TEMP "usbipd-win.msi"
           Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
           $proc = Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
           if ($proc.ExitCode -ne 0) { throw "msiexec exit code $($proc.ExitCode)" }
           Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
           Write-Log -Level 'INFO' -Message "usbipd-win installation via MSI completed"
         }
       } catch {
         Write-Log -Level 'ERROR' -Message "usbipd-win installation failed" -Data @{ error="$($_.Exception.Message)" }
       }
     }
   } else {
     Write-Log -Level 'INFO' -Message "usbipd-win already installed"
   }

   # Start usbipd service if available
   try {
     $svc = Get-Service -Name 'usbipd' -ErrorAction SilentlyContinue
     if ($svc -and $svc.Status -ne 'Running') {
       Start-Service usbipd
       $svc.WaitForStatus('Running','00:00:10')
       Write-Log -Level 'INFO' -Message "usbipd service running"
     }
   } catch {
     Write-Log -Level 'WARN' -Message "usbipd service start failed" -Data @{ error="$($_.Exception.Message)" }
   }

   # Install Git via winget
   if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
     if (Confirm-Action -Message "Install Git via winget?" -DefaultYes) {
       try {
         if (Get-Command winget -ErrorAction SilentlyContinue) {
           if ($PSCmdlet.ShouldProcess("Git", "winget install Git.Git")) {
             winget install Git.Git -e --accept-source-agreements --accept-package-agreements -h | Out-Null
             Write-Log -Level 'INFO' -Message "Git installation attempted via winget"
           }
         } else {
           Write-Host "Install Git manually: https://git-scm.com/download/win" -ForegroundColor Yellow
         }
       } catch {
         Write-Log -Level 'WARN' -Message "Git install failed" -Data @{ error="$($_.Exception.Message)" }
       }
     }
   } else {
     Write-Log -Level 'INFO' -Message "Git already installed"
   }

   # Suggest PowerShell 7 install if missing
   if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
     Write-Log -Level 'WARN' -Message "PowerShell 7 not found"
     if (Confirm-Action -Message "Install PowerShell 7 via winget?" -DefaultYes) {
       try {
         if (Get-Command winget -ErrorAction SilentlyContinue) {
           if ($PSCmdlet.ShouldProcess("PowerShell", "winget install Microsoft.PowerShell")) {
             winget install Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements -h | Out-Null
             Write-Log -Level 'INFO' -Message "PowerShell 7 installation attempted"
           }
         } else {
           Write-Host "Install PowerShell 7 manually: https://aka.ms/powershell" -ForegroundColor Yellow
         }
       } catch {
         Write-Log -Level 'WARN' -Message "PowerShell 7 install failed" -Data @{ error="$($_.Exception.Message)" }
       }
     }
   } else {
     Write-Log -Level 'INFO' -Message "PowerShell 7 available"
   }
 }

 # One-line: set or update user's .wslconfig kernel path safely
 function Set-WSLKernel {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param([Parameter(Mandatory)][string]$Path)
   $kernel = Normalize-Path $Path
   if (-not (Test-Path -LiteralPath $kernel)) {
     Write-Log -Level 'ERROR' -Message "Kernel file not found" -Data @{ path=$kernel }
     throw "Kernel file not found: $kernel"
   }
   $wslcfg = Join-Path $env:USERPROFILE ".wslconfig"
   $current = ""
   if (Test-Path -LiteralPath $wslcfg) { $current = Get-Content -LiteralPath $wslcfg -Raw }
   $newContent = $null
   if ($current -match '^\s*\[wsl2\][\s\S]*?$') {
     if ($current -match '(?ms)^\s*\[wsl2\][\r\n]+(?:.*[\r\n])*?kernel\s*=\s*(.+)$') {
       $newContent = [Regex]::Replace($current, '(?ms)(^\s*\[wsl2\][\r\n]+(?:.*[\r\n])*?kernel\s*=\s*)(.+)$', "`$1$kernel")
     } else {
       $newContent = [Regex]::Replace($current, '(?ms)^\s*\[wsl2\]\s*$', "[wsl2]`r`nkernel=$kernel")
       if ($newContent -eq $current) { $newContent = $current.TrimEnd() + "`r`n`r`nkernel=$kernel" }
     }
   } else {
     $nl = if ($current) { "`r`n`r`n" } else { "" }
     $newContent = $current + $nl + "[wsl2]`r`nkernel=$kernel`r`n"
   }
   if (-not (Confirm-Action -Message "Update .wslconfig to use kernel:`n$kernel" -DefaultYes)) {
     Write-Log -Level 'INFO' -Message "User declined .wslconfig update"
     return
   }
   Backup-File -Path $wslcfg | Out-Null
   if ($PSCmdlet.ShouldProcess($wslcfg, "Write kernel path")) {
     $newContent | Set-Content -LiteralPath $wslcfg -Encoding UTF8
     Write-Log -Level 'INFO' -Message ".wslconfig updated" -Data @{ path=$wslcfg; kernel=$kernel }
   }
 }

 # One-line: copy helper files to WSL home folder or via base64 if UNC not accessible
 function Copy-Toolset {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param([string]$Distro)
   $files = @('ai_helper.py','rtl8821cu_wsl_fix.sh') | ForEach-Object { Join-Path $script:SuiteRoot $_ }
   foreach ($f in $files) {
     if (-not (Test-Path -LiteralPath $f)) { throw "Missing required file: $f" }
   }
   if (-not $Distro) {
     Write-Log -Level 'INFO' -Message "No distro provided, files remain on Windows" -Data @{ path=$script:SuiteRoot }
     return
   }
   $linuxUser = $null
   try {
     $linuxUser = (& wsl.exe -d $Distro -- sh -lc 'echo -n $USER' 2>$null)
     if (-not $linuxUser) { $linuxUser = "root" }
   } catch { $linuxUser = "root" }

   $wslShare = "\\wsl$\$Distro\home\$linuxUser\RTL8821CU_FixSuite"
   $usedUNC = $false
   try {
     $null = & wsl.exe -d $Distro -- sh -lc "mkdir -p ~/RTL8821CU_FixSuite && chmod -R 700 ~/RTL8821CU_FixSuite" 2>$null
     if (Test-Path -LiteralPath $wslShare) {
       foreach ($f in $files) {
         $dest = Join-Path $wslShare (Split-Path -Leaf $f)
         Invoke-RobustCopy -Source $f -Destination $dest
       }
       $usedUNC = $true
       Write-Log -Level 'INFO' -Message "Toolset copied via UNC" -Data @{ distro=$Distro; user=$linuxUser }
     }
   } catch {}
# --- Ensure WSL sees PROJECT_ROOT ---
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
  $wslProjectRoot = try { (wsl.exe wslpath -a -- "$($script:ProjectRoot)" 2>$null).Trim() } catch { $null }
} else {
  $wslProjectRoot = $null
}

if (-not $wslProjectRoot) {
  # Fallback to current windows user profile path if wslpath failed
  $wslProjectRoot = "/mnt/c/Users/$env:USERNAME"
  Write-Log -Level 'WARN' -Message "Fallback PROJECT_ROOT used: $wslProjectRoot"
}

$Env:PROJECT_ROOT = $wslProjectRoot
Write-Log -Level 'INFO' -Message "PROJECT_ROOT for WSL set to $Env:PROJECT_ROOT"

# Write a small .env inside the toolset so WSL-side scripts can source it
$escaped = $Env:PROJECT_ROOT -replace '"','\"'
$envCmd = "mkdir -p ~/RTL8821CU_FixSuite && printf 'export PROJECT_ROOT=\"%s\"\\n' '$escaped' > ~/RTL8821CU_FixSuite/.env && chmod 644 ~/RTL8821CU_FixSuite/.env"
& wsl.exe -d $Distro -- sh -lc $envCmd | Out-Null
Write-Log -Level 'INFO' -Message "Wrote .env to WSL toolset (PROJECT_ROOT exported)"

   if (-not $usedUNC) {
     foreach ($f in $files) {
       $content = Get-Content -LiteralPath $f -Raw -Encoding UTF8
       $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
       $fn = (Split-Path -Leaf $f)
       $cmd = "mkdir -p ~/RTL8821CU_FixSuite && echo '$b64' | base64 -d | (command -v dos2unix >/dev/null 2>&1 && dos2unix >/dev/null 2>&1 || cat) > ~/RTL8821CU_FixSuite/$fn && chmod +x ~/RTL8821CU_FixSuite/$fn"
       & wsl.exe -d $Distro -- sh -lc "$cmd" | Out-Null
     }
     Write-Log -Level 'INFO' -Message "Toolset copied via base64 injection" -Data @{ distro=$Distro; user=$linuxUser }
   }
 }

 # One-line: find usbipd.exe path or throw
 function Get-UsbipdPath {
   [CmdletBinding()]
   param()
   $cmd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
   if (-not $cmd) { throw "usbipd.exe not found in PATH" }
   return $cmd.Source
 }

 # One-line: parse 'usbipd wsl list' output into objects
 function Get-UsbipdDevices {
   [CmdletBinding()]
   param()
   $out = & usbipd.exe wsl list 2>$null
   if (-not $out -or $out.Count -eq 0) {
     $out = & usbipd.exe list 2>$null
   }
   if (-not $out) { return @() }
   $lines = $out | Where-Object { $_ -and -not ($_ -match 'BUSID\s+VID:PID') }
   $list = @()
   foreach ($line in $lines) {
     $trim = ($line -replace '\x1b\[[0-9;]*m','').Trim()
     if (-not $trim) { continue }
     $parts = $trim -split '\s{2,}'
     if ($parts.Count -lt 3) { continue }
     $bus   = $parts[0].Trim()
     $vidpid= $parts[1].Trim()
     $dev   = $parts[2].Trim()
     $state = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }
     $list += [pscustomobject]@{ BusId=$bus; VidPid=$vidpid; Device=$dev; State=$state }
   }
   return $list
 }

 # One-line: attach Realtek device to WSL and validate using lsusb
 function Attach-RTL8821CU {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param(
     [switch]$AutoAttach,
     [string]$BusId,
     [Parameter(Mandatory)][string]$Distro
   )
   $null = Get-UsbipdPath
   $devices = Get-UsbipdDevices
   if (-not $devices -or $devices.Count -eq 0) {
     Write-Log -Level 'ERROR' -Message "No USB devices listed by usbipd"
     throw "No devices found by usbipd"
   }
   $candidates = $devices | Where-Object { $_.VidPid -match '(?i)0bda' -or $_.Device -match '(?i)Realtek|802\.11|Wireless|Wi-?Fi|8821|8811' }
   if (-not $candidates -or $candidates.Count -eq 0) {
     Write-Log -Level 'WARN' -Message "No obvious Realtek candidates; showing all devices"
     $candidates = $devices
   }
   if ($AutoAttach) {
     if (-not $BusId) { throw "-AutoAttach requires -BusId" }
     $target = $candidates | Where-Object { $_.BusId -eq $BusId } | Select-Object -First 1
     if (-not $target) {
       Write-Log -Level 'WARN' -Message "Specified BusId not found in filter; falling back to full list" -Data @{ BusId=$BusId }
       $target = $devices | Where-Object { $_.BusId -eq $BusId } | Select-Object -First 1
     }
     if (-not $target) { throw "BusId $BusId not found" }
   } else {
     Write-Host ""
     Write-Host "Select device to attach:" -ForegroundColor Cyan
     $i = 0
     $candidates | ForEach-Object {
       $stateInfo = if ($_.State) { "($($_.State))" } else { "" }
       Write-Host ("  [{0}] {1} {2} {3} {4}" -f $i, $_.BusId, $_.VidPid, $_.Device, $stateInfo) -ForegroundColor Gray
       $i++
     }
     $sel = Read-Host "Enter index (0..$($candidates.Count-1))"
     if (-not [int]::TryParse($sel, [ref]$null)) { throw "Invalid selection" }
     $sel = [int]$sel
     if ($sel -lt 0 -or $sel -ge $candidates.Count) { throw "Selection out of range" }
     $target = $candidates[$sel]
     $BusId  = $target.BusId
   }
   Write-Log -Level 'INFO' -Message "Attaching device" -Data @{ BusId=$BusId; Distro=$Distro; Device=$target.Device }
   if ($PSCmdlet.ShouldProcess("BusId $BusId", "usbipd wsl attach to $Distro")) {
     $attachArgs = @('wsl','attach','--busid', $BusId, '--distribution', $Distro)
     $p = Start-Process -FilePath usbipd.exe -ArgumentList $attachArgs -NoNewWindow -Wait -PassThru
     if ($p.ExitCode -ne 0) {
       Write-Log -Level 'ERROR' -Message "usbipd attach failed" -Data @{ code=$p.ExitCode }
       throw "usbipd attach failed with code $($p.ExitCode)"
     }
   }
   Start-Sleep -Seconds 2
   try {
     $ls = & wsl.exe -d $Distro -- sh -lc "lsusb | grep -i -E '0bda|realtek' ; true" 2>$null
     if ($ls -and ($ls -match '(?i)realtek|0bda')) {
       Write-Log -Level 'INFO' -Message "Validation success: Realtek device visible in WSL" -Data @{ lsusb=$ls -join "`n" }
     } else {
       Write-Log -Level 'WARN' -Message "Validation inconclusive: lsusb did not show Realtek"
     }
   } catch {
     Write-Log -Level 'WARN' -Message "Validation failed to run lsusb" -Data @{ error="$($_.Exception.Message)" }
   }
 }

 # One-line: create or update .gitignore, stage, and commit changes safely
 function Invoke-GitCommit {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param()
   $git = Get-Command git.exe -ErrorAction SilentlyContinue
   if (-not $git) { Write-Log -Level 'WARN' -Message "git not found; skipping commit"; return }
   Push-Location $script:SuiteRoot
   try {
     if (-not (Test-Path -LiteralPath (Join-Path $script:SuiteRoot '.git'))) {
       if ($PSCmdlet.ShouldProcess($script:SuiteRoot, "git init")) {
         git init | Out-Null
         Write-Log -Level 'INFO' -Message "Initialized git repository"
       }
     }
     $gi = Join-Path $script:SuiteRoot '.gitignore'
     $ignoreLines = @("logs/", "setup_old_versions/")
     $existing = @()
     if (Test-Path -LiteralPath $gi) { $existing = Get-Content -LiteralPath $gi -ErrorAction SilentlyContinue }
     $new = @()
     foreach ($l in $ignoreLines) { if ($existing -notcontains $l) { $new += $l } }
     if ($new.Count -gt 0 -and $PSCmdlet.ShouldProcess($gi, "Update .gitignore")) {
       ($existing + $new) | Set-Content -LiteralPath $gi -Encoding UTF8
       Write-Log -Level 'INFO' -Message ".gitignore updated"
     }
     if ($PSCmdlet.ShouldProcess($script:SuiteRoot, "git add")) {
       git add .gitignore setup.ps1 2>$null | Out-Null
     }
     $hasName  = (git config --global user.name 2>$null)
     $hasEmail = (git config --global user.email 2>$null)
     if (-not $hasName -or -not $hasEmail) {
       Write-Log -Level 'WARN' -Message "Git global user.name/email not set; commit may fail"
       Write-Host "Set git identity:" -ForegroundColor Yellow
       Write-Host "  git config --global user.name \"Your Name\"" -ForegroundColor Gray
       Write-Host "  git config --global user.email \"you@example.com\"" -ForegroundColor Gray
       return
     }
     if ($PSCmdlet.ShouldProcess($script:SuiteRoot, "git commit")) {
       git commit -m "feat(setup): unified production setup.ps1 — generated by GPT-5 High (Author: Znuzhg Onyvxpv)" 2>$null | Out-Null
       Write-Log -Level 'INFO' -Message "Git commit created"
     }
   } catch {
     Write-Log -Level 'WARN' -Message "Git commit failed" -Data @{ error="$($_.Exception.Message)" }
   } finally {
     Pop-Location
   }
 }

 # One-line: run non-destructive checks and capture outputs
 function Run-SmokeTest {
   [CmdletBinding()]
   param([string]$Distro)
   $ok = Test-Environment -Distro $Distro
   try {
     $u = & usbipd.exe wsl list 2>$null
     if ($u) { Write-Log -Level 'INFO' -Message "usbipd wsl list output captured" }
   } catch { Write-Log -Level 'WARN' -Message "usbipd wsl list failed" }
   try {
     $v = & wsl.exe -l -v 2>$null
     if ($v) { Write-Log -Level 'INFO' -Message "wsl -l -v output captured" }
   } catch { Write-Log -Level 'WARN' -Message "wsl -l -v failed" }
   return $ok
 }

 # One-line: main routine orchestrating requested actions
 function Invoke-Main {
   [CmdletBinding(SupportsShouldProcess=$true)]
   param()
   if ($Help) { Show-Help; return 0 }
   if ($DryRun) { $script:WhatIfPreference = $true; $global:WhatIfPreference = $true }
   Initialize-Context
   Write-Log -Level 'INFO' -Message "Setup started" -Data @{ SuiteRoot=$script:SuiteRoot; RunId=$script:RunId }

   try {
     Backup-ExistingSetupScripts

     $envOk = Test-Environment -Distro $DistroName
     if (-not $envOk) {
       Write-Log -Level 'WARN' -Message "Environment checks reported issues; attempting Install-MissingTools"
       Install-MissingTools
     }

     if ($RunSmokeTest) {
       $ok = Run-SmokeTest -Distro $DistroName
       if ($ok) {
         Write-Log -Level 'INFO' -Message "Smoke test passed"
         Show-WSL-RestartSteps
         return 0
       } else {
         Write-Log -Level 'ERROR' -Message "Smoke test failed"
         return 3
       }
     }

     if ($KernelPath) {
       Set-WSLKernel -Path $KernelPath
       Write-Host "If kernel was updated, consider restarting WSL." -ForegroundColor Yellow
       Show-WSL-RestartSteps
     }

     if ($DistroName) {
       Copy-Toolset -Distro $DistroName
     } else {
       Write-Log -Level 'INFO' -Message "Skipping Copy-Toolset: no distro specified"
     }

     if ($AutoAttach) {
       if (-not $DistroName) { throw "-AutoAttach requires -DistroName" }
       if (-not $BusId)     { throw "-AutoAttach requires -BusId" }
       Attach-RTL8821CU -AutoAttach -BusId $BusId -Distro $DistroName
     } else {
       Write-Host ""
       Write-Host "usbipd guidance:" -ForegroundColor Cyan
       Write-Host "  1) List devices:   usbipd wsl list" -ForegroundColor Gray
       Write-Host "  2) Attach device:  usbipd wsl attach --busid <ID> --distribution \"$($DistroName)\"" -ForegroundColor Gray
       Write-Host "  3) Validate:       wsl -d \"$($DistroName)\" -- sh -lc 'lsusb | grep -i -E \"0bda|realtek\"'" -ForegroundColor Gray
       Write-Host ""
       Write-Host "Use -AutoAttach -BusId <ID> -DistroName \"$($DistroName)\" for non-interactive attach." -ForegroundColor DarkGray
     }

     if ($GitCommit) {
       Invoke-GitCommit
     }

     Write-Log -Level 'INFO' -Message "Setup completed successfully"
     Write-Host ""
     Write-Host "Setup completed successfully. To verify: open your WSL distro and run lsusb and ip link to confirm wlan0 is visible." -ForegroundColor Green
     Write-Host "Logs: $script:LogFile" -ForegroundColor Gray
     Write-Host "If kernel changed, run: wsl --shutdown" -ForegroundColor Gray
     Write-Host ""
     return 0
   } catch {
     Write-Log -Level 'ERROR' -Message "Unhandled error" -Data @{ error="$($_.Exception.Message)" }
     Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
     return 1
   }
 }

 if ($Help) { Show-Help; exit 0 }
 $exitCode = Invoke-Main
 exit $exitCode
