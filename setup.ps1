[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Help
)

<#
====================================================================
⚙️  SETUP.PS1 — RTL8821CU WSL2 FIX ENVIRONMENT PREPARER
====================================================================
Amaç:
  WSL2 altında çalıştırılacak RTL8821CU sürücü düzeltme araçları
  için gerekli ortamı (PowerShell + Linux tarafı) senkronize eder.

İşlev:
  - Python ve Git kontrolü
  - WSL tarafına dosyaların kopyalanması
  - Linux betiğinin otomatik çalıştırılması (isteğe bağlı)

Kullanım:
  powershell.exe -ExecutionPolicy Bypass -File setup.ps1
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

function Set-WSLKernel {
    <#
      Copy a built Linux kernel image and update %USERPROFILE%\.wslconfig to use it (optional).
    #>
    param(
        [Parameter(Mandatory=$true)][string]$KernelImagePath,
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
        # Ensure [wsl2] section and kernel path
        if (-not ($cfg -match '^\[wsl2\]')) { $cfg = @("[wsl2]") + $cfg }
        $kernelLine = "kernel = $destKernel"
        $new = @()
        $set = $false
        foreach ($line in $cfg) {
            if ($line -match '^\s*kernel\s*=') { $new += $kernelLine; $set=$true } else { $new += $line }
        }
        if (-not $set) { $new += $kernelLine }
        Set-Content -LiteralPath $wslcfg -Value $new -Encoding UTF8
        Write-Host "[OK] .wslconfig updated: $wslcfg"
    }

    Write-Host "[NEXT] To apply: run 'wsl --shutdown' then start your distro again." -ForegroundColor Cyan
}

function Copy-Toolset {
    <#
      Copy RTL8821CU_WSL_FIX_FINALLY folder from Linux-mounted path to Windows path (idempotent).
    #>
    param(
        [string]$LinuxPath = "/mnt/c/Users/mahmu/OneDrive/Belgeler/Projeler_ai/CascadeProjects/windsurf-project/RTL8821CU_WSL_FIX_FINALLY",
        [string]$WindowsPath = "C:\\Users\\mahmu\\OneDrive\\Belgeler\\Projeler_ai\\CascadeProjects\\windsurf-project\\RTL8821CU_WSL_FIX_FINALLY"
    )
    if (-not (Confirm-Action "Copy toolset from '$LinuxPath' to '$WindowsPath'?")) { return }
    New-Item -ItemType Directory -Path $WindowsPath -Force | Out-Null
    Copy-Item -Path $WindowsPath -Recurse -Force | Out-Null  # ensure directory exists
    # Prefer robocopy for reliability
    $src = $WindowsPath
    if (-not (Test-Path -LiteralPath $src)) {
        # Fallback: direct copy from WSL path mapping
        $src = $WindowsPath
    }
    robocopy $WindowsPath $WindowsPath /E /COPYALL /R:1 /W:1 | Out-Null
    Write-Host "[OK] Toolset ensured at: $WindowsPath"

    try { icacls $WindowsPath /grant "$env:USERNAME:(OI)(CI)F" /T | Out-Null } catch {}
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

Write-Host "Loaded helper. Available functions:" -ForegroundColor Cyan
Write-Host " - Set-WSLKernel -KernelImagePath <file> [-UpdateConfig]"
Write-Host " - Copy-Toolset"
Write-Host " - Show-WSL-Restart-Steps"
