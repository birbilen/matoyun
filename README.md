# Mat Düellosu

LGS'ye hazırlanan 7–8. sınıf öğrencileri için gerçek zamanlı matematik düellosu.
Flutter (web + Android) ve Firebase ile yazılmıştır.

Bu depo **1. aşamayı** içerir: Giriş, Ana menü, Arkadaş Odası (2–4 oyuncu),
Maç, Soru sonucu, Maç sonucu, Antrenman, Profil ve Ayarlar.

## Klasörler

| Klasör / dosya | İçerik |
|---|---|
| `lib/` | Uygulama (ekranlar). Yalnızca sonucu gösterir, puan hesaplamaz. |
| `functions/` | Sunucu kodu (Cloud Functions): cevap kontrolü, puan, Taş, XP. |
| `functions/game.js` | Oyun kuralları. Süreler ve puanlar en üstteki `C` içinde. |
| `firestore.rules` | Veritabanı güvenlik kuralları. |
| `data/sorular_ornek.csv` | 20 örnek soru. |
| `functions/scripts/upload_questions.js` | Soru yükleme betiği. |

## Görünüm ve marka

- Renkler tek yerden değişir: `lib/theme.dart` içindeki `Brand` sınıfı.
- Logo: `assets/logo.png` adıyla bir dosya koyarsan giriş ve ana menüde
  otomatik kullanılır (kare, şeffaf arka plan, en az 512x512). Yoksa at
  simgesi görünür.

## Proje dokümanına göre yapılan düzeltmeler

- **Giriş:** Google ile giriş ana yöntemdir (ilerleme hesaba kaydedilir).
  Ayrıca "Misafir olarak dene" vardır; misafir sonradan ana menüden Google
  hesabına bağlanabilir ve ilerlemesi korunur.
- **Kullanıcı adı:** Hazır kelimelerden seçilir (ör. `HızlıVezir42`). Küfür
  filtresine gerek kalmaz, gerçek ad girilemez.
- **Puan:** Toplam puan sıfırın altına inmez.
- **Eşitlik:** Boş bırakılan soru toplam süreye 20 saniye olarak eklenir.
- **Soru sayısı:** Oda kurarken 5, 10 ya da 15 seçilir (varsayılan 5).
- **Oda yönetimi:** Kurucu çıkarsa ya da 1 dakika bağlantısı olmazsa yönetim
  odaya en önce girmiş bağlı oyuncuya geçer.
- **Boş oda:** Odada kimse kalmazsa oda 1 dakika sonra kapanır.
- **Güvenlik kuralları:** Oyuncu yalnızca kendi profilini ve içinde olduğu
  odayı okur. Rakibin adı, avatarı ve skoru oda belgesine kopyalanır.
- **Süre:** Sunucuda zamanlayıcı yoktur; süre dolunca oyuncuların uygulaması
  sunucuya haber verir, sunucu kendi saatine bakarak odayı ilerletir.
- **Taş:** Kazanan 20, diğerleri 5 Taş alır; arkadaş odasından günde en fazla
  100 Taş kazanılır (iki hesapla Taş kasmayı önler).
- **Market:** Ana menüde "Yakında" olarak görünür (3. aşama).
- **Gizlilik politikası:** Uygulama içinde bir **taslak** vardır
  (`lib/screens/privacy_screen.dart`). Yayından önce gözden geçirilmeli ve
  iletişim adresi eklenmelidir.

## 1. Kurulum (bir kere yapılır)

1. **Flutter:** <https://docs.flutter.dev/get-started/install> adresinden
   işletim sistemine uygun kurulumu yap. Bitince terminalde `flutter doctor`
   yaz; "Flutter" ve "Chrome" satırlarında yeşil tik olması yeterli.
2. **Node.js 22:** <https://nodejs.org> adresinden LTS sürümünü kur.
3. **Java 21 ya da üstü:** Emülatör için gerekir. <https://adoptium.net>
4. **Firebase CLI:** Terminalde `npm install -g firebase-tools`
5. Bu depoyu indir ve klasörüne gir, sonra:

   ```
   flutter pub get
   cd functions
   npm install
   cd ..
   ```

## 2. Bilgisayarında çalıştırma (Firebase hesabı gerekmez)

Yerel emülatör, Firebase'in bilgisayarında çalışan bir kopyasıdır. Ücretsizdir
ve kart bilgisi istemez.

**Terminal 1 — emülatörü başlat:**

```
firebase emulators:start --project demo-matduellosu
```

"All emulators ready!" yazısını bekle ve bu pencereyi açık bırak.

**Terminal 2 — örnek soruları yükle** (emülatör her başladığında bir kere):

```
cd functions
npm run sorular:yukle -- ../data/sorular_ornek.csv --emulator
cd ..
```

**Terminal 2 — uygulamayı aç:**

```
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

## 3. Nasıl test edilir?

1. Açılan Chrome'da "Misafir olarak dene"ye bas, profilini oluştur.
2. Adres çubuğundaki adresi kopyala, **yeni bir gizli pencerede** aç
   (ikinci oyuncu). Orada da misafir olarak gir.
3. Birinci pencerede **Oyna → Oda kur**. Çıkan 6 haneli kodu ikinci
   pencerede **Oyna → Odaya katıl** kısmına yaz.
4. Birinci pencerede **Maçı başlat**. İki pencerede de soruları cevapla.

Kontrol listesi:

- [ ] Doğru cevap 100 + hız bonusu veriyor, yanlış −30, puan 0'ın altına inmiyor
- [ ] İki oyuncu da cevaplayınca süre beklenmeden sonuç geliyor
- [ ] Maç sonunda sıralama, Taş ve XP görünüyor; emoji tepkisi karşıya ulaşıyor
- [ ] Kurucu "Ana menü"ye basınca diğer oyuncuda "Tekrar oyna" düğmesi çıkıyor
- [ ] Herkes çıktıktan 1 dakika sonra aynı kodla odaya girilemiyor
- [ ] Antrenmanda ipucu iki şıkkı eliyor, cevaptan sonra çözüm görünüyor
- [ ] Profilde konu bazında doğruluk görünüyor
- [ ] Ayarlar → Hesabımı sil çalışıyor

Google ile girişi emülatörde denersen sahte bir hesap seçme penceresi açılır;
bu normaldir.

Sunucu kurallarının otomatik testi: `cd functions` ve `npm test`

## 3b. Telefonda test (aynı Wi-Fi)

1. Bilgisayarın yerel IP adresini bul: cmd'de `ipconfig` yaz,
   "IPv4 Adresi" satırındaki değeri not et (ör. `192.168.1.35`).
2. Emülatörü her zamanki gibi başlat. Windows güvenlik duvarı sorarsa
   **Özel ağlar** için izin ver.
3. Uygulamayı Chrome yerine ağa açık sunucu olarak başlat:

   ```
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8000 --dart-define=USE_EMULATOR=true
   ```

4. Telefonun tarayıcısında `http://192.168.1.35:8000` adresini aç
   (kendi IP adresinle). Bilgisayarda da aynı adresi açıp telefona karşı
   oynayabilirsin.

Açılmıyorsa: telefon ve bilgisayar aynı Wi-Fi'de mi, güvenlik duvarı izni
verildi mi kontrol et. Okul/misafir ağları cihazların birbirini görmesini
engelleyebilir; o durumda evdeki ağı ya da telefonun hotspot'unu kullan.

## 4. Gerçek Firebase projesine geçiş (öğrencilerle test için)

1. <https://console.firebase.google.com> → **Proje ekle**.
2. **Build → Authentication → Başlayın → Sign-in method:** "Google" ve
   "Anonim" sağlayıcılarını etkinleştir.
3. **Build → Firestore Database → Veritabanı oluştur** (konum:
   `europe-west1`, üretim modu).
4. Sol alttan planı **Blaze (kullandıkça öde)** yap. Cloud Functions için
   zorunludur ve kart bilgisi ister. Sürpriz olmaması için **Faturalandırma →
   Bütçeler** kısmından küçük bir bütçe uyarısı kur.
5. Terminalde:

   ```
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Projeni seç, platform olarak **web** ve **android** işaretle. Bu komut
   `lib/firebase_options.dart` dosyasını senin projenin ayarlarıyla değiştirir.
6. Sunucu kodunu, kuralları ve web sürümünü yayınla:

   ```
   firebase use --add
   flutter build web
   firebase deploy
   ```

   Sonunda çıkan `https://PROJE.web.app` adresini öğrencilerle paylaş.
7. Soruları yükle (aşağıya bak).

## 5. Soruları yükleme

Soruları Google E-Tablo'da `data/sorular_ornek.csv` ile **aynı sütun
başlıklarıyla** hazırla:

`id, konu, zorluk, metin, sik_a, sik_b, sik_c, sik_d, dogru, cozum, gorsel, mod`

- `dogru`: 0 = A, 1 = B, 2 = C, 3 = D
- `mod`: `duello`, `antrenman` ya da `ikisi`
- `konu`: `carpanlar_katlar`, `uslu_ifadeler`, `karekoklu_ifadeler`,
  `veri_analizi`, `olasilik`, `cebirsel_ifadeler`, `dogrusal_denklemler`,
  `esitsizlikler`, `ucgenler`, `eslik_benzerlik`, `donusum_geometrisi`,
  `geometrik_cisimler`
- Matematik ifadeleri iki dolar işareti arasına LaTeX ile yazılır:
  `$\sqrt{50}$`, `$\frac{1}{8}$`, `$2^{-3}$`

E-Tablo'da **Dosya → Paylaş → Web'de yayınla → Virgülle ayrılmış değerler
(.csv)** seç ve verilen bağlantıyı kopyala.

Gerçek projeye yüklemek için bir kere: Firebase konsolu → **Proje ayarları →
Hizmet hesapları → Yeni özel anahtar oluştur**. İnen dosyayı depo dışında bir
yere koy ve kimseyle paylaşma. Sonra:

```
cd functions
export GOOGLE_APPLICATION_CREDENTIALS="/dosya/yolu/anahtar.json"
npm run sorular:yukle -- "CSV_BAGLANTISI" --project PROJE_KIMLIGI
```

(Windows PowerShell'de `export` yerine
`$env:GOOGLE_APPLICATION_CREDENTIALS="C:\yol\anahtar.json"`.)

Betik hatalı satırları (eksik şık, bilinmeyen konu vb.) satır numarasıyla
bildirir ve hiçbir şey yüklemez. Aynı komutu tekrar çalıştırmak soruları
günceller.

## 6. Android

Kod Android'e de derlenecek şekilde yazıldı, ancak Android derlemesi henüz
denenmedi. Web testi bittikten sonra Android Studio kurup
`flutter run` ile denenmeli. Google ile giriş için Firebase konsolunda Android
uygulamasına SHA-1 parmak izi eklemek gerekir.

## Henüz yapılmayanlar

- Ses efektleri (yalnızca Android'de tıklama sesi var) ve bildirimler
- Hızlı Maç, lig, günlük görevler (2. aşama); market (3. aşama)
- 300 soruluk havuz (şu an 20 örnek soru var)
