# RTL8821CU FixSuite – WSL2 Wi-Fi Sürücü Aracı

**Sürüm:** v3  
**Geliştirici:** Znuzhg Onyvxpv  
**Lisans:** MIT (FixSuite betikleri ve özgün dosyalar)

RTL8821CU FixSuite, Realtek RTL8821CU USB Wi-Fi adaptörünün Windows üzerinden WSL2 içindeki Kali, Debian veya Ubuntu dağıtımına bağlanmasını ve Linux sürücüsünün kurulmasını kolaylaştırır.

Proje, önce Linux çekirdeğinin kendi \`rtw88_8821cu\` sürücüsünü ve firmware'i kullanmayı dener. WSL ortamında firmware bulunamaz veya cihaz çalışmazsa WSL çekirdek kaynağını hazırlar ve \`8821cu\` sürücüsünü DKMS üzerinden kurmayı dener.

## Gereksinimler

- Windows 10/11 ve WSL2 kurulumu.
- WSL2 üzerinde Kali Linux, Debian veya Ubuntu.
- Windows tarafında usbipd-win.
- Sürücü kurulumu için WSL içinde root/\`sudo\` yetkisi.
- DKMS yolu için internet bağlantısı (kaynakları indirmek için) veya önceden hazırlanmış yerel kaynak.
- \`git\`, \`dkms\`, \`build-essential\`, \`make\` ve çekirdek derleme bağımlılıkları.

Windows tarafında usbipd-win'i kurmak için yönetici PowerShell'de:

\`\`\`powershell
winget install --interactive --exact dorssel.usbipd-win
\`\`\`

Winget kullanılamıyorsa resmi sürümler: [dorssel/usbipd-win Releases](https://github.com/dorssel/usbipd-win/releases).

## Kurulum ve kullanım

### 1. Depoyu WSL içine alın

Örnek:

\`\`\`bash
git clone https://github.com/znuzhg/RTL8821CU_FixSuite.git
cd RTL8821CU_FixSuite
\`\`\`

### 2. Bağımlılıkları hazırlayın

\`\`\`bash
sudo bash update.sh
\`\`\`

İnternet kullanmadan yalnızca mevcut paketleri kontrol etmek için:

\`\`\`bash
sudo bash update.sh --no-network
\`\`\`

\`update.sh\` sistem genelinde \`apt-get upgrade\` çalıştırmaz. Yalnızca FixSuite'in ihtiyaç duyduğu eksik paketleri kurar. \`autoremove\` varsayılan olarak kapalıdır; açıkça istendiğinde \`--autoremove\` kullanılır.

### 3. USB adaptörünü Windows'tan WSL'e bağlayın

PowerShell'i yönetici olarak açın ve cihazları listeleyin:

\`\`\`powershell
usbipd list
\`\`\`

RTL8821CU cihazının BUSID değerini kullanarak cihazı paylaşın:

\`\`\`powershell
usbipd bind --busid <ID>
\`\`\`

Ardından WSL'e bağlayın:

\`\`\`powershell
usbipd attach --wsl --busid <ID>
\`\`\`

Otomatik yeniden bağlanma seçeneği desteklenen usbipd-win sürümlerinde:

\`\`\`powershell
usbipd attach --wsl --busid <ID> --auto-attach
\`\`\`

Bağlantıyı ayırmak için:

\`\`\`powershell
usbipd detach --busid <ID>
\`\`\`

\`detach\` komutunda \`--wsl\` kullanılmaz.

İsteğe bağlı olarak proje içindeki PowerShell betiği de kullanılabilir:

\`\`\`powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Unblock-File .\\setup.ps1
.\\setup.ps1 -AutoAttach
\`\`\`

Betiğe \`-BusId <ID>\` veya \`-DistroName <dağıtım>\` verilebilir. BUSID belirtilmezse betik \`0bda:c811\` VID:PID değerine göre Realtek cihazını bulmayı dener.

### 4. WSL içinde sürücüyü kurun

Önce DRY-RUN ile planlanan işlemleri inceleyin:

\`\`\`bash
sudo bash rtl8821cu_wsl_fix.sh
\`\`\`

Gerçek kurulum:

\`\`\`bash
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
\`\`\`

Varsayılan davranış DRY-RUN'dır. DRY-RUN sırasında sistem paketleri, sürücüler veya yapılandırma dosyaları değiştirilmez; çalışma logları yine de oluşturulur.

## Script parametreleri

| Parametre | Açıklama |
|---|---|
| \`--run\` | Gerçek işlemleri uygular. |
| \`--dry-run\` | Komutları simüle eder. Varsayılandır. |
| \`--auto-fix\` | DKMS hataları için otomatik düzeltme adımlarını dener. |
| \`--force-manual\` | DKMS başarısız olursa manuel derlemeye geçer. |
| \`--force-dkms\` | Firmware/çekirdek içi sürücü yolu çalışsa bile DKMS yolunu da dener. |
| \`--skip-firmware\` | Firmware ve çekirdek içi sürücü adımını atlar. |
| \`--no-network\` | Ana scriptte apt/git ağ erişimini kapatır; eksik yerel kaynaklar kendiliğinden sağlanmaz. |
| \`--log-dir PATH\` | Log dizinini belirler. |
| \`--project-root PATH\` | Proje kök dizinini belirler. |
| \`-h\`, \`--help\` | Yardımı gösterir. |

Bağımlılık aracı \`update.sh\` parametreleri:

| Parametre | Açıklama |
|---|---|
| \`--no-network\` | Ağ erişimini kullanmaz; eksik paket varsa hata verir. |
| \`--autoremove\` | İsteğe bağlı apt autoremove temizliğini çalıştırır. Varsayılan değildir. |
| \`-h\`, \`--help\` | Yardımı gösterir. |

## Çalışma akışı

1. **Firmware ve çekirdek içi sürücü:** \`firmware-realtek\` veya uygun firmware paketini kontrol eder, \`rtw88_8821cu\` sürücüsünü dener ve USB cihazını resetler.
2. **WSL çekirdek kaynağı ve DKMS:** Uygun çekirdek ağacını arar. Uygun ağaç yoksa WSL çekirdek kaynağını hazırlar, sürücü kaynağını alır ve DKMS ile derleyip kurar.
3. **Manuel fallback:** DKMS başarısız olursa ve \`--force-manual\` verilmişse manuel derleme denenir.

## WSL2 hakkında önemli notlar

- WSL çekirdeği güncellenirse sürücü modülü yeni çekirdek için yeniden hazırlanmalıdır. Güncellemeden sonra scripti tekrar çalıştırın.
- \`modules_prepare\` tek başına her WSL çekirdeği için tam \`Module.symvers\` üretmeyebilir. Bu nedenle \`no symbol version for module_layout\` ve \`taints kernel\` gibi mesajlar bazı derlemelerde görülebilir. Bu mesajlar tek başına sürücünün çalışmadığını kanıtlamaz; DKMS sonucu, \`modprobe\`, arayüzün oluşması ve gerçek bağlantı ayrıca doğrulanmalıdır.
- Linux çekirdeği 6.12 ve üzerini kullanan standart dağıtımlarda morrownr/8821cu belgesi çekirdeğin kendi \`rtw88\` sürücüsünü önerir. FixSuite de önce çekirdek içi sürücüyü dener. WSL ortamında firmware'e erişim sorunu yaşanırsa DKMS yedek yolunu kullanır.
- Her \`wsl --shutdown\` sonrasında USB cihazının WSL'e yeniden bağlanması gerekir. Bunun için \`usbipd attach --wsl --busid <ID>\` veya desteklenen sürümlerde \`--auto-attach\` kullanın. \`--auto-forward\`, USB cihazı bağlama seçeneği değildir.
- \`--no-network\` yalnızca ağ işlemlerini atlar; gerekli paketlerin ve kaynakların önceden mevcut olmasını gerektirir.

## Doğrulama ve sorun giderme

WSL içinde:

\`\`\`bash
lsusb | grep -i '0bda:c811'
dmesg | grep -Ei 'rtw|8821'
iw dev
ip -br link
modinfo 8821cu
lsmod | grep '^8821cu'
\`\`\`

Cihaz \`lsusb\` çıktısında görünmüyorsa önce Windows tarafında \`usbipd list\` ve \`usbipd attach\` durumunu kontrol edin. Cihaz görünüyor ancak kablosuz arayüz oluşmuyorsa log dosyasını ve güncel kernel mesajlarını inceleyin.

Çalışma logları proje dizininde \`logs/<zaman-damgası>/run.log\` altında tutulur. Son çalışma için \`logs/latest/run.log\` bağlantısı kullanılır. JSON özet:

\`\`\`bash
python3 ai_helper.py summarize logs/latest/run.log
\`\`\`

DKMS derleme logları DKMS tarafından \`/var/lib/dkms/8821cu/\` altında tutulur.

## Lisans ve harici sürücü

FixSuite'in kendi betikleri ve dokümantasyonu MIT lisansı kapsamındadır. Betik, sürücü kaynağını gerektiğinde [morrownr/8821cu-20210916](https://github.com/morrownr/8821cu-20210916) deposundan indirir. Bu harici sürücü GPL-2.0 lisanslıdır ve kendi lisans koşullarına tabidir. Sürücü kaynak kodu bu depoya vendor olarak eklenmez.

## Sorumluluk reddi

Bu proje olduğu gibi sunulur. Donanım, WSL çekirdeği, dağıtım ve sürücü sürümüne göre sonuçlar değişebilir. Sistem dosyalarında değişiklik yapılmadan önce logları inceleyin ve önemli verilerin yedeğini alın. Proje, veri kaybı, donanım arızası veya kullanım kaynaklı diğer zararlardan sorumlu tutulamaz.

Katkı ve güvenlik bildirimi için [CONTRIBUTING.md](CONTRIBUTING.md) ve [SECURITY.md](SECURITY.md) dosyalarına bakın.
