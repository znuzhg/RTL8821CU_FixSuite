#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
#  RTL8821CU WSL2 FIX TOOL (v3)
# ============================================================
#  Strateji:
#    1) Çekirdeğin kendi rtw88_8821cu sürücüsü için firmware'i kur ve cihazı resetle.
#       (WSL'de çekirdek firmware'i bazen bulamaz; olmazsa otomatik 2. adıma geçilir.)
#    2) Olmazsa: WSL çekirdek kaynağını hazırla, 8821cu sürücüsünü DKMS ile derle.
#    3) DKMS de olmazsa --force-manual ile manuel derleme.
#
#  Kullanım:
#    sudo bash rtl8821cu_wsl_fix.sh [--run|--dry-run] [--auto-fix] [--force-manual]
#                                   [--force-dkms] [--skip-firmware] [--no-network]
#                                   [--log-dir PATH] [--project-root PATH]
#
#  Parametreler:
#    --run             Gerçek işlemleri yapar (varsayılan: dry-run)
#    --dry-run         Sadece simüle eder
#    --auto-fix        DKMS hatalarını otomatik düzeltmeyi dener
#    --force-manual    DKMS başarısızsa manuel derleme yapar
#    --force-dkms      Firmware yolu çalışsa bile DKMS yolunu da dener
#    --skip-firmware   Firmware adımını atlar, doğrudan DKMS
#    --no-network      Ağ/apt/git kullanmaz
#    --log-dir PATH    Log dizini
#    --project-root P  Proje kök dizini
#    -h, --help        Yardım
#
#  Örnek:
#    sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
# ============================================================

SCRIPT_NAME="$(basename "$0")"
START_TS="$(date +%Y%m%d_%H%M%S)"

_abs_path() { readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || echo "$1"; }

THIS_PATH="$(_abs_path "$0")"
TARGET_DIR="$(dirname "$THIS_PATH")"
PROJECT_ROOT="${PROJECT_ROOT:-$TARGET_DIR}"

RUN_MODE=0
AUTO_FIX=0
FORCE_MANUAL=0
FORCE_DKMS=0
SKIP_FIRMWARE=0
NO_NETWORK=0
USER_LOG_DIR=""

USB_VID="0bda"
USB_PID="c811"
KVER="$(uname -r)"
WSL_SRC_DIR="/usr/src/wsl-kernel-src"

usage() {
  cat <<EOF
Kullanım: sudo bash $SCRIPT_NAME [--run|--dry-run] [--auto-fix] [--force-manual]
                                 [--force-dkms] [--skip-firmware] [--no-network]
                                 [--log-dir PATH] [--project-root PATH]
  --run             Gerçek işlemleri yapar (varsayılan dry-run)
  --dry-run         Sadece simüle eder
  --auto-fix        DKMS hatalarını otomatik düzeltmeyi dener
  --force-manual    DKMS başarısızsa manuel derleme
  --force-dkms      Firmware yolu çalışsa bile DKMS'i dener
  --skip-firmware   Firmware adımını atlar
  --no-network      Ağ erişimi yok (apt/git kapalı)
  --log-dir PATH    Özel log dizini
  --project-root P  Proje kök dizini
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run) RUN_MODE=1; shift ;;
    --dry-run) RUN_MODE=0; shift ;;
    --auto-fix) AUTO_FIX=1; shift ;;
    --force-manual|--force-manuel) FORCE_MANUAL=1; shift ;;
    --force-dkms) FORCE_DKMS=1; shift ;;
    --skip-firmware) SKIP_FIRMWARE=1; shift ;;
    --no-network) NO_NETWORK=1; shift ;;
    --log-dir)
      [[ $# -ge 2 ]] || { echo "[ERROR] --log-dir bir yol ister"; exit 2; }
      USER_LOG_DIR="$2"; shift 2 ;;
    --project-root)
      [[ $# -ge 2 ]] || { echo "[ERROR] --project-root bir yol ister"; exit 2; }
      PROJECT_ROOT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Bilinmeyen parametre: $1"; usage; exit 2 ;;
  esac
done

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERROR] Root olarak çalıştırın: sudo bash $SCRIPT_NAME ..."; exit 1
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "[WARN] PROJECT_ROOT bulunamadı: $PROJECT_ROOT -> $TARGET_DIR kullanılacak"
  PROJECT_ROOT="$TARGET_DIR"
fi

# ---------------- Log ----------------
LOG_BASE_DIR="$TARGET_DIR/logs"
mkdir -p "$LOG_BASE_DIR"
LOG_DIR="${USER_LOG_DIR:-$LOG_BASE_DIR/$START_TS}"
mkdir -p "$LOG_DIR"
ln -sfn "$LOG_DIR" "$LOG_BASE_DIR/latest" 2>/dev/null || true
LOG_FILE="$LOG_DIR/run.log"
: >"$LOG_FILE"
DMESG_BASELINE_FILE="$LOG_DIR/dmesg.before"
DMESG_BASELINE_OK=0
if command -v dmesg >/dev/null 2>&1 && dmesg --raw >"$DMESG_BASELINE_FILE" 2>/dev/null; then
  DMESG_BASELINE_OK=1
fi
export RTL8821CU_WSL_TARGET="$TARGET_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

err_trap() {
  local ec=$?
  log "[ERROR] Script hata ile durdu (kod $ec, satır ${BASH_LINENO[0]}). Log: $LOG_FILE"
  exit "$ec"
}
trap err_trap ERR
trap 'log "[INFO] Exit."' EXIT

# ---------------- Yardımcılar ----------------
# Komutu eval OLMADAN çalıştırır (dry-run'da sadece yazar)
_do() {
  if [[ "$RUN_MODE" -eq 1 ]]; then
    log "+ $*"
    "$@"
  else
    log "(dry-run) $*"
  fi
}

# stdin içeriğini dosyaya yazar (dry-run'da yazmaz)
write_file() {
  local dest="$1" mode="${2:-0644}" content
  content="$(cat)"
  if [[ "$RUN_MODE" -eq 1 ]]; then
    log "+ write $dest"
    mkdir -p "$(dirname "$dest")"
    printf '%s\n' "$content" >"$dest"
    chmod "$mode" "$dest"
  else
    log "(dry-run) write $dest"
  fi
}

sanitize_env() {
  unset MAKEFLAGS MAKELEVEL MFLAGS HOSTCFLAGS WERROR NO_WERROR CCACHE_DIR CCACHE_COMPILERCHECK || true
}

has_wifi_iface() {
  local d
  for d in /sys/class/net/*/wireless; do
    [[ -e "$d" ]] && return 0
  done
  return 1
}

module_loaded() { grep -q "^$1 " /proc/modules 2>/dev/null; }

find_usb_dev() {
  local d
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    if [[ "$(cat "$d/idVendor")" == "$USB_VID" && "$(cat "$d/idProduct")" == "$USB_PID" ]]; then
      echo "$d"; return 0
    fi
  done
  return 1
}

reset_usb_dev() {
  local d
  d="$(find_usb_dev)" || { log "[WARN] USB cihaz ($USB_VID:$USB_PID) WSL içinde görünmüyor. Windows'ta 'usbipd attach --wsl --busid <ID>' yapın."; return 1; }
  log "[INFO] USB cihaz resetleniyor: $d"
  _do bash -c "echo 0 > '$d/authorized'; sleep 1; echo 1 > '$d/authorized'" || true
}

wait_for_wifi() {
  [[ "$RUN_MODE" -eq 1 ]] || return 1
  local i
  for i in $(seq 1 12); do
    has_wifi_iface && return 0
    sleep 1
  done
  return 1
}

# ---------------- dpkg onarımı (yarım kalan nvidia-kernel-dkms vb.) ----------------
heal_dpkg() {
  local st
  st="$(dpkg-query -W -f='${db:Status-Abbrev}' nvidia-kernel-dkms 2>/dev/null || true)"
  if [[ -n "$st" && "$st" != "ii " ]]; then
    log "[FIX] nvidia-kernel-dkms yarım kurulmuş (durum: '$st'). WSL'de Linux NVIDIA sürücüsü gerekmez (GPU'yu Windows sürücüsü sağlar); kaldırılıyor."
    local ent
    while read -r ent; do
      [[ -n "$ent" ]] && _do dkms remove "$ent" --all || true
    done < <(dkms status 2>/dev/null | grep -E '^nvidia' | cut -d, -f1 | cut -d: -f1 | sort -u)
    _do apt-get purge -y nvidia-kernel-dkms || _do dpkg --purge --force-all nvidia-kernel-dkms || true
  fi
  if dpkg --audit 2>/dev/null | grep -q .; then
    log "[FIX] dpkg yarım paketler var, 'dpkg --configure -a' çalıştırılıyor"
    _do dpkg --configure -a || true
  fi
}

# ---------------- apt ----------------
PKGS=(git dkms build-essential bc flex bison libssl-dev libelf-dev dwarves pkg-config)
ensure_apt_ready() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log "[WARN] apt-get yok; paket kontrolü atlandı."; return 0
  fi
  if [[ "$NO_NETWORK" -eq 1 ]]; then
    log "[INFO] --no-network: apt atlandı."; return 0
  fi
  local missing=() p
  for p in "${PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if ((${#missing[@]})); then
    _do apt-get update -y
    _do apt-get install -y "${missing[@]}"
  else
    log "[OK] Gerekli paketler kurulu."
  fi
  # NOT: WSL çekirdeği için linux-headers paketi yoktur; denenmez.
}

# ---------------- ADIM 1: Çekirdek içi rtw88 sürücüsü + firmware ----------------
have_fw() { compgen -G "/lib/firmware/rtw88/rtw8821c_fw.bin*" >/dev/null 2>&1; }

ensure_firmware_path() {
  log "[STEP1] Çekirdek içi rtw88_8821cu sürücüsü için firmware kontrolü"
  if ! have_fw; then
    if [[ "$NO_NETWORK" -eq 1 ]]; then
      log "[WARN] rtw8821c_fw.bin yok ve --no-network açık; firmware kurulamaz."
      return 1
    fi
    local pkgs=()
    if apt-cache show firmware-realtek >/dev/null 2>&1; then pkgs+=(firmware-realtek)
    elif apt-cache show linux-firmware >/dev/null 2>&1; then pkgs+=(linux-firmware); fi
    dpkg -s wireless-regdb >/dev/null 2>&1 || pkgs+=(wireless-regdb)
    if ((${#pkgs[@]})); then
      _do apt-get install -y "${pkgs[@]}" || log "[WARN] Firmware paketi kurulamadı."
    else
      log "[WARN] Firmware paketi bulunamadı (firmware-realtek / linux-firmware)."
    fi
  else
    log "[OK] rtw8821c firmware mevcut."
  fi
  _do modprobe rtw88_8821cu || true
  reset_usb_dev || true
  if wait_for_wifi; then
    log "[SUCCESS] Wi-Fi arayüzü çekirdek içi sürücüyle geldi (DKMS gerekmedi)."
    return 0
  fi
  return 1
}

# ---------------- ADIM 2: Çekirdek kaynağı ----------------
KERNEL_SRC=""
kernel_tree_ready() {
  [[ -f "$1/Makefile" && -f "$1/include/generated/autoconf.h" ]] || return 1
  local rel=""
  if [[ -f "$1/include/config/kernel.release" ]]; then
    rel="$(cat "$1/include/config/kernel.release")"; rel="${rel%+}"
    [[ "$rel" == "$KVER" ]] || return 1   # farklı çekirdek sürümünün ağacı
  fi
  return 0
}

prepare_kernel_source() {
  local cand
  for cand in "/lib/modules/$KVER/build" "/usr/src/linux-headers-$KVER" "$WSL_SRC_DIR"; do
    [[ -d "$cand" ]] || continue
    if [[ "$cand" == "$WSL_SRC_DIR" && ! -f "$cand/include/config/kernel.release" \
      && "$(cat "$cand/.built_for_kver" 2>/dev/null || true)" != "$KVER" ]]; then
      continue
    fi
    if kernel_tree_ready "$cand"; then
      KERNEL_SRC="$(_abs_path "$cand")"
      log "[OK] Hazır çekirdek ağacı: $KERNEL_SRC"
      return 0
    fi
  done
  log "[INFO] Hazır çekirdek ağacı yok (build klasörü boş/bozuk). WSL kaynağı hazırlanacak."
  if [[ "$NO_NETWORK" -eq 1 && ! -f "$WSL_SRC_DIR/Makefile" ]]; then
    log "[ERROR] Kaynak yok ve --no-network açık."; return 1
  fi
  KERNEL_SRC="$WSL_SRC_DIR"
  if [[ ! -f "$KERNEL_SRC/Makefile" || "$(cat "$KERNEL_SRC/.built_for_kver" 2>/dev/null || true)" != "$KVER" ]]; then
    local base tag branch
    base="${KVER%%-*}"                       # 6.18.58.1
    tag="linux-msft-wsl-$base"
    branch="linux-msft-wsl-$(echo "$base" | cut -d. -f1,2).y"
    _do rm -rf "$KERNEL_SRC"
    _do git clone --depth 1 --branch "$tag" https://github.com/microsoft/WSL2-Linux-Kernel.git "$KERNEL_SRC" \
      || _do git clone --depth 1 --branch "$branch" https://github.com/microsoft/WSL2-Linux-Kernel.git "$KERNEL_SRC" \
      || _do git clone --depth 1 https://github.com/microsoft/WSL2-Linux-Kernel.git "$KERNEL_SRC"
  else
    log "[INFO] Mevcut kaynak kullanılıyor: $KERNEL_SRC"
  fi
  # Çalışan çekirdeğin gerçek config'i en doğrusu
  if [[ -r /proc/config.gz ]]; then
    _do bash -c "zcat /proc/config.gz > '$KERNEL_SRC/.config'"
  elif [[ -f "$KERNEL_SRC/Microsoft/config-wsl" ]]; then
    _do cp "$KERNEL_SRC/Microsoft/config-wsl" "$KERNEL_SRC/.config"
  fi
  _do make -C "$KERNEL_SRC" olddefconfig || true
  _do make -C "$KERNEL_SRC" -j"$(nproc)" modules_prepare
  if [[ "$RUN_MODE" -eq 1 ]] && ! kernel_tree_ready "$KERNEL_SRC"; then
    log "[ERROR] modules_prepare sonrası $KERNEL_SRC hazır değil."; return 1
  fi
  [[ "$RUN_MODE" -eq 1 ]] && echo "$KVER" >"$KERNEL_SRC/.built_for_kver"
  # /usr/src/linux-headers-<ver> WSL'de çoğunlukla salt-okunur bağlama noktasıdır; dokunulamazsa
  # sorun değil (DKMS --kernelsourcedir ile doğrudan $KERNEL_SRC'yi kullanır).
  local hdr="/usr/src/linux-headers-$KVER"
  if [[ ! -f "$hdr/Makefile" ]]; then
    if mountpoint -q "$hdr" 2>/dev/null; then
      log "[INFO] $hdr bir bağlama noktası; yönlendirme atlandı (gerekmiyor)."
    else
      if [[ -e "$hdr" && ! -L "$hdr" ]]; then _do mv "$hdr" "$hdr.empty.$START_TS" || log "[WARN] $hdr taşınamadı"; fi
      _do ln -sfn "$KERNEL_SRC" "$hdr" || log "[WARN] $hdr sembolik bağı oluşturulamadı (önemli değil)"
    fi
  fi
  log "[OK] Çekirdek kaynağı hazır: $KERNEL_SRC"
}

# ---------------- Sürücü kaynağı ----------------
SCAN_DRIVER_SRC=""
PATCHES_FOUND=()
scan_project_tree() {
  log "[INFO] Proje taranıyor: $PROJECT_ROOT"
  local d
  while read -r d; do
    [[ -n "$d" ]] || continue
    if [[ -f "$d/Makefile" ]]; then SCAN_DRIVER_SRC="$d"; break; fi
  done < <(find "$PROJECT_ROOT" -maxdepth 6 -type d -iname "*8821cu*" -not -path "*/logs/*" 2>/dev/null | sort -u)
  # Sadece kendi patches/ klasöründeki yamalar uygulanır (docs içindeki Android yamaları DEĞİL)
  if [[ -d "$PROJECT_ROOT/patches" ]]; then
    mapfile -t PATCHES_FOUND < <(find "$PROJECT_ROOT/patches" -type f \( -iname "*.patch" -o -iname "*.diff" \) 2>/dev/null | sort -u)
  fi
  if [[ -n "$SCAN_DRIVER_SRC" ]]; then log "[OK] Yerel sürücü kaynağı: $SCAN_DRIVER_SRC"
  else log "[INFO] Yerel sürücü kaynağı yok."; fi
}

DRIVER_SRC=""
DRIVER_VERSION=""
DKMS_SRC_DIR=""
get_driver_source() {
  if [[ -n "$SCAN_DRIVER_SRC" ]]; then
    DRIVER_SRC="$SCAN_DRIVER_SRC"
  else
    if [[ "$NO_NETWORK" -eq 1 ]]; then log "[ERROR] Yerel kaynak yok ve --no-network açık."; return 1; fi
    DRIVER_SRC="$TARGET_DIR/vendor/8821cu"
    _do mkdir -p "$TARGET_DIR/vendor"
    _do rm -rf "$DRIVER_SRC"
    _do git clone --depth 1 https://github.com/morrownr/8821cu-20210916 "$DRIVER_SRC"
  fi
  if [[ -f "$DRIVER_SRC/dkms.conf" ]]; then
    DRIVER_VERSION="$(sed -nE 's/^[[:space:]]*PACKAGE_VERSION[[:space:]]*=[[:space:]]*"?([^"[:space:]]+)"?.*/\1/p' "$DRIVER_SRC/dkms.conf" | head -n1 || true)"
  fi
  [[ -n "$DRIVER_VERSION" && "$DRIVER_VERSION" != "@VERSION@" ]] || DRIVER_VERSION="5.12.0.4"
  DKMS_SRC_DIR="/usr/src/8821cu-$DRIVER_VERSION"
  log "[OK] Sürücü kaynağı: $DRIVER_SRC (sürüm: $DRIVER_VERSION)"
}

write_dkms_conf() {
  local dir="$1" extra="${2:-}" content
  content="$(cat <<'EOF_DKMS'
PACKAGE_NAME="8821cu"
PACKAGE_VERSION="@VERSION@"
BUILT_MODULE_NAME[0]="8821cu"
DEST_MODULE_LOCATION[0]="/updates/dkms"
AUTOINSTALL="yes"
MAKE[0]="'make' -j$(nproc) @EXTRA@ KVER=${kernelver} KSRC=${kernel_source_dir}"
CLEAN="'make' clean"
EOF_DKMS
)"
  content="${content//@VERSION@/$DRIVER_VERSION}"
  content="${content//@EXTRA@/$extra}"
  if [[ -f "$dir/dkms.conf" ]]; then _do cp "$dir/dkms.conf" "$dir/dkms.conf.bak.$(date +%Y%m%d_%H%M%S)"; fi
  printf '%s\n' "$content" | write_file "$dir/dkms.conf" 0644
  log "[OK] dkms.conf yazıldı (${extra:-ek bayrak yok})"
}

sync_to_dkms_tree() {
  [[ -n "$DKMS_SRC_DIR" ]] || { log "[ERROR] DKMS_SRC_DIR boş"; return 1; }
  if [[ -d "$DKMS_SRC_DIR" ]]; then
    _do rm -rf "$DKMS_SRC_DIR.bak"
    _do mv "$DKMS_SRC_DIR" "$DKMS_SRC_DIR.bak"
  fi
  _do mkdir -p "$DKMS_SRC_DIR"
  _do cp -a "$DRIVER_SRC/." "$DKMS_SRC_DIR/"
  write_dkms_conf "$DKMS_SRC_DIR" "KBUILD_MODPOST_WARN=1"
}

apply_patches_if_any() {
  local record="$TARGET_DIR/PATCHES_APPLIED" p
  if ((${#PATCHES_FOUND[@]}==0)); then log "[INFO] Uygulanacak yama yok."; return 0; fi
  for p in "${PATCHES_FOUND[@]}"; do
    if grep -Fqx "$p" "$record" 2>/dev/null; then log "[INFO] Yama zaten uygulanmış: $p"; continue; fi
    if git -C "$DKMS_SRC_DIR" apply --check "$p" >/dev/null 2>&1; then
      if [[ "$RUN_MODE" -eq 1 ]]; then
        log "[PATCH] $p"; git -C "$DKMS_SRC_DIR" apply "$p" && echo "$p" >>"$record"
      else
        log "(dry-run) yama uygulanır: $p"
      fi
    else
      log "[WARN] Yama uygulanamıyor: $p"
    fi
  done
}

# ---------------- DKMS ----------------
DKMS_ATTEMPTS=0
DKMS_MAKELOG=""
run_dkms_cycle() {
  DKMS_ATTEMPTS=$((DKMS_ATTEMPTS+1))
  log "[INFO] DKMS denemesi #$DKMS_ATTEMPTS (KERNEL_SRC=$KERNEL_SRC)"
  local v ec=0
  while read -r v; do
    [[ -n "$v" ]] && _do dkms remove -m 8821cu -v "$v" --all || true
  done < <(dkms status 2>/dev/null | grep -E '^8821cu' | sed -E 's#^8821cu[/ ,]+([^,: ]+).*#\1#' | sort -u)

  _do dkms add -m 8821cu -v "$DRIVER_VERSION" || true

  if [[ "$RUN_MODE" -eq 1 ]]; then
    set +e
    dkms build -m 8821cu -v "$DRIVER_VERSION" -k "$KVER" --kernelsourcedir "$KERNEL_SRC" --verbose 2>&1 | tee -a "$LOG_FILE"
    ec=${PIPESTATUS[0]}
    set -e
  else
    log "(dry-run) dkms build -m 8821cu -v $DRIVER_VERSION -k $KVER --kernelsourcedir $KERNEL_SRC --verbose"
  fi
  DKMS_MAKELOG="$(
    find "/var/lib/dkms/8821cu/$DRIVER_VERSION" -type f -name make.log \
      -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true
  )"
  if [[ $ec -ne 0 ]]; then
    log "[ERROR] DKMS build başarısız (deneme $DKMS_ATTEMPTS). make.log: ${DKMS_MAKELOG:-yok}"
    return 1
  fi
  if [[ "$RUN_MODE" -eq 1 ]]; then
    set +e
    dkms install -m 8821cu -v "$DRIVER_VERSION" -k "$KVER" 2>&1 | tee -a "$LOG_FILE"
    ec=${PIPESTATUS[0]}
    set -e
    [[ $ec -eq 0 ]] || { log "[ERROR] dkms install başarısız"; return 1; }
  else
    log "(dry-run) dkms install -m 8821cu -v $DRIVER_VERSION -k $KVER"
  fi
  return 0
}

attempt_autofix() {
  if [[ -n "$DKMS_MAKELOG" && -f "$DKMS_MAKELOG" ]]; then
    if grep -qi "no makefile found" "$DKMS_MAKELOG"; then
      log "[AUTO-FIX] Çekirdek ağacı boş; yeniden hazırlanıyor"
      KERNEL_SRC=""; prepare_kernel_source || true
    fi
    if grep -Eqi "Module.symvers|modpost" "$DKMS_MAKELOG"; then
      log "[AUTO-FIX] Module.symvers/modpost sorunu"
      [[ -f "$KERNEL_SRC/Module.symvers" ]] && _do cp "$KERNEL_SRC/Module.symvers" "$DKMS_SRC_DIR/Module.symvers"
      write_dkms_conf "$DKMS_SRC_DIR" "KBUILD_MODPOST_WARN=1"
    fi
    if grep -Eq "error:" "$DKMS_MAKELOG"; then
      log "[NOTE] Derleme hataları var: eski sürücü kaynağı $KVER API'siyle uyumsuz olabilir. make.log: $DKMS_MAKELOG"
    fi
  else
    log "[AUTO-FIX] make.log yok; genel hazırlık"
    _do make -C "$KERNEL_SRC" -j"$(nproc)" modules_prepare || true
  fi
}

manual_build_fallback() {
  log "[FALLBACK] Manuel derleme"
  _do make -C "$KERNEL_SRC" M="$DKMS_SRC_DIR" KBUILD_MODPOST_WARN=1 modules
  local ko
  ko="$(find "$DKMS_SRC_DIR" -name '8821cu.ko' -type f 2>/dev/null | head -n1 || true)"
  if [[ "$RUN_MODE" -eq 1 && -z "$ko" ]]; then
    log "[ERROR] Manuel derleme 8821cu.ko üretmedi"; return 1
  fi
  _do mkdir -p "/lib/modules/$KVER/extra"
  [[ -n "$ko" ]] && _do cp "$ko" "/lib/modules/$KVER/extra/"
  _do depmod -a
  _do modprobe 8821cu || true
  log "[FALLBACK] Manuel derleme bitti"
}

# ---------------- Kalıcılık ----------------
ensure_wsl_systemd() {
  local f=/etc/wsl.conf
  if [[ -f "$f" ]] && grep -Eq '^[[:space:]]*systemd[[:space:]]*=[[:space:]]*true' "$f"; then
    log "[OK] wsl.conf: systemd zaten açık"; return 0
  fi
  if [[ -f "$f" ]]; then _do cp "$f" "$f.bak.$START_TS"; fi
  if [[ "$RUN_MODE" -ne 1 ]]; then log "(dry-run) wsl.conf [boot] systemd=true eklenecek"; return 0; fi
  if [[ -f "$f" ]] && grep -Eq '^[[:space:]]*\[boot\]' "$f"; then
    sed -i -E '/^[[:space:]]*\[boot\]/a systemd=true' "$f"
  else
    printf '\n[boot]\nsystemd=true\n' >>"$f"
  fi
  log "[OK] wsl.conf güncellendi (WSL'i 'wsl --shutdown' ile yeniden başlatın)"
}

setup_persistence() {
  log "[PERSISTENCE] Otomatik yükleme ve hotplug ayarlanıyor"
  _do depmod -a
  printf '8821cu\n' | write_file /etc/modules-load.d/8821cu.conf 0644
  # Çekirdek içi rtw88 sürücüsüyle çakışmayı önle
  printf 'blacklist rtw88_8821cu\nblacklist rtw88_8821c\n' | write_file /etc/modprobe.d/blacklist-rtw88-8821cu.conf 0644
  printf 'ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="%s", ATTR{idProduct}=="%s", RUN+="/sbin/modprobe 8821cu"\n' "$USB_VID" "$USB_PID" \
    | write_file /etc/udev/rules.d/99-rtl8821cu.rules 0644
  _do udevadm control --reload-rules || true
  ensure_wsl_systemd
  log "[PERSISTENCE] Tamam. Not: WSL çekirdeği güncellenirse scripti tekrar çalıştırın."
}

# ---------------- Doğrulama ----------------
verify_system() {
  log "[VERIFY] Sistem bilgisi toplanıyor"
  {
    echo "===== modinfo 8821cu ====="; modinfo 8821cu 2>&1 || true
    echo "===== modinfo rtw88_8821cu ====="; modinfo rtw88_8821cu 2>&1 | head -n 5 || true
    echo "===== firmware ====="; ls -l /lib/firmware/rtw88/rtw8821c_fw.bin* 2>&1 || true
    echo "===== ip -br link ====="; ip -br link 2>&1 || true
    echo "===== iw dev ====="; iw dev 2>&1 || true
    echo "===== lsusb ====="; lsusb 2>&1 || true
    echo "===== dmesg (bu çalışmada yeni rtw/usb kayıtları) ====="
    if [[ "$DMESG_BASELINE_OK" -eq 1 && -f "$DMESG_BASELINE_FILE" ]] && command -v diff >/dev/null 2>&1; then
      dmesg --raw 2>/dev/null \
        | diff -u "$DMESG_BASELINE_FILE" - \
        | sed -n '/^+++ /d; /^+/{s/^+//;p;}' \
        | grep -Ei 'rtw|8821|cfg80211|usb 1-' \
        | tail -n 40 || true
    else
      echo "[WARN] dmesg başlangıç kaydı alınamadı; eski kernel mesajları ayıklanamadı."
    fi
  } 2>&1 | tee -a "$LOG_FILE"

  if has_wifi_iface; then
    log "[SUCCESS] Kablosuz arayüz görünüyor."
    local d iface
    for d in /sys/class/net/*/wireless; do
      iface="$(basename "$(dirname "$d")")"
      _do ip link set "$iface" up || true
    done
  else
    log "[WARN] Kablosuz arayüz yok. dmesg çıktısına ve USB passthrough durumuna bakın."
  fi
}

summarize() {
  if command -v python3 >/dev/null 2>&1 && [[ -f "$TARGET_DIR/ai_helper.py" ]]; then
    python3 -W ignore::DeprecationWarning "$TARGET_DIR/ai_helper.py" summarize "$LOG_FILE" 2>&1 | tee -a "$LOG_FILE" || true
  else
    log "[NOTE] ai_helper.py yok; özet atlandı."
  fi
}

finish() {
  if has_wifi_iface || module_loaded 8821cu; then log "DONE success"; else log "DONE failure"; fi
}

# ---------------- main ----------------
main() {
  sanitize_env
  log "[START] $SCRIPT_NAME $START_TS | KVER=$KVER | MODE=$([[ $RUN_MODE -eq 1 ]] && echo run || echo dry-run) | AUTO_FIX=$AUTO_FIX | FORCE_MANUAL=$FORCE_MANUAL | FORCE_DKMS=$FORCE_DKMS | SKIP_FIRMWARE=$SKIP_FIRMWARE | NO_NETWORK=$NO_NETWORK"
  log "[INFO] Log: $LOG_FILE"
  [[ "$RUN_MODE" -eq 1 ]] || log "[INFO] DRY-RUN: hiçbir şey değişmez. Gerçek kurulum için --run ekleyin."

  heal_dpkg
  ensure_apt_ready || true

  # --- Adım 1: firmware + çekirdek içi sürücü ---
  if [[ "$SKIP_FIRMWARE" -eq 0 ]]; then
    if ensure_firmware_path && [[ "$FORCE_DKMS" -eq 0 ]]; then
      verify_system; finish; summarize; return 0
    fi
  fi

  # --- Adım 2: DKMS ---
  log "[STEP2] DKMS yolu"
  scan_project_tree
  prepare_kernel_source || { log "[ERROR] Çekirdek kaynağı hazırlanamadı."; verify_system; finish; summarize; return 0; }
  get_driver_source || { verify_system; finish; summarize; return 0; }
  sync_to_dkms_tree
  apply_patches_if_any

  local success=0
  if run_dkms_cycle; then
    success=1
  elif [[ "$AUTO_FIX" -eq 1 ]]; then
    attempt_autofix
    if run_dkms_cycle; then
      success=1
    else
      attempt_autofix
      write_dkms_conf "$DKMS_SRC_DIR" "KBUILD_MODPOST_WARN=1"
      run_dkms_cycle && success=1 || true
    fi
  fi

  if [[ "$success" -ne 1 ]]; then
    log "[ERROR] DKMS yolu başarısız."
    if [[ "$FORCE_MANUAL" -eq 1 ]]; then
      manual_build_fallback && success=1 || true
    else
      log "[INFO] --run --auto-fix veya --run --force-manual ile tekrar deneyin."
    fi
  fi

  if [[ "$success" -eq 1 ]]; then
    _do modprobe -r rtw88_8821cu 2>/dev/null || true
    _do modprobe 8821cu || true
    setup_persistence
    reset_usb_dev || true
    wait_for_wifi || true
  fi

  verify_system
  finish
  summarize
}

main