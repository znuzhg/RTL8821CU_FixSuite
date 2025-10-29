#!/bin/bash
# ===============================================================
# 🧩 update.sh — RTL8821CU_FixSuite Sistem Güncelleme ve Hazırlık Aracı (v4)
# ---------------------------------------------------------------
# Tüm WSL2/Debian/Kali sistemleri için eksiksiz bağımlılık kurulumunu
# sağlar. Her çalıştırmada ortamı kontrol eder ve eksikleri tamamlar.
#
# Yazan: Znuzhg Onyvxpv
# Lisans: MIT
# ===============================================================

LOGFILE="/var/log/rtl8821cu_fixsuite_update.log"

echo "=============================================================="
echo "🔧 RTL8821CU FixSuite Sistem Güncelleme ve Ortam Hazırlığı"
echo "=============================================================="

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Lütfen betiği root (sudo) ile çalıştırın."
    exit 1
fi

set +e  # hata alsa da devam et

echo "[STEP] Paket listeleri güncelleniyor..."
apt-get update -y >> "$LOGFILE" 2>&1

echo "[STEP] Sistem yükseltiliyor..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$LOGFILE" 2>&1

echo "[STEP] Temel sistem araçları kuruluyor..."
apt-get install -y \
    git dkms build-essential bc \
    curl wget unzip rfkill net-tools \
    python3 python3-pip \
    linux-headers-$(uname -r) >> "$LOGFILE" 2>&1

# Donanım analiz araçları
echo "[STEP] Donanım analiz araçları kuruluyor..."
apt-get install -y \
    usbutils libusb-1.0-0 \
    pciutils libpci3 >> "$LOGFILE" 2>&1

# Kablosuz analiz araçları
echo "[STEP] Kablosuz analiz araçları kuruluyor..."
apt-get install -y iw wireless-tools >> "$LOGFILE" 2>&1

# Gerekirse yeniden yükle
for pkg in iw wireless-tools usbutils pciutils; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        echo "[FIX] Paket yeniden yükleniyor: $pkg"
        apt-get install -y --reinstall $pkg >> "$LOGFILE" 2>&1
    fi
done

# Ek yardımcı araçlar
echo "[STEP] Yardımcı sistem araçları kuruluyor..."
apt-get install -y lshw ethtool htop nano >> "$LOGFILE" 2>&1

# Python modülleri
echo "[STEP] Python modülleri yükleniyor..."
python3 -m pip install --upgrade pip >> "$LOGFILE" 2>&1
python3 -m pip install colorama psutil >> "$LOGFILE" 2>&1

# Temizlik
echo "[STEP] Gereksiz dosyalar kaldırılıyor..."
apt-get autoremove -y >> "$LOGFILE" 2>&1
apt-get clean >> "$LOGFILE" 2>&1

# Doğrulama
echo
echo "=============================================================="
echo "✅ Kurulum tamamlandı. Komut kontrolü:"
echo "--------------------------------------------------------------"
for cmd in lsusb iwconfig iw lspci python3; do
    if command -v $cmd &>/dev/null; then
        echo "$cmd → $(command -v $cmd)"
    else
        echo "$cmd → ❌ Eksik"
    fi
done
echo "=============================================================="
echo "📄 Log dosyası: $LOGFILE"
