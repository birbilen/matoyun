// Mat Düellosu — oyun kuralları (saf mantık, Firebase'e bağımlı değil).
// Bu dosyadaki her şey sunucuda çalışır; uygulama yalnızca sonucu gösterir.

const C = {
  QUESTION_MS: 20000, // soru başına süre
  COUNTDOWN_MS: 3000, // maç başı geri sayım
  REVEAL_MS: 6000, // soru sonucu ekranı süresi
  STALE_MS: 35000, // bu kadar süre sinyal gelmeyen oyuncu "bağlantısı kopmuş" sayılır
  EMPTY_CLOSE_MS: 60000, // odada kimse kalmazsa oda bu süre sonunda kapanır
  HOST_STALE_MS: 60000, // kurucu bu kadar süre yoksa yönetim devredilir
  SUBMIT_GRACE_MS: 500, // ağ gecikmesi için küçük tolerans
  MAX_PLAYERS: 4,
  MIN_PLAYERS: 2,
  QUESTION_COUNTS: [5, 10, 15],
  WIN_TAS: 20,
  PLAY_TAS: 5,
  DAILY_TAS_CAP: 100, // arkadaş odasından günde en fazla kazanılabilecek Taş
  XP_PER_LEVEL: 200,
  REACTIONS: ["👏", "😎", "🔥", "😅", "🤝", "♟️"],
};

const TOPICS = [
  "carpanlar_katlar",
  "uslu_ifadeler",
  "karekoklu_ifadeler",
  "veri_analizi",
  "olasilik",
  "cebirsel_ifadeler",
  "dogrusal_denklemler",
  "esitsizlikler",
  "ucgenler",
  "eslik_benzerlik",
  "donusum_geometrisi",
  "geometrik_cisimler",
];

// Avatarlar ve açıldıkları hesap seviyesi.
const AVATARS = { piyon: 1, at: 1, fil: 2, kale: 3, vezir: 5, sah: 8 };

function levelOf(xp) {
  return 1 + Math.floor((xp || 0) / C.XP_PER_LEVEL);
}

// Doğru: 100 + hız bonusu (kalan saniye × 5, en fazla 100). Yanlış: −30.
function scoreDelta(correct, remainingMs) {
  if (!correct) return -30;
  const secs = Math.max(0, Math.floor(remainingMs / 1000));
  return 100 + Math.min(100, secs * 5);
}

function isConnected(p, now) {
  return !!p && !p.left && now - p.lastSeen < C.STALE_MS;
}

function connectedUids(room, now) {
  return Object.keys(room.players)
    .filter((u) => isConnected(room.players[u], now))
    .sort((a, b) => room.players[a].joinedAt - room.players[b].joinedAt);
}

// Odanın boşaldığı an (boş değilse null).
function emptySince(room, now) {
  if (connectedUids(room, now).length > 0) return null;
  if (room.emptySince) return room.emptySince;
  const seen = Object.values(room.players)
    .filter((p) => !p.left)
    .map((p) => p.lastSeen + C.STALE_MS);
  return seen.length ? Math.max(...seen) : now;
}

function isClosed(room, now) {
  const e = emptySince(room, now);
  return e !== null && now - e >= C.EMPTY_CLOSE_MS;
}

function publishQuestion(room, priv, i, now) {
  const q = priv.questions[i];
  room.index = i;
  room.status = "playing";
  room.question = {
    text: q.text,
    options: q.options,
    image: q.image || null,
    topic: q.topic,
    startsAt: now,
    endsAt: now + C.QUESTION_MS,
  };
  room.reveal = null;
  for (const p of Object.values(room.players)) p.answered = false;
}

function makeReveal(room, priv, now) {
  const q = priv.questions[room.index];
  const answers = (priv.answers || {})[String(room.index)] || {};
  const results = {};
  priv.tally = priv.tally || {};
  for (const [uid, p] of Object.entries(room.players)) {
    const a = answers[uid];
    const before = p.score;
    let correct = false;
    if (a) {
      correct = a.choice === q.correct;
      const remaining = C.QUESTION_MS - a.ms;
      // Toplam puan sıfırın altına inmez.
      p.score = Math.max(0, p.score + scoreDelta(correct, remaining));
      p.totalMs += a.ms;
      p.answeredCount += 1;
      if (correct) p.correctCount += 1;
      const t = (priv.tally[uid] = priv.tally[uid] || {});
      const s = (t[q.topic] = t[q.topic] || { correct: 0, total: 0 });
      s.total += 1;
      if (correct) s.correct += 1;
    } else {
      // Boş bırakma: 0 puan, eşitlik bozmada tam süre sayılır.
      p.totalMs += C.QUESTION_MS;
    }
    results[uid] = {
      choice: a ? a.choice : null,
      correct,
      delta: p.score - before,
    };
  }
  room.status = "reveal";
  room.reveal = {
    correctIndex: q.correct,
    solution: q.solution || "",
    results,
    endsAt: now + C.REVEAL_MS,
  };
}

// Sıralama: puan yüksek olan, eşitlikte toplam cevap süresi kısa olan önde.
function ranking(room) {
  return Object.entries(room.players)
    .map(([uid, p]) => ({
      uid,
      name: p.name,
      avatar: p.avatar,
      score: p.score,
      totalMs: p.totalMs,
      correct: p.correctCount,
      answered: p.answeredCount,
      left: !!p.left,
    }))
    .sort((a, b) => b.score - a.score || a.totalMs - b.totalMs);
}

// Her çağrıda odanın durumunu sunucu saatine göre ilerletir.
// Dönüş: maç bu çağrıda bittiyse true.
function tick(room, priv, now) {
  // Kurucu çıktıysa ya da 1 dakikadır yoksa yönetim en eski bağlı oyuncuya geçer.
  const host = room.players[room.hostUid];
  const hostGone = !host || host.left || now - host.lastSeen >= C.HOST_STALE_MS;
  const connected = connectedUids(room, now);
  if (hostGone && connected.length > 0) room.hostUid = connected[0];

  room.emptySince = emptySince(room, now);

  if (room.status === "countdown") {
    if (now >= room.countdownEndsAt) publishQuestion(room, priv, 0, now);
  } else if (room.status === "playing") {
    const allAnswered =
      connected.length > 0 && connected.every((u) => room.players[u].answered);
    if (now >= room.question.endsAt || allAnswered) makeReveal(room, priv, now);
  } else if (room.status === "reveal") {
    if (now >= room.reveal.endsAt) {
      if (room.index + 1 < room.total) {
        publishQuestion(room, priv, room.index + 1, now);
      } else {
        room.status = "finished";
        return true;
      }
    }
  }
  return false;
}

// Maç sonu ödülleri. users: uid -> kullanıcı belgesi, day: "2026-11-11".
function rewards(rank, users, day) {
  const participants = rank.filter((r) => r.answered > 0);
  const winnerUid = participants.length >= 2 ? participants[0].uid : null;
  const out = {};
  for (const r of participants) {
    const u = users[r.uid];
    if (!u) continue;
    const won = r.uid === winnerUid;
    const usedToday =
      u.tasDaily && u.tasDaily.day === day ? u.tasDaily.amount : 0;
    const room = Math.max(0, C.DAILY_TAS_CAP - usedToday);
    const tas = Math.min(won ? C.WIN_TAS : C.PLAY_TAS, room);
    const xp = 20 + 10 * r.correct + (won ? 30 : 0);
    const badges = [];
    if (!(u.badges || []).includes("ilk_mac")) badges.push("ilk_mac");
    if (won && !(u.badges || []).includes("ilk_galibiyet")) {
      badges.push("ilk_galibiyet");
    }
    out[r.uid] = { tas, xp, won, badges, tasToday: usedToday + tas };
  }
  return out;
}

function mergeStats(stats, tally) {
  const out = { ...(stats || {}) };
  for (const [topic, t] of Object.entries(tally || {})) {
    const cur = out[topic] || { correct: 0, total: 0 };
    out[topic] = {
      correct: cur.correct + t.correct,
      total: cur.total + t.total,
    };
  }
  return out;
}

module.exports = {
  C,
  TOPICS,
  AVATARS,
  levelOf,
  scoreDelta,
  isConnected,
  connectedUids,
  emptySince,
  isClosed,
  publishQuestion,
  makeReveal,
  ranking,
  tick,
  rewards,
  mergeStats,
};
