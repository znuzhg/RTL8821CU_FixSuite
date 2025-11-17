# 🚀 RTL8821CU FixSuite – WSL2 Wi-Fi Sürücü Aracı  
**Sürüm:** V1.0.1  
**Geliştirici:** Znuzhg Onyvxpv  
**Lisans:** MIT  

---

## 📌 Kısa Açıklama

**RTL8821CU FixSuite**, Windows + WSL2 üzerinde **Realtek RTL8821CU USB Wi-Fi adaptörünü**, usbipd kullanarak WSL içine otomatik bağlayan; DKMS ile derleyip kuran; kalıcı, güvenli ve tamamen otomatik bir çözüm aracıdır.

Bu araç:

- ✔ Tek komutla sürücü kurar  
- ✔ WSL2 içinde Wi-Fi adaptörünü sorunsuz kullanmanızı sağlar  
- ✔ usbipd, DKMS ve kernel source adımlarını otomatik yönetir  
- ✔ Otomatik düzeltme mekanizmasına sahiptir  
- ✔ Off-line mod ile internetsiz ortamda bile kurulabilir  

---

## 🔥 Özellikler

| Özellik | Açıklama |
|--------|----------|
| 🔌 USBIPD otomasyonu | Windows → WSL arası bind / detach / attach işlemleri |
| ⚡ usbipd 5.3+ desteği | `usbipd attach --wsl` sözdizimi, eski sürümler için fallback |
| 🛠️ DKMS derleme akışı | `add → build → install` + yaygın hatalar için otomatik düzeltme |
| 🔁 Kalıcılık | `modules-load`, `udev rules`, `wsl.conf` birleştirme ve autoload |
| 🌐 Off-line mod | `--no-network` ile apt ve git clone adımlarını atlar |
| 🧠 AI log analizi | `ai_helper.py summarize` ile JSON özet ve hata analizi |
| 📦 Kernel source fallback | Headers yoksa WSL kernel source indirip hazırlama |
| 🔄 İdempotent betikler | Betikler güvenle tekrar tekrar çalıştırılabilir |

---

## 📂 Proje Klasör Yapısı

Aşağıdaki tablo FixSuite içindeki dosya ve klasörlerin işlevlerini gösterir:

| Klasör / Dosya | Açıklama |
|----------------|----------|
| `setup.ps1` | Windows tarafı usbipd yönetimi, bind / detach / attach, loglama |
| `update.sh` | WSL bağımlılık kurulumu, headers kontrolü, off-line mod |
| `rtl8821cu_wsl_fix.sh` | DKMS derleme, kernel source fallback, kalıcılık ayarları |
| `ai_helper.py` | Log → JSON özetleme ve hata analizi |
| `logs/` | Windows & WSL logları, `latest` sembolik bağlantısı |
| `README.md` | Bu dokümantasyon dosyası |

---

## 🖥️ Desteklenen Sistemler

- Windows 10 / 11  
- WSL2 (Kali Linux, Ubuntu, Debian)  
- usbipd-win **5.3+**  
- Windows tarafında **Admin PowerShell**  
- WSL tarafında **root/sudo** yetkisi  

---

## 🚀 Kurulum (Adım Adım Kılavuz)

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
Headers bulunmazsa betik uyarır ve kernel source fallback ile devam eder.

3️⃣ Windows tarafında setup.ps1 çalıştırın (Admin)
powershell
Kodu kopyala
cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File -Path .\setup.ps1
Çalıştırın:

powershell
Kodu kopyala
.\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose
Notlar:

BusId verilmezse script Realtek cihazını otomatik bulur

“Not shared” → otomatik usbipd bind

“Attached” → otomatik usbipd detach

usbipd ≥ 5.3 → usbipd attach --wsl

Eski sürüm → fallback usbipd attach --busid

4️⃣ WSL içinde sürücüyü kurun
bash
Kodu kopyala
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
Off-line mod:

bash
Kodu kopyala
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network
🔌 USBIPD Komut Özeti
powershell
Kodu kopyala
# Cihazları listele
usbipd list

# Paylaşıma aç
usbipd bind --busid 2-13

# WSL'e bağla
usbipd attach --busid 2-13 --wsl kali-linux

# Varsayılan distro ile bağla
usbipd attach --busid 2-13

# Bağlantıyı kes
usbipd detach --busid 2-13
📌 WSL yeniden başlatıldığında (wsl --shutdown) cihazı tekrar bağlamanız gerekir:

powershell
Kodu kopyala
usbipd.exe attach --busid --wsl <DISTRO_NAME>
📄 Loglama
Windows logları:

arduino
Kodu kopyala
logs\YYYYmmdd_HHMMSS\setup.log
WSL logları:

bash
Kodu kopyala
logs/YYYYmmdd_HHMMSS/run.log
logs/latest
AI ile log özetleme:

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
Arayüz aktif mi?

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
usbipd bulunamadı	usbipd-win kurulu değil	winget install dorssel.usbipd-win
Cihaz "Not shared"	Paylaşım aktif değil	usbipd bind --busid 2-13
DKMS build failed	Eksik semboller veya kaynak	rtl8821cu_wsl_fix.sh --run --auto-fix
linux-headers yok	WSL kernel paketi mevcut değil	Kernel source fallback otomatik devreye girer
WLAN görünmüyor	Cihaz bağlanmamış / WSL kapalı	wsl --shutdown → tekrar attach

🔐 Güvenlik
Betikler tamamen idempotent çalışır

Off-line mod, internet olmayan ortamlarda kullanım içindir

Hiçbir kullanıcı verisi toplanmaz

🤝 Katkı Rehberi
Katkıda bulunmak isterseniz:

CONTRIBUTING.md

CODE_OF_CONDUCT.md

SECURITY.md

📜 Lisans
MIT License
© 2025 Znuzhg Onyvxpv
