🚀 RTL8821CU WSL2 FixSuite
Realtek 8821CU USB Wi-Fi Adaptörü — WSL2 Tam Otomatik Kurulum Aracı

Final v1.0 — Geliştirici: Znuzhg Onyvxpv

📌 Özet

Bu proje, Windows + WSL2 üzerinde Realtek RTL8821CU USB Wi-Fi adaptörünü tam otomatik olarak WSL içine bağlar, DKMS ile derler, kurar ve kalıcı hale getirir.

🔹 Tam otomasyon
🔹 İdempotent (güvenle yeniden çalıştırılabilir)
🔹 Off-line uyumlu
🔹 Ayrıntılı loglama + JSON özetleme

⚙️ Özellikler
Özellik	Açıklama
🔌 USBIPD otomasyonu	Windows → WSL arası cihaz algılama, bind/detach, attach
⚡ Yeni usbipd (5.3+) sözdizimi	usbipd attach --wsl desteği + eski sürümler için fallback
🛠️ DKMS derleme döngüsü	add → build → install + otomatik hata düzeltme
🔁 Kalıcılık	/etc/modules-load.d, /etc/udev/rules.d, wsl.conf güvenli birleştirme
🌐 Off-line mod	--no-network ile apt & clone adımlarını atlar
🧠 Teşhis aracı	ai_helper.py ile log → JSON özetleme
🧩 Kernel source fallback	Headers yoksa WSL kernel source hazırlanır
🖥️ Desteklenen Sistemler

Windows 10 / 11

WSL2

Dağıtımlar:

Kali Linux

Ubuntu

Debian

usbipd-win 5.3+ (öncelikli)

Yetkiler:

Windows: Admin PowerShell

WSL: root / sudo

🧩 Mimari ve Bileşenler
🪟 setup.ps1 (Windows)

usbipd ile otomatik bind/detach/attach

BusId doğrulama

Yeni sözdizimi öncelikli (attach --wsl)

Fallback eski yöntem (attach --busid)

Ayrıntılı loglama

🐧 update.sh (WSL)

Bağımlılık kurulumu (apt)

Headers yoksa yalnızca uyarı

Off-line mod desteği

🐧 rtl8821cu_wsl_fix.sh (WSL)

Kernel source hazırlığı

DKMS döngüsü

Otomatik düzeltme

Kalıcılık ayarları

🚀 Kurulum (Sırasıyla)
1️⃣ WSL2 içinde proje dizinine gidin
cd /mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FixSuite/

2️⃣ update.sh ile bağımlılıkları kurun
sudo DEBIAN_FRONTEND=noninteractive bash update.sh


Ağ kısıtlıysa:

sudo bash update.sh --no-network


ℹ️ Bazı WSL kernel sürümlerinde linux-headers-$(uname -r) bulunmayabilir; betik uyarı verir ve kernel source fallback ile devam eder.

3️⃣ Windows tarafında setup.ps1 çalıştırın

Admin PowerShell aç:

cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File -Path .\setup.ps1


Cihazı bağlayın:

.\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose


🔹 BusId vermediğinizde Realtek cihaz otomatik seçilir
🔹 “Not shared” → otomatik bind
🔹 “Attached” → otomatik detach
🔹 usbipd >= 5.3: attach --wsl
🔹 Eski sürüm: attach --busid

4️⃣ WSL tarafında sürücü kurulumu
cd /mnt/c/Users/<kullanıcı>/Desktop/RTL8821CU_FxSute-local/repo
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix


Off-line:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network


DKMS → kernel source fallback → kalıcılık → hepsi otomatik.

🧵 USB Passthrough (usbipd) Rehberi

Cihazları listele:

usbipd list


“Not shared” cihaz için:

usbipd bind --busid 2-13


Bağlamak:

usbipd attach --busid 2-13 --wsl kali-linux


Varsayılan dağıtım için:

usbipd attach --busid 2-13


Ayırmak:

usbipd detach --busid 2-13


💡 WSL kapatılıp yeniden açıldığında Windows terminalde tekrar:
usbipd.exe attach --busid --wsl <DISTRO_NAME>

🛠️ Komut Satırı Referansı
🪟 setup.ps1
Parametre	Açıklama
-AutoAttach	Otomatik bind + attach
-DistroName	WSL dağıtım adı
-BusId	USB bus numarası
-DryRun	Test modu
-Force	Zorla yürütme
-LogDir	Log dizini

Örnek:

.\setup.ps1 -AutoAttach -DistroName "Ubuntu-22.04" -BusId "2-13" -Force -Verbose

🐧 update.sh
sudo bash update.sh
sudo bash update.sh --no-network

🐧 rtl8821cu_wsl_fix.sh
Parametre	Açıklama
--run	Gerçek kurulum
--dry-run	Test modu
--auto-fix	Hata düzeltme
--force-manual	Manuel mod
--no-network	Off-line
--log-dir	Log dizini

Örnek:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network

📄 Loglama ve Çıkış Kodları
Windows:
logs\YYYYmmdd_HHMMSS\setup.log

WSL:
logs/YYYYmmdd_HHMMSS/run.log
logs/latest → son çalışmanın sembolik bağlantısı

AI özetleme:
python3 ai_helper.py summarize logs/latest/run.log

🟢 Başarılı Kurulum Belirtileri
Cihaz görünüyor mu?
lsusb | grep -i 0bda:c811

Modül yüklü mü?
lsmod | grep '^8821cu'
modinfo 8821cu

Arayüz?
ip -br link
iw dev
rfkill list

❗ Sık Karşılaşılan Hatalar ve Çözümler
Hata	Açıklama	Çözüm
usbipd bulunamadı	Sistem usbipd-win kurulu değil	winget install dorssel.usbipd-win
"Not shared"	Cihaz paylaşılmamış	usbipd bind --busid
Adaptör görünmüyor	WSL bağlanmadı	wsl --shutdown → tekrar deneyin
DKMS: Module.symvers	Eksik kernel sembolleri	Kernel source fallback devreye girer
modpost/Undefined	Eksik kaynak veya modül	Betik otomatik düzeltme dener
linux-headers yok	WSL kernel sürümü özel	Sadece uyarı; fallback aktif
🧪 Teşhis (Hızlı)

Wi-Fi görünmüyor → sıra ile:

lsusb | grep 0bda:c811
lsmod | grep 8821cu
ip -br link
sudo ip link set wlan0 up
rfkill unblock all


DKMS hatası:

tail -n 200 /var/lib/dkms/8821cu/*/build/make.log
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix


USB görünmüyorsa:

usbipd list
usbipd bind --busid
usbipd attach --busid --wsl

🔐 Güvenlik

Betikler yeniden çalıştırılabilir (idempotent)

Devlet seviyesinde güvenlik gereksinimleri düşünülerek yazılmıştır

Off-line mod ağ kapalı ortamlarda çalışır

❤️ Katkı

Katkıda bulunmak isteyenler için:
→ CONTRIBUTING.md
→ CODE_OF_CONDUCT.md
→ SECURITY.md

📜 Lisans

MIT License
© 2025 Znuzhg Onyvxpv
