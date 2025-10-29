# 🧰 RTL8821CU WSL2 FIX SUITE

### Author
**Znuzhg Onyvxpv**

---

## 📘 Genel Bakış

Bu proje, **WSL2 altında Realtek RTL8821CU kablosuz adaptörünün** doğru şekilde çalışması için geliştirilmiş tam otomatik bir araç setidir.  
Araç seti, Windows–WSL ikili ortamında çalışan üç ana bileşenden oluşur:

| Bileşen | Açıklama |
|----------|-----------|
| **setup.ps1** | Windows PowerShell üzerinden WSL ortamını hazırlar, kernel yapılandırmasını günceller ve gerekli dosyaları senkronize eder. |
| **rtl8821cu_wsl_fix.sh** | WSL (Debian/Ubuntu/Kali) içinde çalışarak RTL8821CU sürücüsünü DKMS üzerinden derler, yükler ve otomatik olarak hataları düzeltir. |
| **ai_helper.py** | `rtl8821cu_wsl_fix.sh` tarafından oluşturulan logları analiz eder, hataları ve önerileri JSON formatında özetler. |

---

## ⚙️ Kurulum Adımları

### 1️⃣ Windows Tarafında (PowerShell)

```powershell
powershell.exe -ExecutionPolicy Bypass -File setup.ps1
Bu adım:

Python ve Git kontrolünü yapar.

WSL tarafındaki betikleri senkronize eder.

Kernel imajı veya .wslconfig yapılandırmasını güncellemeye yardımcı olur.

Kullanılabilir Fonksiyonlar:

powershell

Set-WSLKernel -KernelImagePath <vmlinuz> [-UpdateConfig]
Copy-Toolset
Show-WSL-Restart-Steps
2️⃣ Linux Tarafında (WSL2 Terminal)
bash
Kodu kopyala
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
Desteklenen parametreler:

Parametre	Açıklama
--run	Gerçek derleme ve kurulum işlemini başlatır.
--dry-run	Simülasyon modudur, sistemde değişiklik yapmaz.
--auto-fix	DKMS hatalarını otomatik düzeltmeyi dener.
--force-manual	DKMS başarısız olursa manuel derleme moduna geçer.
--no-network	Ağ bağlantısı olmadan yerel kaynakları kullanır.
--log-dir <path>	Özel bir log dizini belirtir.

Örnek:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
🧠 Log Analizi (ai_helper.py)
Derleme tamamlandıktan sonra, tüm çıktılar JSON olarak özetlenir:

bash
Kodu kopyala
python3 ai_helper.py summarize logs/latest/run.log
Örnek çıktı:

json

{
  "timestamp": "2025-10-29T00:00:00Z",
  "errors": ["modpost: Undefined symbol"],
  "warnings": ["deprecated API"],
  "suggested_fixes": ["Re-run kernel prepare"],
  "applied_patches": ["patch_8821cu_power.diff"]
}
🧩 Proje Yapısı

RTL8821CU_FixSuite/
├── setup.ps1               # Windows ortam hazırlayıcı
├── rtl8821cu_wsl_fix.sh    # WSL2 sürücü onarıcı
├── ai_helper.py             # Log analiz ve özetleyici
├── logs/                   # Çalışma logları
│   ├── 20251029_031200/
│   └── latest -> 20251029_031200/
└── PATCHES_APPLIED          # Uygulanan yamaların kaydı
🛠️ Teknik Özellikler
Tam idempotent yapı: Aynı komutlar tekrar çalıştırıldığında sistem kararlılığını korur.

Otomatik loglama ve özetleme: Tüm çıktı logs/<timestamp> altında saklanır.

Kernel kaynak senkronizasyonu: WSL2 kernel kaynakları otomatik klonlanır ve modules_prepare aşaması yürütülür.

Yama yönetimi: PATCHES_APPLIED dosyası üzerinden hangi yamaların uygulandığı takip edilir.

Python entegrasyonu: ai_helper.py logları analiz eder, JSON çıktı sağlar.

🧾 Lisans
Bu proje açık kaynak olarak sunulmuştur.
Ticari veya kapalı kaynak türevlerde kullanılmadan önce yazılı izin alınması önerilir.

💡 Katkı ve Geliştirme
Pull Request ve Issue’lar memnuniyetle karşılanır.

Tüm geliştirme süreçlerinde kod stilinin ve modüler yapının korunması tavsiye edilir.

Yeni yamalar patch_*.diff veya patch_*.sh biçiminde eklenebilir.

Author: Znuzhg Onyvxpv
Version: 1.0.0
Last Updated: 2025-10-29

Compatibility: WSL2 (Ubuntu/Debian/Kali)
