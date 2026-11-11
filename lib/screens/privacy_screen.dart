import 'package:flutter/material.dart' hide Page;

import '../widgets/common.dart';

/// TASLAK gizlilik politikası. Yayından önce gözden geçirilmeli ve
/// iletişim adresi eklenmelidir.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Taslak',
      'Bu metin bir taslaktır. Uygulama yayınlanmadan önce bir uzmana '
          'gösterilmeli ve veri sorumlusunun iletişim bilgileri eklenmelidir.'
    ),
    (
      'Hangi verileri saklıyoruz?',
      'Hazır kelimelerden seçtiğin kullanıcı adı, avatarın, oyun ilerlemen '
          '(puan, seviye, Taş, rozetler) ve konu bazında doğru/yanlış '
          'sayıların. Gerçek adını, okulunu, adresini ya da telefon numaranı '
          'istemiyoruz.'
    ),
    (
      'Google ile giriş',
      'Google ile giriş yaparsan hesabını tanımak için Google\'ın verdiği '
          'hesap kimliği ve e-posta adresi giriş sisteminde (Firebase '
          'Authentication) tutulur. Bu bilgi diğer oyunculara gösterilmez ve '
          'başka bir amaçla kullanılmaz. Misafir olarak oynarsan bu bilgiler '
          'alınmaz.'
    ),
    (
      'Diğer oyuncular ne görür?',
      'Yalnızca aynı odadaki oyuncular kullanıcı adını, avatarını ve o '
          'maçtaki puanını görür. Serbest yazışma yoktur; yalnızca hazır '
          'emoji tepkileri gönderilebilir.'
    ),
    (
      'Veriler nerede tutulur?',
      'Veriler Google Firebase altyapısında saklanır. Verilerin reklam '
          'amacıyla kimseyle paylaşılmaz ve satılmaz.'
    ),
    (
      'Veli onayı',
      'Oyun 12–14 yaş arası öğrenciler içindir. Oyuna başlarken velinin '
          'izni olduğunu onaylaman istenir. Veliler çocuklarının hesabının '
          'silinmesini her zaman isteyebilir.'
    ),
    (
      'Hesabını silme',
      'Ayarlar > Hesabımı sil ile hesabını ve tüm ilerlemeni kalıcı olarak '
          'silebilirsin. Silme işlemi geri alınamaz.'
    ),
    (
      'Haklarınız (KVKK)',
      '6698 sayılı Kanun kapsamında verilerinize erişme, düzeltilmesini ya '
          'da silinmesini isteme hakkınız vardır. İletişim: [e-posta adresi '
          'eklenecek].'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Page(
      title: 'Gizlilik politikası',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, body) in _sections) ...[
            Text(title, style: t.titleMedium),
            const SizedBox(height: 4),
            Text(body, style: t.bodyMedium),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
