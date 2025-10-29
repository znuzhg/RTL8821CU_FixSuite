🧰 RTL8821CU WSL2 FIX SUITE
Author

Znuzhg Onyvxpv

📘 Genel Bakış

Bu proje, WSL2 altında Realtek RTL8821CU kablosuz adaptörünün doğru şekilde çalışması için geliştirilmiş tam otomatik araç setidir.
Araç seti, Windows–WSL ikili ortamında çalışan üç ana bileşenden oluşur:

Bileşen	Açıklama
setup.ps1	Windows PowerShell üzerinden WSL ortamını hazırlar, kernel yapılandırmasını günceller ve gerekli dosyaları senkronize eder.
rtl8821cu_wsl_fix.sh	WSL (Debian/Ubuntu/Kali) içinde çalışarak RTL8821CU sürücüsünü DKMS üzerinden derler, yükler ve otomatik olarak hataları düzeltir.
ai_helper.py	rtl8821cu_wsl_fix.sh tarafından oluşturulan logları analiz eder, hataları ve önerileri JSON formatında özetler.
⚙️ Önemli Ön Hazırlıklar

Windows tarafına usbipd (usbipd-win) kurun.
(Microsoft Store veya winget kullanarak usbipd paketini yükleyin.)

WSL dağıtımınızın (kali-linux, ubuntu-20.04 vb.) yüklü ve başlatılmış olduğundan emin olun.

🔧 Kurulum & Kullanım Adımları
1️⃣ Windows — setup.ps1 ile hazırlık (PowerShell, yönetici)
# Yönetici PowerShell'de
powershell.exe -ExecutionPolicy Bypass -File setup.ps1


Ne yapar: Python ve Git kontrolleri yapar, WSL tarafına dosyaları senkronize eder ve kullanıcıya kullanılabilecek helper fonksiyonlarını listeler.

Kullanılabilir fonksiyonlar:

Set-WSLKernel -KernelImagePath <vmlinuz> [-UpdateConfig]

Copy-Toolset

Show-WSL-Restart-Steps

Attach-RTL8821CU (usbipd ile adaptör bağlama için yardımcı)

2️⃣ WSL (Linux) — sürücüyü derleme ve yükleme

WSL terminalinde:

# Derleme ve kurulum (gerçek çalıştırma)
sudo bash update.sh (bu betik paketleri kurar ve günceller)
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix

# Örnek: sadece simülasyon
sudo bash rtl8821cu_wsl_fix.sh --dry-run


Parametreler

--run : Gerçek derleme ve kurulum.

--dry-run : Simülasyon (değişiklik yapmaz).

--auto-fix : DKMS hatalarını otomatik düzeltme denemesi.

--force-manual : DKMS başarısızsa manuel derlemeye geç.

--no-network : Ağ bağlantısı olmadan yerel kaynak kullan.

--log-dir <path> : Özel log dizini.

Örnek

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix

3️⃣ Windows — USB cihazını WSL'e yönlendirme (usbipd)

Derleme tamamlandıktan sonra Windows PowerShell (yönetici) içinde:

Takılı USB cihazlarını listeleyin:

usbipd list


Listeden RTL cihazınızın BUSID değerini (örn. 2-13) bulun.

Cihazı WSL dağıtımınıza bağlayın:

# örnek: distro olarak 'kali-linux' kullanıldı
usbipd attach --busid 2-13 --wsl kali-linux


Not: bazı Windows sürümlerinde önce usbipd bind --busid <BUSID> gerekebilir; genelde attach yeterlidir.

4️⃣ WSL — bağlandıktan sonra kontrol ve etkinleştirme

WSL terminalinde:

# Bağlı USB cihazlarını kontrol edin
lsusb

# Ağ arayüzlerini kontrol edin
ip link show

# Eğer wlan0 görünüyor ama DOWN ise:
sudo ip link set wlan0 up

# Ardından kablosuz ağları görüntüleyin
iw dev

🧠 Log Analizi (ai_helper.py)

Derleme tamamlandıktan sonra log özetini almak için:

python3 ai_helper.py summarize logs/latest/run.log


Örnek JSON çıktı:

{
  "timestamp": "2025-10-29T00:00:00Z",
  "errors": ["modpost: Undefined symbol"],
  "warnings": ["deprecated API"],
  "suggested_fixes": ["Re-run kernel prepare"],
  "applied_patches": ["patch_8821cu_power.diff"]
}

📂 Proje Yapısı (Örnek)
RTL8821CU_FixSuite/
├── setup.ps1
├── rtl8821cu_wsl_fix.sh
├── ai_helper.py
├── update.sh              # (sistem bağımlılıklarını kuran yardımcı)
├── logs/
│   ├── 20251029_031200/
│   └── latest -> 20251029_031200/
└── PATCHES_APPLIED

🛠️ Teknik Notlar (Kısa)

Betikler idempotent olacak şekilde tasarlanmıştır; tekrar çalıştırılabilir.

rtl8821cu_wsl_fix.sh DKMS kullanır; başarısızlık halinde manuel derleme yolunu destekler.

Kernel kaynakları eksikse WSL için WSL2-Linux-Kernel deposundan kaynak hazırlanır (network gerektirir).

update.sh ile WSL içinde gerekli paketler (dkms, build-essential, iw, usbutils vb.) otomatik kurulabilir.

⚠️ Sorun Giderme (Hızlı)

lsusb çıkmıyorsa: WSL içinde usbutils yüklü değil — sudo apt install usbutils.

wlan0 görünmüyor: Windows tarafında usbipd attach ile doğru BUSID bağlandığından emin olun.

DKMS hataları: önce --auto-fix ile yeniden deneyin; gerekirse --force-manual.

linux-headers eksikse: dağıtım paketleriyle uyumsuz olabilir — loglara bakıp kernel kaynak yolunu kullanın.

🧾 Lisans

Açık kaynak. Kullanım veya türev çalışmalar için yazar izni önerilir.

Author: Znuzhg Onyvxpv
Version: 1.0.0
Last Updated: 2025-10-29
Compatibility: WSL2 (Ubuntu / Debian / Kali)

