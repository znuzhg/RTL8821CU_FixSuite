#!/usr/bin/env bash
set -Eeuo pipefail

# ===============================================================
# RTL8821CU_FixSuite - WSL bağımlılık hazırlama aracı
# Yalnızca gerekli araçları kurar; sistem genelini yükseltmez.
# ===============================================================

LOGFILE="/var/log/rtl8821cu_fixsuite_update.log"
NO_NETWORK=0
AUTO_REMOVE=0

usage() {
    cat <<'EOF'
Kullanım: sudo bash update.sh [--no-network] [--autoremove] [-h|--help]

  --no-network  Ağ erişimini kullanma; eksik paket varsa hata ver.
  --autoremove  İsteğe bağlı apt autoremove temizliğini çalıştır.
  -h, --help    Bu yardım metnini göster.

Not: Betik apt-get upgrade çalıştırmaz. Yalnızca FixSuite için gereken
paketleri kurar. autoremove varsayılan olarak kapalıdır.
EOF
}

while (($#)); do
    case "$1" in
        --no-network) NO_NETWORK=1; shift ;;
        --autoremove) AUTO_REMOVE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[HATA] Bilinmeyen parametre: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo "[HATA] Betiği root olarak çalıştırın: sudo bash update.sh" >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-query >/dev/null 2>&1; then
    echo "[HATA] Bu betik apt/dpkg tabanlı Debian, Ubuntu veya Kali sistemleri içindir." >&2
    exit 1
fi

install -d -m 0755 "$(dirname "$LOGFILE")"
touch "$LOGFILE"
chmod 0640 "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

trap 'ec=$?; echo "[HATA] Güncelleme betiği $ec koduyla sonlandı. Log: $LOGFILE"; exit "$ec"' ERR

PACKAGES=(
    git dkms build-essential bc flex bison
    libssl-dev libelf-dev dwarves pkg-config
    curl wget unzip rfkill net-tools
    python3 python3-colorama python3-psutil
    usbutils libusb-1.0-0 pciutils
    iw wireless-tools lshw ethtool htop nano
)

echo "=============================================================="
echo "RTL8821CU FixSuite - Sistem Bağımlılıklarını Hazırlama"
echo "=============================================================="
echo "[BİLGİ] Log dosyası: $LOGFILE"
echo "[BİLGİ] apt-get upgrade çalıştırılmayacak; yalnızca gerekli paketler kurulacak."

if [[ "$NO_NETWORK" -eq 0 ]]; then
    echo "[ADIM] Paket listeleri güncelleniyor..."
    apt-get update
else
    echo "[BİLGİ] --no-network etkin; paket listeleri güncellenmeyecek."
fi

MISSING=()
for package in "${PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${db:Status-Abbrev}' "$package" 2>/dev/null | grep -q '^ii'; then
        MISSING+=("$package")
    fi
done

if ((${#MISSING[@]})); then
    if [[ "$NO_NETWORK" -eq 1 ]]; then
        printf '[HATA] Ağ kapalı ve şu paketler eksik: %s\n' "${MISSING[*]}" >&2
        exit 1
    fi
    echo "[ADIM] Eksik bağımlılıklar kuruluyor: ${MISSING[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${MISSING[@]}"
else
    echo "[OK] Gerekli paketlerin tamamı kurulu."
fi

if [[ "$AUTO_REMOVE" -eq 1 ]]; then
    echo "[ADIM] İsteğe bağlı autoremove temizliği çalıştırılıyor."
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
else
    echo "[BİLGİ] autoremove çalıştırılmadı. Pentest ve kullanıcı paketleri korunuyor."
fi

echo
echo "==================== Komut doğrulaması ===================="
COMMANDS=(git dkms make curl wget lsusb lspci iw iwconfig python3)
for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '[OK] %-12s %s\n' "$cmd" "$(command -v "$cmd")"
    else
        printf '[EKSİK] %s\n' "$cmd"
    fi
done

echo "=============================================================="
echo "[TAMAM] Bağımlılık kontrolü tamamlandı."
echo "[BİLGİ] WSL çekirdeği için linux-headers paketi aranmadı. Gerekli çekirdek ağacı ana betik tarafından hazırlanır."
echo "[BİLGİ] Log: $LOGFILE"
