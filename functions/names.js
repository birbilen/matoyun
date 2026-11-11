// Kullanıcı adı hazır kelimelerden seçilir: sıfat + taş + sayı (ör. HızlıVezir42).
// Böylece küfür filtresine gerek kalmaz ve gerçek ad girilemez.
// Bu listeler lib/data/names.dart ile aynı olmalıdır.
const ADJECTIVES = [
  "Hızlı",
  "Zeki",
  "Cesur",
  "Sakin",
  "Usta",
  "Parlak",
  "Kararlı",
  "Dikkatli",
  "Neşeli",
  "Güçlü",
  "Sabırlı",
  "Çevik",
];
const NOUNS = ["Piyon", "At", "Fil", "Kale", "Vezir", "Şah"];

module.exports = { ADJECTIVES, NOUNS };
