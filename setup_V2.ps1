[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Help
)

<#
====================================================================
⚙️  SETUP.PS1 — RTL8821CU WSL2 FIX ENVIRONMENT PREPARER (FINAL)
====================================================================
Amaç:
  WSL2 ortamında RTL8821CU sürücüsünü düzeltmek için gerekli
  araçları (bash, python, kaynak kodlar) senkronize eder ve
  kullanıcıya yardımcı yönetim fonksiyonları sunar.

İşlevler:
  - Python ve Git varlığını kontrol eder
  - WSL tarafına gerekli dosyaları kopyalar
  - Kernel kopyalama ve .wslconfig yapılandırmasını sağlar
  - Ortamı idempotent şekilde hazırlar

Kullanım:
  powershell.exe -ExecutionPolicy Bypass -File setup.ps1
  .\setup.ps1 -Help

Örnekler:
  Set-WSLKernel -KernelImagePath "C:\path\to\vmlinuz" -UpdateConfig
  Copy-Toolset
  Show-WSL-Restart-Steps

Uyumluluk:
  - Windows PowerShell 5.1+
  - PowerShell 7+ (Core)
====================================================================
#>

Write-Host "Initializing RTL8821CU WSL2 environment setup..." -ForegroundColor Cyan

function Confirm-Action([string]$Message) {
    Write-Host "[CONFIRM] $Message" -ForegroundColor Yellow
    $c = Read-Host "Type YES to proceed"
    return ($c -eq 'YES')
}

function Backup-File([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
        $bak = "$Path.bak.$ts"
        Copy-Item -LiteralPath $Path -Destination $bak -Force
        Write-Host "[INFO] Backup created: $bak"
        return $bak
    }
}

function Ensure-PythonAndGit {
    Write-Host "[CHECK] Verifying Python and Git installation..."
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "[WARN] Python3 not found. Please install from Microsoft Store or python.org." -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Python found at: $($python.Source)"
    }
    if (-not $git) {
        Write-Host "[WARN] Git not found. Please install from https://git-scm.com/downloads" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Git found at: $($git.Source)"
    }
}

function Set-WSLKernel {
    <#
      Copy a built Linux kernel image and update %USERPROFILE%\.wslconfig to use it (optional).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$KernelImagePath,
        [string]$Destination = "$env:USERPROFILE\\.wsl-kernels",
        [switch]$UpdateConfig
    )
    if (-not (Test-Path -LiteralPath $KernelImagePath)) {
        throw "Kernel image not found: $KernelImagePath"
    }
    if (-not (Confirm-Action "Copy kernel to '$Destination' and optionally update .wslconfig?")) { return }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $destKernel = Join-Path $Destination (Split-Path $KernelImagePath -Leaf)
    Copy-Item -LiteralPath $KernelImagePath -Destination $destKernel -Force
    Write-Host "[OK] Kernel copied to: $destKernel"

    if ($UpdateConfig) {
        $wslcfg = Join-Path $env:USERPROFILE ".wslconfig"
        Backup-File $wslcfg | Out-Null
        $cfg = @()
        if (Test-Path -LiteralPath $wslcfg) { $cfg = Get-Content -LiteralPath $wslcfg -ErrorAction SilentlyContinue }
        if (-not ($cfg -match '^\[wsl2\]')) { $cfg = @("[wsl2]") + $cfg }
        $kernelLine = "kernel = $destKernel"
        $new = @()
        $set = $false
        foreach ($line in $cfg) {
            if ($line -match '^\s*kernel\s*=') { $new += $kernelLine; $set = $true } else { $new += $line }
        }
        if (-not $set) { $new += $kernelLine }
        Set-Content -LiteralPath $wslcfg -Value $new -Encoding UTF8
        Write-Host "[OK] .wslconfig updated: $wslcfg"
    }

    Write-Host "[NEXT] To apply: run 'wsl --shutdown' then start your distro again." -ForegroundColor Cyan
}

function Copy-Toolset {
    <#
      Copy RTL8821CU_WSL_FIX toolset from Windows path to ensure latest scripts exist.
    #>
    param(
        [string]$Source = "C:\\Users\\mahmu\\OneDrive\\Belgeler\\Projeler_ai\\CascadeProjects\\windsurf-project\\RTL8821CU_WSL_FIX_FINALLY",
        [string]$Destination = "C:\\Users\\mahmu\\OneDrive\\Belgeler\\Projeler_ai\\CascadeProjects\\windsurf-project\\RTL_FIX_ALL"
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Host "[ERROR] Source path not found: $Source" -ForegroundColor Red
        return
    }

    if (-not (Confirm-Action "Copy toolset from '$Source' to '$Destination'?")) { return }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Write-Host "[INFO] Copying toolset, please wait..."
    robocopy $Source $Destination /E /COPYALL /R:1 /W:1 | Out-Null
    Write-Host "[OK] Toolset ensured at: $Destination"

    try {
        icacls $Destination /grant "$env:USERNAME:(OI)(CI)F" /T | Out-Null
    } catch {
        Write-Host "[WARN] Permission adjustment failed or not required."
    }
}

function Show-WSL-Restart-Steps {
    Write-Host "[STEPS] Restart WSL:" -ForegroundColor Green
    Write-Host "1) Close all WSL terminals"
    Write-Host "2) Run: wsl --shutdown"
    Write-Host "3) Launch your distro again"
}

if ($Help) {
    Write-Host "Usage examples:" -ForegroundColor Cyan
    Write-Host "  Set-WSLKernel -KernelImagePath C:\\path\\to\\vmlinuz -UpdateConfig"
    Write-Host "  Copy-Toolset"
    Write-Host "  Show-WSL-Restart-Steps"
    exit 0
}

# === Main Execution ===
Ensure-PythonAndGit
Write-Host ""
Write-Host "Loaded helper. Available functions:" -ForegroundColor Cyan
Write-Host " - Set-WSLKernel -KernelImagePath <file> [-UpdateConfig]"
Write-Host " - Copy-Toolset"
Write-Host " - Show-WSL-Restart-Steps"
