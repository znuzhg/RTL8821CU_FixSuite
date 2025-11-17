🚀 RTL8821CU FixSuite – WSL2 Wi-Fi Sürücü Aracı
Version: V1.0.1

Geliştirici: Znuzhg Onyvxpv
Lisans: MIT

🧩 Kısa Açıklama

RTL8821CU FixSuite, Windows + WSL2 üzerinde Realtek RTL8821CU USB Wi-Fi adaptörünü otomatik olarak WSL içine bağlayan, DKMS ile derleyip kuran ve kalıcı hale getiren kapsamlı bir çözüm aracıdır.

Bu proje:

✔ Tek komutla sürücü kurar

✔ WSL2 ile Wi-Fi adaptörünü problemsiz kullanmanızı sağlar

✔ usbipd, DKMS, kernel source gibi tüm adımları otomatik yönetir

✔ Hataları otomatik düzeltir ve loglar

🔥 Özellikler
Özellik	Açıklama
🔌 USBIPD Otomasyonu	Windows → WSL arası otomatik algılama, bind/detach, attach
⚡ Yeni usbipd 5.3+ Desteği	usbipd attach --wsl sözdizimi, eski sürümler için fallback
🛠️ DKMS Derleme Akışı	add → build → install + otomatik düzeltmeler
🔁 Kalıcılık	/etc/modules-load.d, /etc/udev/rules.d, wsl.conf birleştirme
🌐 Off-line Mod	--no-network ile apt/clone adımlarını atlama
🧠 AI Log Analizi	ai_helper.py summarize ile JSON rapor
🧩 Kernel Source Fallback	Headers yoksa WSL kernel source hazırlanır
📡 İdempotent	Betikler güvenle tekrarlanabilir
📂 Proje Klasör Yapısı

Aşağıdaki tablo, FixSuite içerisindeki klasörlerin anlamını gösterir:

📁 Klasör / Dosya	📝 Açıklama
setup.ps1	Windows tarafı USBIPD yönetimi, bind/detach/attach, loglama.
update.sh	WSL bağımlılık kurulumu, headers kontrolü, off-line destek.
rtl8821cu_wsl_fix.sh	DKMS derleme, kernel source fallback, kalıcılık ayarları.
ai_helper.py	Log → JSON özetleme ve hata analizi.
logs/	Windows & WSL logları, latest sembolik bağlantısı.
README.md	Bu belge.

Tablo formatı GitHub tarafından otomatik olarak çizilir.

🖥️ Desteklenen Sistemler

Windows 10 / 11

WSL2 (Kali, Ubuntu, Debian)

usbipd-win 5.3+

WSL tarafında root (sudo)

Windows tarafında Admin PowerShell

🚀 Kurulum (Adım Adım)
1️⃣ WSL2’de proje dizinine gidin
cd /mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FixSuite/

2️⃣ update.sh ile bağımlılıkları yükleyin
sudo DEBIAN_FRONTEND=noninteractive bash update.sh


Ağ yoksa:

sudo bash update.sh --no-network

3️⃣ Windows tarafında setup.ps1 çalıştırın

Admin PowerShell açın:

cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File -Path .\setup.ps1


Cihazı bağlayın:

.\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose


Notlar:

BusId verilmezse script Realtek cihazını otomatik bulur

“Not shared” cihaz → otomatik bind

“Attached” cihaz → otomatik detach

usbipd 5.3+: attach --wsl

Eski sürüm: fallback attach --busid

4️⃣ WSL içinde sürücü kurulumunu tamamlayın
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix


Off-line:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network

🧵 USBIPD (Windows) Komutları

Cihazları listele:

usbipd list


“Not shared” cihazı paylaşılabilir yap:

usbipd bind --busid 2-13


Bağlama:

usbipd attach --busid 2-13 --wsl kali-linux


Varsayılan dağıtım için:

usbipd attach --busid 2-13


Ayırma:

usbipd detach --busid 2-13


ℹ️ WSL yeniden başlatılırsa tekrar:

usbipd.exe attach --busid --wsl <DISTRO_NAME>

📄 Loglama

Windows:

logs\YYYYmmdd_HHMMSS\setup.log


WSL:

logs/YYYYmmdd_HHMMSS/run.log
logs/latest → en son çalışmayı gösterir


AI özetleme:

python3 ai_helper.py summarize logs/latest/run.log

🟢 Kurulum Kontrolü
Cihaz görünüyor mu?
lsusb | grep -i 0bda:c811

Modül yüklü mü?
lsmod | grep '^8821cu'
modinfo 8821cu

Arayüz aktif mi?
ip -br link
rfkill list

❗ Sık Karşılaşılan Hatalar
Hata	Açıklama	Çözüm
usbipd yok	Sistem usbipd kurulu değil	winget install dorssel.usbipd-win
Not shared	Cihaz paylaşıma açık değil	usbipd bind --busid
Adaptör görünmüyor	WSL bağlanmadı	wsl --shutdown → tekrar deneyin
Module.symvers eksik	Headers/source uyuşmuyor	fallback ile otomatik çözülür
modpost hatası	Kernel kaynak hazırlığı gerekli	script otomatik düzeltir
linux-headers yok	WSL kernel yapısı farklı	sadece uyarı → fallback
🔐 Güvenlik

Betikler güvenle yeniden çalıştırılabilir

Off-line mod ile internetsiz ortamda kullanılabilir

Hiçbir kişisel veri işlenmez

🤝 Katkı

Katkıda bulunmak istersen:

CONTRIBUTING.md

CODE_OF_CONDUCT.md

SECURITY.md

📜 Lisans

MIT License
© 2025 Znuzhg Onyvxpv
