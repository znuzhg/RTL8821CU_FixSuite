# Güvenlik Politikası

## Desteklenen sürüm

| Sürüm | Destek |
|---|---|
| \`main\` dalındaki güncel sürüm | Bakım kapsamındadır |
| Önceki commit'ler ve etiketlenmemiş eski sürümler | Ayrı bir destek taahhüdü yoktur |

Bu depoda henüz resmî sürüm etiketi bulunmayan sürümler için uzun süreli destek garantisi verilmez.

## Güvenlik açığı bildirimi

Güvenlik açıklarını herkese açık Issue veya Pull Request olarak yayımlamayın.

Bildirimi özel olarak şu e-posta adresine gönderin:

**znuz@yaani.com**

GitHub deposunda özel güvenlik bildirimi özelliği etkinse GitHub'ın “Report a vulnerability” akışını da kullanabilirsiniz.

Bildirime mümkün olduğunda şunları ekleyin:

- Etkilenen dosya, fonksiyon ve commit.
- Sorunun teknik açıklaması.
- Yeniden üretme adımları.
- Etki ve gerekli koşullar.
- Varsa güvenli çözüm önerisi.

## İnceleme süreci

Bildirim alındığında sorun doğrulanır, etkisi değerlendirilir ve uygun bir düzeltme hazırlanır. İnceleme süresi sorunun karmaşıklığına ve bakım kapasitesine bağlıdır; önceden garanti edilmiş bir yanıt veya çözüm süresi yoktur.

## Güvenli kullanım

- Logları paylaşmadan önce IP, MAC, hostname ve kullanıcı adı gibi bilgileri temizleyin.
- Scriptleri çalıştırmadan önce değişiklikleri ve hedef yolları inceleyin.
- Bilinmeyen sürücü kaynaklarını güvenilirliğini doğrulamadan kurmayın.
- Üretim veya kritik sistemlerde önce yedek alın ve DRY-RUN çıktısını inceleyin.
