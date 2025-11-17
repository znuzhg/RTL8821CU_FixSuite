🚀 RTL8821CU FixSuite – WSL2 Wi-Fi Sürücü Aracı
Version: V1.0.1

Geliştirici: Znuzhg Onyvxpv
Lisans: MIT

📌 Kısa Açıklama

RTL8821CU FixSuite, Windows + WSL2 üzerinde Realtek RTL8821CU USB Wi-Fi adaptörünü otomatik olarak WSL içine bağlayan, DKMS ile derleyip kuran ve kalıcı hale getiren gelişmiş bir araçtır.

Bu proje:

✔ Tek komutla sürücü kurar

✔ WSL2 ile Wi-Fi adaptörünü problemsiz kullanmanızı sağlar

✔ usbipd, DKMS ve kernel source işlemlerini otomatik yönetir

✔ Hataları otomatik düzeltir ve log oluşturur

✔ Off-line mod ile internetsiz ortamda kurulum yapabilir

🔥 Özellikler
Özellik	Açıklama
🔌 USBIPD Otomasyonu	Windows → WSL arası bind / detach / attach işlemleri
⚡ usbipd 5.3+ Desteği	attach --wsl sözdizimi (eski sürümler için fallback)
🛠️ DKMS Derleme Akışı	add → build → install (otomatik hata düzeltme dahil)
🔁 Kalıcılık	modules-load, udev rules, wsl.conf birleştirme
🌐 Off-line Mod	--no-network ile apt/clone adımlarını atlama
🧠 AI Log Analizi	ai_helper.py summarize ile JSON hata raporu
📦 Kernel Source Fallback	Headers yoksa WSL kernel source hazırlanır
🔄 İdempotent Betikler	Tekrar tekrar güvenle çalıştırılabilir
📂 Proje Klasör Yapısı

Aşağıdaki tablo FixSuite içerisindeki dosya ve klasörlerin anlamını gösterir:

📁 Klasör / Dosya	📝 Açıklama
setup.ps1	Windows tarafı usbipd yönetimi, bind/detach/attach, loglama
update.sh	WSL bağımlılık kurulumu, headers kontrolü, off-line mod
rtl8821cu_wsl_fix.sh	DKMS derleme, kernel source fallback, kalıcılık ayarları
ai_helper.py	Log → JSON özetleme ve hata analizi
logs/	Windows & WSL logları, latest sembolik bağlantısı
README.md	Projenin teknik dokümantasyonu

Bu tablo formatı Medium + GitHub uyumlu olup %100 doğru çizilir.

🖥️ Desteklenen Sistemler

Windows 10 / 11

WSL2 (Kali, Ubuntu, Debian)

usbipd-win 5.3+

Windows tarafında Admin yetkisi

WSL tarafında root / sudo yetkisi

🚀 Kurulum (Adım Adım)
1️⃣ WSL’de proje dizinine gidin
cd /mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FixSuite/

2️⃣ update.sh ile bağımlılıkları yükleyin
sudo DEBIAN_FRONTEND=noninteractive bash update.sh


Ağ yoksa:

sudo bash update.sh --no-network

3️⃣ Windows tarafında setup.ps1 çalıştırın
cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File -Path .\setup.ps1


Cihazı bağlayın:

.\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose

4️⃣ WSL’de sürücüyü kurun
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix


Off-line:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network

🔌 USBIPD Komutları
Komut	Açıklama
usbipd list	USB cihazlarını listeler
usbipd bind --busid 2-13	Cihazı paylaşılabilir hale getirir
usbipd attach --busid 2-13 --wsl	Cihazı WSL’e bağlar
usbipd detach --busid 2-13	Bağlantıyı keser

⚠️ WSL yeniden başlatıldığında yeniden bağlamak gerekir:

usbipd.exe attach --busid --wsl <DISTRO_NAME>

📄 Loglama

Windows Logları:

logs\YYYYmmdd_HHMMSS\setup.log


WSL Logları:

logs/YYYYmmdd_HHMMSS/run.log
logs/latest


AI özetleme:

python3 ai_helper.py summarize logs/latest/run.log

🟢 Kurulum Kontrolü
Cihaz görünüyor mu?
lsusb | grep -i 0bda:c811

Modül yüklü mü?
lsmod | grep '^8821cu'
modinfo 8821cu

Arayüz var mı?
ip -br link
rfkill list

❗ Sık Hatalar ve Çözümleri
Hata	Sebep	Çözüm
usbipd bulunamadı	usbipd-win kurulu değil	winget install dorssel.usbipd-win
Not shared	Cihaz paylaşıma açılmamış	usbipd bind --busid
DKMS build failed	eksik semboller	--auto-fix kullanın
linux-headers yok	WSL kernel özel	fallback otomatik devreye girer
WLAN görünmüyor	adaptör bağlanmadı	wsl --shutdown sonra yeniden bağlayın
🔐 Güvenlik

Betikler güvenle tekrar çalıştırılabilir

Off-line mod ile internetsiz ortamda çalışır

Hiçbir kişisel veri işlemez

🤝 Katkı

CONTRIBUTING.md

CODE_OF_CONDUCT.md

SECURITY.md

📜 Lisans

MIT License
© 2025 Znuzhg Onyvxpv
