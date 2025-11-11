🧰 RTL8821CU WSL2 FIX SUITE

Author: Znuzhg Onyvxpv
Sürüm: 1.0.0
Güncelleme: 2025-10-29

Bu rehber, WSL2 (Kali/Ubuntu/Debian tabanlı) içinde Realtek RTL8821CU USB Wi-Fi adaptörünü çalışır hâle getirmek amacıyla hazırlanmış araç setinin (Fix Suite) sade ama eksiksiz kullanım açıklamasıdır. Adımlar hem Windows (PowerShell) hem de WSL (bash) taraflarını kapsar.

İçindekiler (hızlı)

Genel bakış

Hızlı ön gereksinimler

Klasör yapısı ve dosyalar

Windows — setup.ps1 ile hazırlık (adım adım)

WSL — sürücü derleme ve kurulum (rtl8821cu_wsl_fix.sh)

USB yönlendirme (usbipd) — Windows tarafı

WSL içinde doğrulama (lsusb, ip, iw, airmon-ng)

log analizi ai_helper.py

Yaygın hatalar & çözümleri (basit anlatım)

Geri alma, güvenlik ve dikkat edilmesi gerekenler

Sıkça sorulan sorular (SSS)

İletişim / katkı

1 — Genel bakış (kısa)

Bu araç seti üç ana parça içerir:

setup.ps1 — Windows PowerShell ile çalışır. WSL tarafına dosyaları kopyalar, usbipd kontrolleri ve host ayarlarıyla yardımcı olur.

rtl8821cu_wsl_fix.sh — WSL (bash) içinde çalıştırılır. Driver kaynaklarını bulur/klonlar, gerekirse yamaları uygular, DKMS ile derler ve yükler. Otomatik düzeltmeler dener.

ai_helper.py — Log dosyalarını özetleyen küçük Python aracı (JSON çıktısı verir).

Hedef: WSL içinde adaptörü görünür kılmak (ör. wlan0) ve aircrack-ng, airmon-ng gibi araçlarla kullanılabilir hâle getirmek.

2 — Ön Gereksinimler (basit)

Windows (host):

Windows 10/11 (WSL2 destekli)

usbipd-win yüklü (Microsoft Store veya winget install --id=Microsoft.usbipd)

Yönetici (Admin) erişimi (usbipd attach/detach ve bazı .wslconfig değişiklikleri için gerekebilir)

PowerShell (Windows PowerShell veya PowerShell 7)

WSL dağıtımı (guest):

Kali / Ubuntu / Debian (apt tabanlı) — güncel paket listesi

sudo hakları

Aşağıdaki paketlerin kurulması (script içinde update.sh veya rtl8821cu_wsl_fix.sh --run --auto-fix ile otomatik kurulabilir):
git, dkms, build-essential, bc, flex, bison, libssl-dev, libelf-dev, dwarves, pkg-config, rsync, curl, ca-certificates, kmod, make, gcc, iw, wireless-tools, usbutils

3 — Proje / Klasör Yapısı

Örnek hedef klasör (Windows):

C:\Users\<kullanıcı>\Downloads\RTL8821CU_FixSuite


İçerikler:

RTL8821CU_FixSuite/
├─ setup.ps1
├─ rtl8821cu_wsl_fix.sh
├─ ai_helper.py
├─ update.sh
├─ logs/
│  ├─ 20251029_064721/
│  └─ latest -> 20251029_064721/
└─ PATCHES_APPLIED


WSL içindeki eşdeğeri:

/mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FixSuite

4 — Windows: setup.ps1 (adım adım, kolay)

PowerShell’i yönetici olarak açın (sağ tuş → "Run as administrator").

FixSuite dizinine gidin:

cd "C:\Users\mahmu\OneDrive\Belgeler\Projeler_ai\CascadeProjects\windsurf-project\RTL8821CU_FixSuite"


İlk hazırlıkları simülasyon ile kontrol:

.\setup.ps1 -DryRun


Hazırlıkları gerçek çalıştırma ile yapmak için:

.\setup.ps1 --run


Adaptörü otomatik bağlamak isterseniz (non-interactive):

.\setup.ps1 -AutoAttach -BusId "2-13" -DistroName "kali-linux" -Force


-BusId usbipd list çıktısındaki BUSID (örn 2-13).

-DistroName bağlamak istediğiniz WSL dağıtımının adı.

-Force onay istemeden çalıştırır (dikkatli olun).

setup.ps1 ne yapar (özet):

Gerekliyse usbipd kontrolü yapar.

Hedef dizini WSL ile senkronize eder (ai_helper.py ve bash scriptleri).

Kullanıcıya WSL yeniden başlatma/ek adımlarını gösterir.

Opsiyonel: .wslconfig güncelleme veya özel kernel kurma adımlarını kolaylaştırır (sorulduğunda onay ister).

5 — WSL: rtl8821cu_wsl_fix.sh (kullanım)

WSL dağıtımınızda şu adımları izleyin:

WSL terminalini açın (örn wsl -d kali-linux).

FixSuite dizinine erişin:

cd /mnt/c/Users/mahmu/OneDrive/Belgeler/Projeler_ai/CascadeProjects/windsurf-project/RTL8821CU_FixSuite


Önce sistem paketlerini kurun (örnek update.sh varsa çalıştırın):

sudo bash update.sh


Sürücüyü dry-run ile test edin:

sudo bash rtl8821cu_wsl_fix.sh --dry-run


Asıl kurulum:

sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix


Önemli parametreler

--run : gerçek değişiklikleri uygular.

--dry-run veya --no-network : değişiklik yapmaz; ağsız moda izin verir.

--auto-fix : sık görülen DKMS/make hatalarını otomatik düzeltmeye çalışır.

--force-manual : DKMS başarısız olursa manuel make -> insmod yolunu dener.

--log-dir /path/to/logs : özel log dizini belirtir.

Script hangi adımları otomatik yapar:

Kernel kaynaklarını hazırlar (varsa /lib/modules/$(uname -r)/build kullanır; yoksa Microsoft WSL kernel kaynaklarını klonlayıp modules_prepare çalıştırır).

Sürücü kaynağını (varsa local kopya; yoksa morrownr/8821cu) kullanır.

Var olan dkms.conf hatalarını temizler ve idempotent dkms.conf yazar.

dkms add/build/install akışını uygular; hatalarda make.log analiz edip düzeltme dener.

Başarı/başarısızlık logunu logs/ altına yazar.

6 — USB yönlendirme: usbipd (Windows)

USB cihazlarını listeleme:

usbipd.exe list


Çıktıda BUSID (ör. 2-13) ve VID:PID görünür. RTL cihaz tipik olarak 0bda:c811 veya 0bda:c811 benzeri Realtek VID:PID olur.

Cihazı WSL dağıtımına bağlama:

usbipd.exe attach --busid 2-13 --wsl kali-linux


Not: Bazı usbipd sürümlerinde --wsl parametresi kaldırılmıştır; bu durumda usbipd attach --busid 2-13 yeterlidir ve usbipd varsayılan WSL dağıtımına takar.

Bağlı cihazı kaldırma:

usbipd.exe detach --busid 2-13
# veya tümünü kaldırmak için
usbipd.exe detach -a

7 — WSL içinde doğrulama (basit)

WSL içine cihaz bağlıysa şu komutlar ile kontrol edin:

USB cihazlarını listele:

lsusb
# örnek beklenen satır:
# Bus 001 Device 003: ID 0bda:c811 Realtek Semiconductor Corp. 802.11ac NIC


Ağ arayüzlerini kontrol et:

ip link show
# wlan0 veya yeni bir 'wl...' arayüzü görünmeli


Kablosuz arayüzlerini görmek:

iw dev


Eğer arayüz DOWN ise etkinleştir:

sudo ip link set wlan0 up


airmon-ng, aircrack-ng kontrolü:

sudo airmon-ng check
sudo airmon-ng start wlan0


Eğer airmon-ng arayüzü göstermiyorsa, sürücü doğru yüklenmemiş olabilir — rtl8821cu_wsl_fix.sh loglarını kontrol edin.

8 — Log analizi: ai_helper.py

Kullanım:

python3 ai_helper.py summarize logs/latest/run.log


JSON örneği:

{
  "timestamp": "2025-10-29T00:00:00Z",
  "errors": ["modpost: Undefined symbol"],
  "warnings": ["deprecated API"],
  "suggested_fixes": ["Re-run kernel prepare"],
  "applied_patches": ["patch_8821cu_power.diff"]
}


ai_helper.py insan ve makine tarafından okunacak çıktılar üretir; hataları, uyarıları, özet ve öneriler verir.

9 — Yaygın Hatalar & Basit Çözümleri
Hata: Module.symvers is missing / modpost undefined symbol

Sebep: Kernel kaynakları doğru hazırlanmadı veya Module.symvers eksik.

Çözüm: WSL içinde sudo make -C /usr/src/wsl-kernel-src modules_prepare -j$(nproc) çalıştırın (script bunu otomatik dener). Eğer mümkün değilse --force-manual ile manuel derleme talimatları izlenir.

Hata: dkms add sırasında command not found veya MAKE[0] hatası

Sebep: dkms.conf içinde shell genişleyen ifadeler dkms add aşamasında değerlendiriliyor.

Çözüm: Script idempotent, güvenli dkms.conf yazar; MAKE[0]="make -C /usr/src/wsl-kernel-src M=$PWD" benzeri literal biçim kullanılır.

WSL içinde lsusb cihazı görmüyorum

Sebep: usbipd ile cihaz bağlanmamış veya dağıtım uygun değil.

Çözüm: Windows PowerShell (Admin) usbipd.exe list ile BUSID bulun, usbipd.exe attach --busid <BUSID> --wsl <distro> ile bağlayın; sonra WSL lsusb çalıştırın. Gerekirse wsl --shutdown ardından wsl -d <distro> ile yeniden başlatın.

DKMS build başarısızsa

İlk olarak --auto-fix ile tekrar deneyin.

Hala başarısızsa: --force-manual ile .ko derlenip /lib/modules/$(uname -r)/extra/ altına kopyalanıp depmod -a ve modprobe 8821cu çalıştırılabilir. Script bu adımları açıkça gösterir.

10 — Geri alma, güvenlik ve dikkat edilmesi gerekenler

Scriptler idempotent olarak tasarlanmıştır — yeniden çalıştırılabilir. Yine de --run komutunu çalıştırmadan önce --dry-run ile test etmek şiddetle önerilir.

setup.ps1 Windows tarafında .wslconfig veya kernel image değişiklikleri yaparken kullanıcı onayı ister. Her zaman yedek alınır (timestamp ile setup_old_versions/ altına).

Loglar logs/<timestamp>/setup.log olarak saklanır. Bu dosyaları paylaşırken kişisel bilgileri kaldırın.

11 — Sıkça Sorulan Sorular (SSS)

S: Windows’ta usbipd yoksa ne yapmalıyım?
C: winget install --id=Microsoft.usbipd veya Microsoft Store’dan usbipd-win yükleyin; PowerShell'i yönetici olarak çalıştırın.

S: Hangi komutlarla tamamen sıfırlayıp baştan başlayabilirim?
C:

# Windows: tüm usbipd attach'lerini kaldır
usbipd.exe detach -a

# WSL: DKMS modüllerini kaldırıp tekrar deneyin
sudo dkms remove -m 8821cu -v <version> --all


S: Hataları nereye raporlamalıyım?
C: Proje log klasöründeki en güncel setup.log ve WSL'deki /var/lib/dkms/8821cu/<version>/build/make.log dosyalarını paylaşmak hata çözümünü kolaylaştırır.

12 — İletişim / Katkı

Eğer daha fazla yardım veya geliştirme isterseniz, proje klasörü altındaki README.md / logs/ içeriklerini inceleyip ulaştırabilirsiniz. Açık kaynak katkıları hoş karşılanır — lütfen yama ve düzeltmeleri PATCHES_APPLIED/ klasörüne ekleyin.

Kısa Özet — Hızlı Başlangıç (3 komut)

Windows PowerShell (Admin):

cd "...\RTL8821CU_FixSuite"
.\setup.ps1 --run
# usbipd list => BUSID bul, ardından
usbipd.exe attach --busid 2-13 --wsl kali-linux


WSL (kali-linux):

cd /mnt/c/.../RTL8821CU_FixSuite
sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
# sonra:
lsusb
ip link show
sudo ip link set wlan0 up


