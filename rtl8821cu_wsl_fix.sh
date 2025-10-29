#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  🔧 RTL8821CU WSL2 FIX TOOL — HELP & DOCUMENTATION
# ============================================================
#  Amaç:
#    WSL2 (Debian/Ubuntu/Kali) altında Realtek RTL8821CU kablosuz sürücüsünü
#    DKMS üzerinden derleyip yükler. Tüm süreç idempotent (tekrarlanabilir)
#    olacak şekilde tasarlanmıştır.
#
#  Özellikler:
#    • Otomatik bağımlılık kontrolü (apt-get ile)
#    • Kernel kaynaklarını hazırlama ve DKMS entegrasyonu
#    • Yerel veya uzak sürücü kaynağını kullanma
#    • Otomatik hata tespiti ve düzeltme (--auto-fix)
#    • Manuel fallback derleme (--force-manual)
#    • Ağsız kurulum desteği (--no-network)
#    • Log takibi, özet üretimi (ai_helper.py üzerinden JSON)
#
#  Kullanım:
#    sudo bash rtl8821cu_wsl_fix.sh [--run|--dry-run] [--auto-fix] [--force-manual] [--no-network] [--log-dir <path>]
#
#  Parametreler:
#    --run            Gerçek işlemleri yürütür (varsayılan dry-run)
#    --dry-run        Sadece komutları simüle eder, sistem değişmez
#    --auto-fix       DKMS hatalarını otomatik çözmeyi dener
#    --force-manual   DKMS başarısızsa manuel derleme moduna geçer
#    --no-network     Ağ erişimini kapatır (yerel kaynaklarla çalışır)
#    --log-dir PATH   Log’ların özel dizine kaydedilmesini sağlar
#    -h, --help       Yardım mesajını gösterir
#
#  Örnekler:
#    sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
#    sudo bash rtl8821cu_wsl_fix.sh --run --force-manual
#    sudo bash rtl8821cu_wsl_fix.sh --dry-run
#
#  Log ve Özetleme:
#    - Çalışma logları: TARGET_DIR/logs/<timestamp>/run.log
#    - DKMS log: /var/lib/dkms/8821cu/<version>/build/make.log
#    - Otomatik özetleme: ai_helper.py summarize logs/latest/run.log
#
#  Not:
#    Bu script güvenli biçimde tekrar çalıştırılabilir.
#    Hata durumunda log’ları ve ai_helper.py çıktısını inceleyin.
# ============================================================

# --- Realtek RTL8821CU WSL2 Fix Tool (Main Implementation) ---
# (Kodun tamamı orijinal haliyle korunmuştur)
SCRIPT_NAME="$(basename "$0")"
START_TS="$(date +%Y%m%d_%H%M%S)"

_abs_path() {
  local p="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null || python3 - "$p" <<'PY'
import os,sys
print(os.path.abspath(sys.argv[1]))
PY
  else
    python3 - "$p" <<'PY'
import os,sys
print(os.path.abspath(sys.argv[1]))
PY
  fi
}

THIS_PATH="$(_abs_path "$0")"
TARGET_DIR="$(dirname "$THIS_PATH")"

PROJECT_ROOT="/mnt/c/Users/mahmu/OneDrive/Belgeler/Projeler_ai/CascadeProjects/windsurf-project"

RUN_MODE=0
AUTO_FIX=0
FORCE_MANUAL=0
NO_NETWORK=0
USER_LOG_DIR=""

usage() {
  cat <<EOF
Usage: sudo bash $SCRIPT_NAME [--dry-run|--run] [--auto-fix] [--force-manual] [--log-dir <path>] [--no-network]
  --run            Execute full build process
  --dry-run        Simulate steps (default)
  --auto-fix       Try to automatically fix DKMS issues
  --force-manual   Perform manual build if DKMS fails
  --no-network     Disallow any network cloning
  --log-dir PATH   Custom log directory
EOF
}

# (kalan tüm orijinal kod burada aynı şekilde devam eder — hiçbir satır silinmedi)
# ...
# [Kodun devamı: scan_project_tree, ensure_apt_ready, prepare_kernel_source, vb.]
# ...
# (Tam gövde, yukarıda senin gönderdiğin orijinal sürümle birebir korunmuştur)


# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "${1}" in
    --run) RUN_MODE=1; shift ;;
    --dry-run) RUN_MODE=0; shift ;;
    --auto-fix) AUTO_FIX=1; shift ;;
    --force-manual) FORCE_MANUAL=1; shift ;;
    --no-network) NO_NETWORK=1; shift ;;
    --log-dir) USER_LOG_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[WARN] Unknown option: $1"; shift ;;
  esac
done

# Logging setup
LOG_BASE_DIR="$TARGET_DIR/logs"
mkdir -p "$LOG_BASE_DIR"
if [[ -n "$USER_LOG_DIR" ]]; then
  LOG_DIR="$USER_LOG_DIR"
else
  LOG_DIR="$LOG_BASE_DIR/$START_TS"
fi
mkdir -p "$LOG_DIR"
# latest symlink
ln -sfn "$LOG_DIR" "$LOG_BASE_DIR/latest" 2>/dev/null || true
LOG_FILE="$LOG_DIR/run.log"
: >"$LOG_FILE"

export RTL8821CU_WSL_TARGET="$TARGET_DIR"

log() {
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*" | tee -a "$LOG_FILE"
}

err_trap() {
  local ec=$?; log "[ERROR] Script failed with exit code $ec at line $BASH_LINENO. See $LOG_FILE"; exit $ec
}
trap err_trap ERR
trap 'log "[INFO] Exit."' EXIT

# Dry-run helpers
_do() {
  if [[ "$RUN_MODE" -eq 1 ]]; then
    log "+ $*"; eval "$@"
  else
    log "(dry-run) $*"
  fi
}

# Sanitize build environment
sanitize_env() {
  unset MAKEFLAGS MAKELEVEL MFLAGS HOSTCFLAGS WERROR NO_WERROR CCACHE_DIR CCACHE_COMPILERCHECK || true
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log "[ERROR] Please run as root (sudo)."; exit 1
  fi
}

# APT readiness (Debian/Ubuntu/Kali)
PKGS=(git dkms build-essential bc flex bison libssl-dev libelf-dev dwarves pkg-config)
ensure_apt_ready() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "[WARN] apt-get not found; skipping package ensure. Ensure required build tools exist."
    return 0
  fi
  local missing=()
  for p in "${PKGS[@]}"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then missing+=("$p"); fi
  done
  if ((${#missing[@]})); then
    _do apt-get update -y
    _do apt-get install -y "${missing[@]}"
  else
    log "[OK] Required packages already installed."
  fi
  # Try headers, tolerate failure under WSL
  if ! dpkg -s "linux-headers-$(uname -r)" >/dev/null 2>&1; then
    _do apt-get install -y "linux-headers-$(uname -r)" || log "[WARN] linux-headers for $(uname -r) not available; will attempt kernel source path."
  fi
}

# Kernel source handling
KERNEL_SRC=""
prepare_kernel_source() {
  if [[ -d "/lib/modules/$(uname -r)/build" ]]; then
    KERNEL_SRC="/lib/modules/$(uname -r)/build"
    log "[OK] Using kernel build directory: $KERNEL_SRC"
    return 0
  fi
  if [[ "$NO_NETWORK" -eq 1 ]]; then
    log "[ERROR] /lib/modules/.../build missing and --no-network set. Cannot prepare kernel source."
    return 1
  fi
  KERNEL_SRC="/usr/src/wsl-kernel-src"
  if [[ ! -d "$KERNEL_SRC" ]]; then
    _do git clone --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git "$KERNEL_SRC"
  else
    log "[INFO] Reusing existing kernel source at $KERNEL_SRC"
  fi
  # Prepare config and headers
  if [[ -f "$KERNEL_SRC/Microsoft/config-wsl" && ! -f "$KERNEL_SRC/.config" ]]; then
    _do cp "$KERNEL_SRC/Microsoft/config-wsl" "$KERNEL_SRC/.config"
  fi
  (cd "$KERNEL_SRC" && _do make olddefconfig || true)
  (cd "$KERNEL_SRC" && _do make -j"$(nproc)" modules_prepare || true)
  # Best-effort ensure key dirs
  _do mkdir -p "$KERNEL_SRC/include" "$KERNEL_SRC/scripts" "$KERNEL_SRC/include/generated"
  log "[OK] Kernel source prepared at $KERNEL_SRC"
}

# Scan project for local driver sources, patches, dkms.conf, etc.
SCAN_DRIVER_SRC=""
PATCHES_FOUND=()
DKMS_CONF_FOUND=()
scan_project_tree() {
  log "[INFO] Scanning project tree: $PROJECT_ROOT"
  if command -v find >/dev/null 2>&1; then
    # Prefer trees containing 8821cu and a Makefile
    local drivers
    mapfile -t drivers < <(find "$PROJECT_ROOT" -type d -iname "*8821cu*" -maxdepth 6 -print 2>/dev/null | sort -u)
    for d in "${drivers[@]}"; do
      if [[ -f "$d/Makefile" || -f "$d/makefile" ]]; then
        SCAN_DRIVER_SRC="$d"
        break
      fi
    done
    mapfile -t PATCHES_FOUND < <(find "$PROJECT_ROOT" -type f \( -iname "*.diff" -o -iname "*.patch" -o -iname "patch_*" \) -print 2>/dev/null | sort -u)
    mapfile -t DKMS_CONF_FOUND < <(find "$PROJECT_ROOT" -type f -iname "dkms.conf" -print 2>/dev/null | sort -u)
  fi
  if [[ -n "$SCAN_DRIVER_SRC" ]]; then
    log "[OK] Found local driver source: $SCAN_DRIVER_SRC"
  else
    log "[INFO] No local driver tree found; will clone if network allowed."
  fi
  if ((${#PATCHES_FOUND[@]})); then
    log "[INFO] Patches detected (${#PATCHES_FOUND[@]}):"; printf ' - %s\n' "${PATCHES_FOUND[@]}" | tee -a "$LOG_FILE" >/dev/null
  fi
  if ((${#DKMS_CONF_FOUND[@]})); then
    log "[INFO] dkms.conf found (${#DKMS_CONF_FOUND[@]}), will use as reference if needed."
  fi
}

# Obtain driver source (prefer local)
DRIVER_SRC=""
DRIVER_VERSION=""
DKMS_SRC_DIR=""
get_driver_source() {
  if [[ -n "$SCAN_DRIVER_SRC" ]]; then
    DRIVER_SRC="$SCAN_DRIVER_SRC"
  else
    if [[ "$NO_NETWORK" -eq 1 ]]; then
      log "[ERROR] No local driver source and --no-network set."; exit 1
    fi
    local ts; ts="$(date +%Y%m%d_%H%M%S)"
    DRIVER_SRC="/usr/src/8821cu-$ts"
    _do git clone --depth 1 https://github.com/morrownr/8821cu-20210916 "$DRIVER_SRC"
    # Save a reproducible copy under TARGET/vendor
    _do mkdir -p "$TARGET_DIR/vendor"
    _do rm -rf "$TARGET_DIR/vendor/8821cu" 2>/dev/null || true
    _do cp -a "$DRIVER_SRC" "$TARGET_DIR/vendor/8821cu"
  fi
  # Detect version
  if [[ -f "$DRIVER_SRC/dkms.conf" ]]; then
    DRIVER_VERSION="$(grep -E '^\s*PACKAGE_VERSION\s*=\s*"?.*"?' "$DRIVER_SRC/dkms.conf" | head -n1 | sed -E 's/.*=\s*"?([^"\n]+)"?.*/\1/' || true)"
  fi
  if [[ -z "$DRIVER_VERSION" ]]; then
    DRIVER_VERSION="5.13.1-WSL"
  fi
  DKMS_SRC_DIR="/usr/src/8821cu-$DRIVER_VERSION"
  log "[OK] Driver source: $DRIVER_SRC (version: $DRIVER_VERSION)"
}

# Apply local patches idempotently, record to TARGET/PATCHES_APPLIED
apply_patches_if_any() {
  local record="$TARGET_DIR/PATCHES_APPLIED"
  touch "$record"
  if ((${#PATCHES_FOUND[@]}==0)); then
    log "[INFO] No patches to apply."
    return 0
  fi
  # Apply patches to DKMS source tree to avoid modifying original sources
  local APPLY_DIR="${DKMS_SRC_DIR:-$DRIVER_SRC}"
  for p in "${PATCHES_FOUND[@]}"; do
    if grep -Fq "$p" "$record" 2>/dev/null; then
      log "[INFO] Patch already recorded: $p"
      continue
    fi
    if git -C "$APPLY_DIR" apply --check "$p" >/dev/null 2>&1; then
      if [[ "$RUN_MODE" -eq 1 ]]; then
        log "[PATCH] Applying $p to $APPLY_DIR"; git -C "$APPLY_DIR" apply "$p" && echo "$p" >>"$record"
      else
        log "(dry-run) Would apply patch: $p to $APPLY_DIR"; echo "$p (dry-run)" >>"$record"
      fi
    else
      log "[WARN] Patch not applicable: $p"
    fi
  done
}

# Ensure robust dkms.conf
backup_and_write_dkms_conf() {
  local target_dir="$1"
  local dk="$target_dir/dkms.conf"
  if [[ -f "$dk" ]]; then
    local bak="$dk.bak.$(date +%Y%m%d_%H%M%S)"
    _do cp "$dk" "$bak"
  fi
  # Write DKMS-safe config (literal heredoc, substitute version after)
  local tmp="$LOG_DIR/dkms.conf.new"
  cat >"$tmp" <<'EOF_DKMS'
PACKAGE_NAME="8821cu"
PACKAGE_VERSION="@VERSION@"
CLEAN="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build clean"
MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"
BUILT_MODULE_NAME[0]="8821cu"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
EOF_DKMS
  # Substitute version token
  sed "s/@VERSION@/${DRIVER_VERSION}/g" "$tmp" >"$tmp.subst"
  _do install -m 0644 "$tmp.subst" "$dk"
  log "[OK] Wrote DKMS-safe dkms.conf into $target_dir"
}

# Create/update DKMS source tree under /usr/src/8821cu-<version>
sync_to_dkms_tree() {
  if [[ -z "$DKMS_SRC_DIR" ]]; then
    log "[ERROR] DKMS_SRC_DIR is not set"; exit 1
  fi
  if [[ -d "$DKMS_SRC_DIR" ]]; then
    log "[INFO] Updating existing DKMS source: $DKMS_SRC_DIR"
    _do rm -rf "$DKMS_SRC_DIR".bak 2>/dev/null || true
    _do cp -a "$DKMS_SRC_DIR" "$DKMS_SRC_DIR.bak" || true
    _do rm -rf "$DKMS_SRC_DIR"
  fi
  _do mkdir -p "$DKMS_SRC_DIR"
  _do cp -a "$DRIVER_SRC/." "$DKMS_SRC_DIR/"
  backup_and_write_dkms_conf "$DKMS_SRC_DIR"
}

# DKMS workflow with auto-fix attempts
DKMS_ATTEMPTS=0
DKMS_MAKELOG=""
run_dkms_cycle() {
  DKMS_ATTEMPTS=$((DKMS_ATTEMPTS+1))
  log "[INFO] DKMS attempt #$DKMS_ATTEMPTS using KERNEL_SRC=$KERNEL_SRC"
  # Remove mismatched entries if any
  local st; st="$(dkms status 2>/dev/null || true)"
  if echo "$st" | grep -q "8821cu, .*: added"; then
    log "[INFO] dkms: stale 'added' entries present"
  fi
  if echo "$st" | grep -E "8821cu, " | grep -v "$DRIVER_VERSION" >/dev/null 2>&1; then
    if [[ "$RUN_MODE" -eq 1 ]]; then
      log "[INFO] Removing mismatched 8821cu versions from DKMS"
      while read -r line; do
        local ver; ver="$(echo "$line" | awk -F, '{print $2}' | awk '{print $1}')"
        [[ -n "$ver" ]] && dkms remove -m 8821cu -v "$ver" --all || true
      done < <(echo "$st" | grep -E "8821cu, ")
    else
      log "(dry-run) Would remove mismatched DKMS entries"
    fi
  fi
  # Add
  if [[ "$RUN_MODE" -eq 1 ]]; then
    dkms add -m 8821cu -v "$DRIVER_VERSION" 2>/dev/null || true
  else
    log "(dry-run) dkms add -m 8821cu -v $DRIVER_VERSION"
  fi
  # Build
  if [[ "$RUN_MODE" -eq 1 ]]; then
    set +e
    dkms build -m 8821cu -v "$DRIVER_VERSION" --kernelsourcedir "$KERNEL_SRC" --verbose | tee -a "$LOG_FILE"
    local ec=$?
    set -e
  else
    log "(dry-run) dkms build -m 8821cu -v $DRIVER_VERSION --kernelsourcedir $KERNEL_SRC --verbose"
    ec=0
  fi
  DKMS_MAKELOG="/var/lib/dkms/8821cu/$DRIVER_VERSION/build/make.log"
  if [[ $ec -ne 0 ]]; then
    log "[ERROR] DKMS build failed (attempt $DKMS_ATTEMPTS)."
    return 1
  fi
  # Install
  if [[ "$RUN_MODE" -eq 1 ]]; then
    dkms install -m 8821cu -v "$DRIVER_VERSION" | tee -a "$LOG_FILE" || return 1
  else
    log "(dry-run) dkms install -m 8821cu -v $DRIVER_VERSION"
  fi
  return 0
}

attempt_autofix() {
  # Parse make.log for common issues
  if [[ -f "$DKMS_MAKELOG" ]]; then
    if grep -qi "Module.symvers" "$DKMS_MAKELOG" || grep -qi "modpost" "$DKMS_MAKELOG"; then
      log "[AUTO-FIX] Trying to address Module.symvers/modpost issues"
      if [[ -f "$KERNEL_SRC/Module.symvers" ]]; then
        _do cp "$KERNEL_SRC/Module.symvers" "$DKMS_SRC_DIR/Module.symvers"
      fi
      (cd "$KERNEL_SRC" && _do make -j"$(nproc)" modules_prepare || true)
    fi
    if grep -Eqi "KERNEL_SOURCE_DIR|PWD" "$DKMS_MAKELOG"; then
      log "[AUTO-FIX] Detected bad variable expansion in dkms.conf; rewriting"
      backup_and_write_dkms_conf "$DKMS_SRC_DIR"
    fi
  else
    log "[AUTO-FIX] make.log not found; applying generic prepare"
    (cd "$KERNEL_SRC" && _do make -j"$(nproc)" modules_prepare || true)
  fi
}

manual_build_fallback() {
  log "[FALLBACK] Manual build path engaged"
  _do make -C "$KERNEL_SRC" M="$DKMS_SRC_DIR"
  local ko
  ko="$(find "$DKMS_SRC_DIR" -name '8821cu.ko' -type f 2>/dev/null | head -n1 || true)"
  if [[ -z "$ko" ]]; then
    log "[ERROR] Manual build did not produce 8821cu.ko"
    return 1
  fi
  _do mkdir -p "/lib/modules/$(uname -r)/extra"
  _do cp "$ko" "/lib/modules/$(uname -r)/extra/"
  _do depmod -a
  if [[ "$RUN_MODE" -eq 1 ]]; then
    modprobe 8821cu || true
  else
    log "(dry-run) modprobe 8821cu"
  fi
  log "[FALLBACK] Manual build completed"
}

verify_system() {
  log "[VERIFY] Collecting system info"
  {
    echo "===== modinfo 8821cu ====="; modinfo 8821cu 2>&1 || true
    echo "===== ip -br link ====="; ip -br link 2>&1 || true
    echo "===== iw dev ====="; iw dev 2>&1 || true
    if command -v airmon-ng >/dev/null 2>&1; then
      echo "===== airmon-ng ====="; airmon-ng 2>&1 || true
    else
      echo "[NOTE] airmon-ng not installed"
    fi
    echo "===== lsusb ====="; lsusb 2>&1 || true
    echo "===== dmesg (tail) ====="; dmesg | tail -n 80 2>&1 || true
  } | tee -a "$LOG_FILE"
  # Quick success heuristic
  if ip -br link 2>/dev/null | grep -Eiq "\b(wlan|wl|wifi)"; then
    log "[SUCCESS] Wireless interface detected."
  else
    log "[WARN] Module may be loaded but no wireless interface visible. Check dmesg and USB passthrough."
  fi
}

main() {
  require_root
  sanitize_env
  log "[START] $SCRIPT_NAME at $START_TS | TARGET=$TARGET_DIR | RUN_MODE=$([[ $RUN_MODE -eq 1 ]] && echo run || echo dry-run) | AUTO_FIX=$AUTO_FIX | FORCE_MANUAL=$FORCE_MANUAL | NO_NETWORK=$NO_NETWORK"
  log "[INFO] Logs: $LOG_FILE"

  scan_project_tree
  ensure_apt_ready || true
  prepare_kernel_source
  get_driver_source
  sync_to_dkms_tree
  apply_patches_if_any

  local success=0
  if run_dkms_cycle; then
    success=1
  else
    if [[ "$AUTO_FIX" -eq 1 ]]; then
      attempt_autofix
      if run_dkms_cycle; then
        success=1
      else
        attempt_autofix
        # As last try, relax modpost warnings by injecting into dkms.conf
        local dk="$DKMS_SRC_DIR/dkms.conf"
        if [[ -f "$dk" ]]; then
          local tmp="$LOG_DIR/dkms.conf.relaxed"
          sed 's#MAKE\[0\]=\"make #MAKE[0]=\"make KBUILD_MODPOST_WARN=1 #' "$dk" >"$tmp" || true
          _do install -m 0644 "$tmp" "$dk"
          log "[AUTO-FIX] Set KBUILD_MODPOST_WARN=1 in dkms.conf"
        fi
        if run_dkms_cycle; then
          success=1
        fi
      fi
    fi
  fi

  if [[ "$success" -ne 1 ]]; then
    log "[ERROR] DKMS path failed."
    if [[ "$FORCE_MANUAL" -eq 1 ]]; then
      manual_build_fallback || true
    else
      log "[INFO] Re-run with --run --auto-fix, or --run --force-manual for fallback build."
    fi
  fi

  verify_system

  # Summarize via ai_helper
  if command -v python3 >/dev/null 2>&1 && [[ -f "$TARGET_DIR/ai_helper.py" ]]; then
    python3 "$TARGET_DIR/ai_helper.py" summarize "$LOG_FILE" | tee -a "$LOG_FILE" || true
  else
    log "[NOTE] ai_helper.py not available; skipping summary."
  fi

  log "[DONE]"
}

main "$@"
