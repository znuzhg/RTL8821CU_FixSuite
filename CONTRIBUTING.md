# Katkı Rehberi

RTL8821CU_FixSuite projesine katkı sağlamak istediğiniz için teşekkürler. Bu belge, hata bildirimleri, kod katkıları ve test sürecini açıklar.

## Hata bildirimi

Issue açarken aşağıdaki bilgileri ekleyin:

- Windows sürümü ve WSL sürümü.
- WSL dağıtımı ve \`uname -r\` çıktısı.
- USB adaptörünün VID:PID ve BUSID bilgisi.
- Çalıştırılan komut ve parametreler.
- İlgili \`run.log\` ve DKMS \`make.log\` bölümleri.
- Beklenen ve gerçekleşen davranış.

Log göndermeden önce kullanıcı adı, IP adresi, MAC adresi ve diğer özel bilgileri gözden geçirin.

## Pull Request süreci

1. Depoyu fork edin.
2. Tek bir amaca odaklanan dal oluşturun.
3. Küçük ve anlaşılır commit'ler hazırlayın.
4. Değişiklikleri mümkün olan en dar kapsamda test edin.
5. PR açıklamasında değişiklikleri, testleri ve bilinen sınırlamaları belirtin.

## Kod standartları

- Bash betikleri için \`set -Eeuo pipefail\` kullanın ve \`bash -n\` ile sözdizimini doğrulayın.
- Mümkünse ShellCheck uyarı seviyesini \`warning\` olarak çalıştırın.
- PowerShell değişikliklerinde usbipd-win'in güncel komut biçimini koruyun.
- Yorumları Türkçe yazın.
- Log, cache, paket kurulum dosyası ve yerel vendor içeriklerini commit etmeyin.
- Sistem genelinde yükseltme veya paket kaldırma işlemlerini varsayılan davranış yapmayın.
- Kullanıcı verilerini veya mevcut ayarları onay olmadan silmeyin.

## Güvenlik açıkları

Güvenlik sorunlarını herkese açık Issue olarak paylaşmayın. [SECURITY.md](SECURITY.md) dosyasındaki özel bildirim yöntemini kullanın.

## Davranış kuralları

Katılımcılar [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) dosyasındaki kurallara uymalıdır.

Teşekkürler!
