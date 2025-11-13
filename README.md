• # RTL8821CU WSL2 FIX TOOL (Final v1.0)

  Geliştirici: Znuzhg Onyvxpv
  Lisans: MIT

  Kısa Açıklama

  - Bu proje, Windows + WSL2 ortamında Realtek RTL8821CU USB Wi‑Fi adaptörünü WSL içine güvenle bağlar, DKMS ile
    sürücüyü derleyip kurar ve kalıcılığı etkinleştirir. Tüm akış idempotent (güvenle yeniden çalıştırılabilir),
    off‑line uyumlu ve ayrıntılı loglamaya sahiptir.

  Özellikler

  - Tam otomasyon: Windows tarafında usbipd ile bağlama; WSL tarafında bağımlılık kurulumu + DKMS derleme + kalıcılık
  - usbipd‑win 5.3+ sözdizimi (attach --wsl) desteği ve geriye dönük fallback
  - Cihaz durumu yönetimi: “Not shared” ise otomatik bind; “Attached” ise önce detach
  - DKMS döngüsü (add → build → install) ve sık hatalar için otomatik düzeltme denemeleri (Module.symvers, modpost/
    Undefined, KERNEL_SOURCE_DIR/PWD)
  - Kalıcılık: /etc/modules-load.d, /etc/udev/rules.d, /etc/wsl.conf güvenli birleştirme ve dinamik autoload betiği
    (sürümü otomatik algılar)
  - Off‑line uyum: --no-network ile apt ve klonlama adımları atlanır (paketler/kaynaklar önceden sağlanmalı)
  - Ayrıntılı günlükler ve JSON özetleme (ai_helper.py) ile hızlı teşhis

  Desteklenen Sistemler

  - Windows 10/11 + WSL2
  - WSL dağıtımları: Kali Linux, Ubuntu, Debian
  - usbipd‑win 5.3+ (yeni sözdizimi). Eski sürümler için fallback davranışı
  - Yetkiler: Windows tarafında Yönetici (Admin), WSL tarafında root (sudo)

  Mimari ve Bileşenler

  - setup.ps1 (Windows): usbipd ile cihazı WSL’e bağlar; BusId doğrulama, bind/detach, yeni sözdizimi ve fallback
    desteği, kapsamlı loglama
  - update.sh (WSL): bağımlılıkların kurulumu (apt), kernel headers denemesi (başarısızsa yalnızca uyarı), off‑line
    desteği
  - rtl8821cu_wsl_fix.sh (WSL): kernel kaynak hazırlığı (headers yoksa kernel source fallback), DKMS döngüsü,
    otomatik düzeltmeler ve kalıcılık

  Kurulum Adımları (Sırasıyla)

  1. WSL2 açılır

  - WSL terminalinde proje dizinine gidin:

    cd /mnt/c/Users/<kullanıcı>/Downloads/RTL8821CU_FxSuite/

  2. update.sh ile tüm bağımlılıklar kurulur

  - Root ile çalıştırın:

    sudo DEBIAN_FRONTEND=noninteractive bash update.sh
  - Ağ kısıtlı ise (off‑line):

    sudo bash update.sh --no-network
  - Not: Bazı WSL çekirdeklerinde linux-headers-$(uname -r) bulunmayabilir; bu durumda betik yalnızca uyarır. DKMS
    derlemesi, kernel source fallback ile (WSL kernel kaynaklarını indirip hazırlayarak) sürdürülecektir.

  3. Windows PowerShell üzerinde setup.ps1 çalıştırılır

  - Yönetici PowerShell açın; proje klasörüne gidin:

    cd C:\Users\<kullanıcı>\Downloads\RTL8821CU_FxSuite\
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    Unblock-File -Path .\setup.ps1
  - Cihazı bağlayın:

    .\setup.ps1 -AutoAttach -DistroName "kali-linux" -BusId "2-13" -Force -Verbose
  - Açıklamalar:
      - BusId vermediğinizde script Realtek (VID:PID=0bda:c811) cihazını otomatik seçer.
      - “Not shared” cihazlar için önce usbipd bind --busid <id> yapılır; “Attached” ise detach edilir.
      - usbipd 5.3+ sözdizimi önceliklidir: usbipd attach --busid <id> --wsl <distro>
      - --wsl desteklenmezse fallback: usbipd attach --busid <id>

  4. WSL içinde otomatik olarak rtl8821cu_wsl_fix.sh kullanılır

  - Bağlama tamamlandıktan sonra WSL tarafında sürücü kurulumu:

    cd /mnt/c/Users/<kullanıcı>/Desktop/RTL8821CU_FxSute-local/repo
    sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix
  - Ağ kısıtlı ise:

    sudo bash rtl8821cu_wsl_fix.sh --run --auto-fix --no-network
  - Betik, kernel kaynaklarını hazırlayıp (headers yoksa Microsoft WSL kernel source fallback ile), DKMS add/build/
    install akışını çalıştırır; hatalarda otomatik düzeltme dener ve kalıcılık ayarlarını güvenle etkinleştirir.

  USB Passthrough (usbipd) Rehberi

  - Cihazları listele (Windows PowerShell, Admin):

    usbipd list
  - “Not shared” ise:

    usbipd bind --busid <BUSID>
  - Bağlamak (usbipd 5.3+):

    usbipd attach --busid <BUSID> --wsl kali-linux
    veya varsayılan dağıtım için:

    usbipd attach --busid <BUSID>
  - Gerekirse ayırma:

    usbipd detach --busid <BUSID>

  Komut Satırı Referansı (Özet)

  - setup.ps1 (Windows):
      - Parametreler: -AutoAttach, -DistroName <ad>, -BusId <X-Y>, -DryRun, -Force, -LogDir <yol>
      - Örnek:

        .\setup.ps1 -AutoAttach -DistroName "Ubuntu-22.04" -BusId "2-13" -Force -Verbose
  - update.sh (WSL):
      - Parametre: --no-network (opsiyonel)
      - Örnek:

        sudo DEBIAN_FRONTEND=noninteractive bash update.sh
        sudo bash update.sh --no-network
  - rtl8821cu_wsl_fix.sh (WSL):
      - Parametreler: --run, --dry-run, --auto-fix, --force-manual, --no-network, --log-dir <yol>
      - Örnek:

        sudo bash rtl8821cu_wsl_fx.sh --run --auto-fix
        sudo bash rtl8821cu_wsl_fx.sh --run --auto-fix --no-network

  Loglama ve Çıkış Kodları

  - Tüm betikler “START/INFO/WARN/ERROR/DONE” formatında log üretir.
  - Windows tarafı logları: setup.ps1 için logs\YYYYmmdd_HHMMSS\setup.log
  - WSL tarafı logları: rtl8821cu_wsl_fix.sh için logs/YYYYmmdd_HHMMSS/run.log ve logs/latest sembolik bağlantısı
  - a_helper.py summarize <log> ile JSON özet ve status: success|failure alanı üretilebilir.
  - Hata durumunda betikler non‑zero (başarısız) çıkış kodu verir.

  Başarılı Kurulum Belirtileri (WSL İçinde)

  - lsusb:

    lsusb | grep -i 0bda:c811
  - Modül yüklü:

    lsmod | grep '^8821cu'
    modinfo 8821cu
  - Arayüz:

    ip -br link | grep -Ei '\b(wlan|wl|wifi)'
    iw dev
    rfkill list

  Güvenlik ve İdempotency

  - Betikler güvenle tekrar çalıştırılabilir; mevcut durum (bind/detach, var olan DKMS kaynakları, wsl.conf)
    gözetilir ve yalnızca gerekli adımlar uygulanır.
  - Sadece WSL içinde, sürücü/kernel kaynağı gereksinimi olduğunda git clone; yama uygulamada git apply kullanılır
    (off‑line modda atlanır).

  Sık Karşılaşılan Hatalar ve Çözümler

  - usbipd bulunamadı:
      - Microsoft Store veya:

        winget install dorssel.usbipd-win
      - Servisi başlatın:

        Start-Service usbipd
  - Cihaz “Not shared”:

    usbipd bind --busid <BUSID>
    Ardından attach komutunu yeniden çalıştırın.
  - Adaptör WSL’de görünmüyor:
      - wsl --shutdown ile WSL’i kapatıp yeniden başlatın:

        wsl --shutdown
        wsl -d <DistroName>
      - usbutils ve ağ araçlarının kurulu olduğundan emin olun (update.sh).
      - Adaptörü fiziksel olarak çıkarıp takmayı deneyin.
  - DKMS derleme hataları:
      - logs/latest/run.log ve python3 ai_helper.py summarize logs/latest/run.log çıktısını inceleyin.
      - Sık nedenler:
          - Module.symvers eksik → kernel source üzerine make modules_prepare; betik otomatik dener.
          - modpost/Undefined → kernel source yolunu ve hazırlığını doğrulayın; betik dkms.conf’u güvenli şekilde
            yeniden yazar.
          - linux-headers eksik → yalnızca uyarı; kernel source fallback devreye girer.

  Teşhis (Kısa)

  - wlan0 görünmüyorsa:
      1. lsusb | grep -i 0bda:c811 → aygıt WSL’de görünüyor mu?
      2. lsmod | grep '^8821cu' → modül yüklenmiş mi?
      3. ip -br link → arayüz var ama DOWN ise:

         sudo ip link set wlan0 up
      4. rfkill list → blok varsa rfkill unblock all.
  - dkms build failed:
      1. tail -n 200 /var/lib/dkms/8821cu/<ver>/build/make.log
      2. sudo bash rtl8821cu_wsl_fx.sh --run --auto-fix
      3. Gerekirse off‑line modu kaldırıp tekrar deneyin (kernel kaynak hazırlığı için).
  - USB görünmüyorsa:
      1. Windows’ta usbipd list ile doğrula.
      2. “Not shared” ise:

         usbipd bind --busid <BUSID>
      3. Bağla:

         usbipd attach --busid <BUSID> --wsl <DistroName>
         veya:

         usbipd attach --busid <BUSID>
      4. Gerekirse:

         usbipd detach --busid <BUSID>
  Not : "wsl kapatılıp tekrar açıldığında yeni bir windows terminalde [ usbipd.exe attach --busid <BUSID> --wsl <DISTRO_NAME> ] yapılması gerekir"
