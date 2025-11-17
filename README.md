# 🚀 RTL8821CU FixSuite – WSL2 Wi-Fi Sürücü Aracı  
**Version:** V1.0.1  
**Geliştirici:** Znuzhg Onyvxpv  
**Lisans:** MIT  

---

## 📌 Kısa Açıklama

RTL8821CU FixSuite, Windows + WSL2 üzerinde **Realtek RTL8821CU USB Wi-Fi adaptörünü** otomatik olarak WSL içine bağlayan, DKMS ile derleyip kuran ve kalıcı hale getiren bir araçtır.

Bu proje:

- Tek komutla sürücü kurar  
- WSL2 içinde Wi-Fi adaptörünü sorunsuz kullanmanı sağlar  
- usbipd, DKMS ve kernel source adımlarını otomatik yönetir  
- Hataları mümkün olduğunca otomatik düzeltir ve loglar  
- Off-line mod ile internetsiz ortamda da çalışabilir  

---

## 🔥 Özellikler

| Özellik | Açıklama |
|--------|----------|
| 🔌 USBIPD otomasyonu | Windows → WSL arası bind / detach / attach işlemleri |
| ⚡ usbipd 5.3+ desteği | `usbipd attach --wsl` sözdizimi, eski sürümler için fallback |
| 🛠️ DKMS derleme akışı | `add → build → install` ve yaygın hatalar için otomatik düzeltme |
| 🔁 Kalıcılık | `modules-load`, `udev rules`, `wsl.conf` birleştirme ve autoload |
| 🌐 Off-line mod | `--no-network` ile `apt` ve `git clone` adımlarını atlar |
| 🧠 AI log analizi | `ai_helper.py summarize` ile JSON özet ve hata analizi |
| 📦 Kernel source fallback | Headers yoksa WSL kernel source indirip hazırlar |
| 🔄 İdempotent betikler | Betikler güvenle tekrar tekrar çalıştırılabilir |

---

## 📂 Proje Klasör Yapısı

Aşağıdaki tablo, FixSuite içindeki dosya ve klasörlerin anlamını gösterir:

| Klasör / Dosya | Açıklama |
|----------------|----------|
| `setup.ps1` | Windows tarafı usbipd yönetimi, bind / detach / attach, loglama |
| `update.sh` | WSL bağımlılık kurulumu, headers kontrolü, off-line mod |
| `rtl8821cu_wsl_fix.sh` | DKMS derleme, kernel source fallback, kalıcılık ayarları |
| `ai_helper.py` | Log → JSON özetleme ve hata analizi |
| `logs/` | Windows ve WSL logları, `latest` sembolik bağlantısı |
| `README.md` | Bu dokümantasyon dosyası |

---

## 🖥️ Desteklenen Sistemler

- Windows 10 / 11  
- WSL2 (Kali, Ubuntu, Debian)  
- `usbipd-win` 5.3+  
- Windows tarafında **Admin PowerShell**  
- WSL tarafında **root / sudo** yetkisi  

---

## 🚀 Kurulum

### 1️⃣ WSL içinde proje dizinine gidin

```bash
cd /mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FixSuite/
2️⃣ update.sh ile bağımlılıkları yükleyin
bash
Kodu kopyala
sudo DEBIAN_FRONTEND=noninteractive bash update.sh
Ağ yoksa:

bash
Kodu kopyala
sudo bash update.sh --no-network
Bazı WSL kernel sürümlerinde linux-headers-$(uname -r) paketi bulunmayabilir. Bu durumda betik uyarı verir ve kernel source fallback ile devam eder.

3️⃣ Windows tarafında setup.ps1 çalıştırın
Admin PowerShell açın:

powershell
Kodu kopyala
cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File -Path .\setup.ps1
Cihazı bağlayın:

powershell
Kodu kopyala
.\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose
Notlar:

BusId vermediğinizde script Realtek (VID:PID=0bda:c811) cihazını otomatik bulmaya çalışır.

Cihaz “Not shared” ise önce usbipd bind --busid yapılır.

Cihaz “Attached” ise önce usbipd detach --busid ile ayrılır.

usbipd 5.3+ ise öncelik usbipd attach --busid --wsl.

Eski sürümlerde fallback: usbipd attach --busid.

4️⃣ WSL içinde sürücüyü kurun
bash
Kodu kopyala
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
Off-line mod:

bash
Kodu kopyala
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network
Betik, kernel source hazırlığı, DKMS add/build/install akışı, otomatik düzeltmeler ve kalıcılık ayarlarını yönetir.

🔌 USBIPD Komut Özeti (Windows)
powershell
Kodu kopyala
# Cihazları listele
usbipd list

# Cihazı paylaşıma aç
usbipd bind --busid 2-13

# Cihazı WSL'e bağla (usbipd 5.3+)
usbipd attach --busid 2-13 --wsl kali-linux

# Varsayılan distro için:
usbipd attach --busid 2-13

# Bağlantıyı kes
usbipd detach --busid 2-13
Not: WSL tamamen kapatılıp (wsl --shutdown) tekrar açıldığında, yeni bir Windows terminalde tekrar usbipd.exe attach --busid --wsl <DISTRO_NAME> komutunu çalıştırmanız gerekir.

📄 Loglama
Windows logları:

text
Kodu kopyala
logs\YYYYmmdd_HHMMSS\setup.log
WSL logları:

text
Kodu kopyala
logs/YYYYmmdd_HHMMSS/run.log
logs/latest   # son çalışmanın sembolik bağlantısı
AI özetleme:

bash
Kodu kopyala
python3 ai_helper.py summarize logs/latest/run.log
🟢 Kurulum Kontrolü
Cihaz görünüyor mu?

bash
Kodu kopyala
lsusb | grep -i 0bda:c811
Modül yüklü mü?

bash
Kodu kopyala
lsmod | grep '^8821cu'
modinfo 8821cu
Arayüz var mı?

bash
Kodu kopyala
ip -br link
rfkill list
Gerekirse:

bash
Kodu kopyala
sudo ip link set wlan0 up
rfkill unblock all
❗ Sık Karşılaşılan Hatalar
Hata	Sebep	Çözüm
usbipd bulunamadı	usbipd-win kurulu değil	winget install dorssel.usbipd-win ile kurun
Cihaz "Not shared"	Cihaz paylaşıma açılmamış	usbipd bind --busid 2-13
Adaptör WSL'de görünmüyor	USB tekrar bağlanmamış	wsl --shutdown → WSL aç → yeniden attach
DKMS build failed	Eksik semboller / kaynak	sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix ve make.log incele
linux-headers yok	Bazı WSL kernel sürümleri için paket yok	Betik kernel source fallback ile devam eder

🔐 Güvenlik
Betikler idempotent çalışacak şekilde tasarlanmıştır.

Off-line mod, internet erişimi olmayan ortamlarda kullanım içindir.

Kullanıcıya ait kişisel veri toplanmaz veya dışarı gönderilmez.

🤝 Katkı
Katkıda bulunmak isterseniz lütfen şu belgeleri inceleyin:

CONTRIBUTING.md

CODE_OF_CONDUCT.md

SECURITY.md

📜 Lisans
Bu proje MIT Lisansı ile lisanslanmıştır.
© 2025 Znuzhg Onyvxpv
