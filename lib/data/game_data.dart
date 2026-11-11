import 'package:flutter/material.dart';

/// Konu kimlikleri ve görünen adları (functions/game.js ile aynı kimlikler).
const topicNames = <String, String>{
  'karisik': 'Karışık (tüm konular)',
  'carpanlar_katlar': 'Çarpanlar ve Katlar',
  'uslu_ifadeler': 'Üslü İfadeler',
  'karekoklu_ifadeler': 'Kareköklü İfadeler',
  'veri_analizi': 'Veri Analizi',
  'olasilik': 'Basit Olayların Olma Olasılığı',
  'cebirsel_ifadeler': 'Cebirsel İfadeler ve Özdeşlikler',
  'dogrusal_denklemler': 'Doğrusal Denklemler',
  'esitsizlikler': 'Eşitsizlikler',
  'ucgenler': 'Üçgenler',
  'eslik_benzerlik': 'Eşlik ve Benzerlik',
  'donusum_geometrisi': 'Dönüşüm Geometrisi',
  'geometrik_cisimler': 'Geometrik Cisimler',
};

class AvatarInfo {
  final String name;
  final String glyph;
  final Color color;
  final int level; // açıldığı hesap seviyesi
  const AvatarInfo(this.name, this.glyph, this.color, this.level);
}

const avatars = <String, AvatarInfo>{
  'piyon': AvatarInfo('Piyon', '♟', Color(0xFF4F7CAC), 1),
  'at': AvatarInfo('At', '♞', Color(0xFF3E8E6E), 1),
  'fil': AvatarInfo('Fil', '♝', Color(0xFF8E5BB5), 2),
  'kale': AvatarInfo('Kale', '♜', Color(0xFFB5653A), 3),
  'vezir': AvatarInfo('Vezir', '♛', Color(0xFFC0392B), 5),
  'sah': AvatarInfo('Şah', '♚', Color(0xFFB8922E), 8),
};

const xpPerLevel = 200;
int levelOf(int xp) => 1 + xp ~/ xpPerLevel;

/// Lig adları ve alt sınırları (lig puanı).
const leagues = <(String, int)>[
  ('Piyon', 0), ('At', 300), ('Fil', 700),
  ('Kale', 1200), ('Vezir', 1800), ('Şah', 2500),
];
String leagueOf(int lp) => leagues.lastWhere((l) => lp >= l.$2).$1;

const badgeNames = <String, String>{
  'ilk_mac': 'İlk Maç',
  'ilk_galibiyet': 'İlk Galibiyet',
};

const reactions = ['👏', '😎', '🔥', '😅', '🤝', '♟️'];
const questionCounts = [5, 10, 15];
const questionMs = 20000;
const staleMs = 35000;

int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;
