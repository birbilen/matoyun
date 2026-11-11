// Mat Düellosu — Cloud Functions.
// Cevap kontrolü, puanlama, Taş ve XP işlemleri yalnızca burada yapılır.

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const G = require("./game");
const { ADJECTIVES, NOUNS } = require("./names");

admin.initializeApp();
const db = admin.firestore();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

const { C } = G;

// ---------- yardımcılar ----------

function fail(code, message) {
  return new HttpsError(code, message);
}

// Giriş zorunlu; her yanıta sunucu saatini ekler (uygulama saatini buna göre ayarlar).
function call(handler) {
  return onCall(async (req) => {
    if (!req.auth) throw fail("unauthenticated", "Giriş yapmalısın.");
    const res = await handler(req.auth.uid, req.data || {});
    return { ...(res || {}), now: Date.now() };
  });
}

function istanbulDay(now) {
  return new Date(now + 3 * 3600 * 1000).toISOString().slice(0, 10);
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function cleanCode(code) {
  const c = String(code || "").trim();
  if (!/^\d{6}$/.test(c)) throw fail("invalid-argument", "Oda kodu 6 haneli olmalı.");
  return c;
}

async function getProfile(uid) {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists) throw fail("failed-precondition", "Önce profil oluşturmalısın.");
  return snap.data();
}

// mode: "duello" | "antrenman", topic: konu kimliği ya da "karisik"
async function questionIds(mode, topic) {
  const snap = await db.doc("meta/questionIndex").get();
  const byTopic = (snap.exists && snap.data()[mode]) || {};
  if (topic === "karisik") return Object.values(byTopic).flat();
  return byTopic[topic] || [];
}

function checkTopic(topic) {
  if (topic !== "karisik" && !G.TOPICS.includes(topic)) {
    throw fail("invalid-argument", "Geçersiz konu.");
  }
  return topic;
}

function newPlayer(profile, now) {
  return {
    name: profile.name,
    avatar: profile.avatar,
    score: 0,
    totalMs: 0,
    correctCount: 0,
    answeredCount: 0,
    answered: false,
    left: false,
    reaction: null,
    joinedAt: now,
    lastSeen: now,
  };
}

function roomRefs(code) {
  const roomRef = db.doc(`rooms/${code}`);
  return { roomRef, privRef: roomRef.collection("private").doc("state") };
}

// Maç bittiğinde: ödülleri dağıt, istatistikleri güncelle, maçı kaydet.
async function finalize(tx, room, priv, now) {
  const rank = G.ranking(room);
  const refs = rank.map((r) => db.doc(`users/${r.uid}`));
  const snaps = refs.length ? await tx.getAll(...refs) : [];
  const users = {};
  snaps.forEach((s) => {
    if (s.exists) users[s.id] = s.data();
  });
  const day = istanbulDay(now);
  const rw = G.rewards(rank, users, day);

  const writes = [];
  for (const r of rank) {
    const u = users[r.uid];
    const w = rw[r.uid];
    r.tas = w ? w.tas : 0;
    r.xp = w ? w.xp : 0;
    if (!u || !w) continue;
    writes.push([
      db.doc(`users/${r.uid}`),
      {
        tas: (u.tas || 0) + w.tas,
        xp: (u.xp || 0) + w.xp,
        matches: (u.matches || 0) + 1,
        wins: (u.wins || 0) + (w.won ? 1 : 0),
        badges: [...(u.badges || []), ...w.badges],
        tasDaily: { day, amount: w.tasToday },
        stats: G.mergeStats(u.stats, (priv.tally || {})[r.uid]),
      },
    ]);
  }
  room.result = { ranking: rank };
  return () => {
    for (const [ref, data] of writes) tx.update(ref, data);
    tx.set(db.collection("matches").doc(), {
      code: room.code,
      topic: room.topic,
      playerUids: rank.map((r) => r.uid),
      players: rank,
      questions: priv.questions.map((q) => q.id),
      answers: priv.answers || {},
      finishedAt: now,
    });
  };
}

// Oda üzerinde tek bir işlem (transaction) çalıştırır ve odayı zamana göre ilerletir.
async function runRoom(code, uid, mutate, opts = {}) {
  const { roomRef, privRef } = roomRefs(code);
  const out = await db.runTransaction(async (tx) => {
    const [rs, ps] = await tx.getAll(roomRef, privRef);
    const now = Date.now();
    if (!rs.exists) return { gone: true };
    const room = rs.data();
    const priv = ps.exists ? ps.data() : { questions: [], answers: {} };
    if (G.isClosed(room, now)) {
      tx.delete(roomRef);
      tx.delete(privRef);
      return { gone: true };
    }
    const me = room.players[uid];
    if (!opts.allowNonMember && (!me || me.left)) return { notMember: true };
    if (me && !me.left) me.lastSeen = now;

    const extra = (await mutate(room, priv, now)) || {};
    const finishedNow = G.tick(room, priv, now);
    const commit = finishedNow ? await finalize(tx, room, priv, now) : null;

    room.memberUids = Object.keys(room.players).filter(
      (u) => !room.players[u].left
    );
    room.lastBeat = now;
    room.updatedAt = now;
    tx.set(roomRef, room);
    tx.set(privRef, priv);
    if (commit) commit();
    return extra;
  });
  if (out.gone) throw fail("not-found", "Oda bulunamadı ya da kapandı.");
  if (out.notMember) throw fail("permission-denied", "Bu odada değilsin.");
  return out;
}

// ---------- profil ----------

exports.createProfile = call(async (uid, data) => {
  const ref = db.doc(`users/${uid}`);
  const existing = await ref.get();
  if (existing.exists) return { name: existing.data().name };

  if (data.consent !== true) {
    throw fail("failed-precondition", "Veli onayı gerekli.");
  }
  if (!ADJECTIVES.includes(data.adjective) || !NOUNS.includes(data.noun)) {
    throw fail("invalid-argument", "Kullanıcı adı listeden seçilmeli.");
  }
  if (G.AVATARS[data.avatar] !== 1) {
    throw fail("invalid-argument", "Bu avatar henüz açık değil.");
  }
  const number = 10 + Math.floor(Math.random() * 90);
  const name = `${data.adjective}${data.noun}${number}`;
  const now = Date.now();
  await ref.set({
    name,
    avatar: data.avatar,
    xp: 0,
    lp: 0,
    tas: 0,
    owned: [],
    badges: [],
    stats: {},
    matches: 0,
    wins: 0,
    tasDaily: { day: istanbulDay(now), amount: 0 },
    consent: true,
    createdAt: now,
  });
  return { name };
});

exports.updateAvatar = call(async (uid, data) => {
  const u = await getProfile(uid);
  const need = G.AVATARS[data.avatar];
  if (!need || G.levelOf(u.xp) < need) {
    throw fail("failed-precondition", "Bu avatar henüz açık değil.");
  }
  await db.doc(`users/${uid}`).update({ avatar: data.avatar });
  return {};
});

exports.deleteAccount = call(async (uid) => {
  // Biten maç kayıtlarındaki izi sil.
  const ms = await db
    .collection("matches")
    .where("playerUids", "array-contains", uid)
    .get();
  const batch = db.batch();
  ms.forEach((doc) => {
    const d = doc.data();
    batch.update(doc.ref, {
      playerUids: d.playerUids.filter((u) => u !== uid),
      players: d.players.map((p) =>
        p.uid === uid ? { ...p, uid: null, name: "Silinmiş oyuncu" } : p
      ),
    });
  });
  batch.delete(db.doc(`users/${uid}`));
  batch.delete(db.doc(`trainingSessions/${uid}`));
  await batch.commit();
  await admin.auth().deleteUser(uid);
  return {};
});

// ---------- arkadaş odası ----------

exports.createRoom = call(async (uid, data) => {
  const profile = await getProfile(uid);
  const topic = checkTopic(data.topic);
  const count = Number(data.questionCount);
  if (!C.QUESTION_COUNTS.includes(count)) {
    throw fail("invalid-argument", "Soru sayısı 5, 10 ya da 15 olmalı.");
  }
  const available = (await questionIds("duello", topic)).length;
  if (available === 0) {
    throw fail("failed-precondition", "Bu konuda henüz soru yok.");
  }

  for (let attempt = 0; attempt < 10; attempt++) {
    const code = String(100000 + Math.floor(Math.random() * 900000));
    const { roomRef, privRef } = roomRefs(code);
    const ok = await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomRef);
      const now = Date.now();
      if (snap.exists && !G.isClosed(snap.data(), now)) return false;
      tx.set(roomRef, {
        code,
        hostUid: uid,
        status: "lobby",
        topic,
        questionCount: count,
        total: Math.min(count, available),
        index: -1,
        players: { [uid]: newPlayer(profile, now) },
        memberUids: [uid],
        question: null,
        reveal: null,
        result: null,
        emptySince: null,
        createdAt: now,
        updatedAt: now,
        lastBeat: now,
      });
      tx.set(privRef, { questions: [], answers: {}, tally: {} });
      return true;
    });
    if (ok) return { code };
  }
  throw fail("unavailable", "Oda kurulamadı, tekrar dene.");
});

exports.joinRoom = call(async (uid, data) => {
  const code = cleanCode(data.code);
  const profile = await getProfile(uid);
  return runRoom(
    code,
    uid,
    (room, priv, now) => {
      const me = room.players[uid];
      if (me && !me.left) return { code }; // zaten odada (yeniden bağlanma)
      if (room.status !== "lobby") {
        throw fail("failed-precondition", "Bu odada maç başlamış.");
      }
      // Oda doluysa bağlantısı kopmuş oyuncuların yerini aç.
      const uids = Object.keys(room.players);
      if (uids.length >= C.MAX_PLAYERS) {
        const ghost = uids.find((u) => !G.isConnected(room.players[u], now));
        if (!ghost) throw fail("resource-exhausted", "Oda dolu (en fazla 4 oyuncu).");
        delete room.players[ghost];
      }
      room.players[uid] = newPlayer(profile, now);
      return { code };
    },
    { allowNonMember: true }
  );
});

exports.leaveRoom = call(async (uid, data) => {
  const code = cleanCode(data.code);
  try {
    await runRoom(code, uid, (room) => {
      // Bekleme salonunda tamamen çıkar; maçta ise sıralamada kalır.
      if (room.status === "lobby") delete room.players[uid];
      else room.players[uid].left = true;
    });
  } catch (e) {
    if (e.code !== "not-found" && e.code !== "permission-denied") throw e;
  }
  return {};
});

exports.startMatch = call(async (uid, data) => {
  const code = cleanCode(data.code);
  const first = await roomRefs(code).roomRef.get();
  if (!first.exists) throw fail("not-found", "Oda bulunamadı ya da kapandı.");
  const { topic, questionCount } = first.data();
  const ids = shuffle(await questionIds("duello", topic)).slice(0, questionCount);
  if (ids.length === 0) throw fail("failed-precondition", "Bu konuda henüz soru yok.");
  const snaps = await db.getAll(...ids.map((id) => db.doc(`questions/${id}`)));
  const questions = snaps
    .filter((s) => s.exists)
    .map((s) => ({ id: s.id, ...s.data() }));

  return runRoom(code, uid, (room, priv, now) => {
    if (room.hostUid !== uid) {
      throw fail("permission-denied", "Maçı yalnızca oda yöneticisi başlatabilir.");
    }
    if (room.status !== "lobby") {
      throw fail("failed-precondition", "Maç zaten başladı.");
    }
    // Bağlantısı kopmuş oyuncular maça alınmaz.
    for (const u of Object.keys(room.players)) {
      if (!G.isConnected(room.players[u], now)) delete room.players[u];
    }
    if (Object.keys(room.players).length < C.MIN_PLAYERS) {
      throw fail("failed-precondition", "Başlamak için en az 2 oyuncu gerekli.");
    }
    priv.questions = questions;
    priv.answers = {};
    priv.tally = {};
    room.total = questions.length;
    room.index = -1;
    room.status = "countdown";
    room.countdownEndsAt = now + C.COUNTDOWN_MS;
  });
});

exports.submitAnswer = call(async (uid, data) => {
  const code = cleanCode(data.code);
  const choice = Number(data.choice);
  if (![0, 1, 2, 3].includes(choice)) throw fail("invalid-argument", "Geçersiz şık.");
  return runRoom(code, uid, (room, priv, now) => {
    if (room.status !== "playing" || room.index !== Number(data.index)) {
      throw fail("failed-precondition", "Bu soru kapandı.");
    }
    if (now > room.question.endsAt + C.SUBMIT_GRACE_MS) {
      throw fail("deadline-exceeded", "Süre doldu.");
    }
    const key = String(room.index);
    priv.answers[key] = priv.answers[key] || {};
    if (priv.answers[key][uid]) {
      throw fail("already-exists", "Cevap değiştirilemez.");
    }
    // Süre sunucu saatine göre ölçülür.
    const ms = Math.min(C.QUESTION_MS, Math.max(0, now - room.question.startsAt));
    priv.answers[key][uid] = { choice, ms };
    room.players[uid].answered = true;
  });
});

// Uygulama bunu düzenli aralıkla ve her aşamanın süresi dolduğunda çağırır.
// Hem "buradayım" sinyalidir hem de odayı sunucu saatine göre ilerletir.
exports.syncRoom = call(async (uid, data) => {
  return runRoom(cleanCode(data.code), uid, () => {});
});

exports.playAgain = call(async (uid, data) => {
  return runRoom(cleanCode(data.code), uid, (room, priv, now) => {
    if (room.hostUid !== uid) {
      throw fail("permission-denied", "Yalnızca oda yöneticisi yeniden başlatabilir.");
    }
    if (room.status !== "finished") {
      throw fail("failed-precondition", "Maç henüz bitmedi.");
    }
    for (const [u, p] of Object.entries(room.players)) {
      if (p.left) {
        delete room.players[u];
        continue;
      }
      Object.assign(p, {
        score: 0,
        totalMs: 0,
        correctCount: 0,
        answeredCount: 0,
        answered: false,
        reaction: null,
      });
    }
    priv.questions = [];
    priv.answers = {};
    priv.tally = {};
    room.status = "lobby";
    room.index = -1;
    room.question = null;
    room.reveal = null;
    room.result = null;
  });
});

exports.sendReaction = call(async (uid, data) => {
  if (!C.REACTIONS.includes(data.emoji)) {
    throw fail("invalid-argument", "Geçersiz tepki.");
  }
  return runRoom(cleanCode(data.code), uid, (room, priv, now) => {
    room.players[uid].reaction = { emoji: data.emoji, at: now };
  });
});

// ---------- antrenman ----------

exports.trainingNext = call(async (uid, data) => {
  await getProfile(uid);
  const topic = checkTopic(data.topic);
  const ids = await questionIds("antrenman", topic);
  if (ids.length === 0) throw fail("failed-precondition", "Bu konuda henüz soru yok.");
  const sessRef = db.doc(`trainingSessions/${uid}`);
  const sess = (await sessRef.get()).data() || {};
  const recent = sess.recent || [];
  const fresh = ids.filter((id) => !recent.includes(id));
  const pool = fresh.length ? fresh : ids;
  const qid = pool[Math.floor(Math.random() * pool.length)];
  const q = (await db.doc(`questions/${qid}`).get()).data();
  if (!q) throw fail("not-found", "Soru bulunamadı.");
  await sessRef.set({
    qid,
    answered: false,
    hint: null,
    recent: [...recent, qid].slice(-10),
  });
  return {
    question: {
      text: q.text,
      options: q.options,
      image: q.image || null,
      topic: q.topic,
      difficulty: q.difficulty,
    },
  };
});

// İpucu: iki yanlış şıkkı eler (yalnızca antrenmanda).
exports.trainingHint = call(async (uid) => {
  const sessRef = db.doc(`trainingSessions/${uid}`);
  const sess = (await sessRef.get()).data();
  if (!sess || sess.answered) throw fail("failed-precondition", "Aktif soru yok.");
  if (sess.hint) return { remove: sess.hint };
  const q = (await db.doc(`questions/${sess.qid}`).get()).data();
  const wrong = shuffle([0, 1, 2, 3].filter((i) => i !== q.correct)).slice(0, 2);
  await sessRef.update({ hint: wrong });
  return { remove: wrong };
});

exports.trainingAnswer = call(async (uid, data) => {
  const choice = Number(data.choice);
  if (![0, 1, 2, 3].includes(choice)) throw fail("invalid-argument", "Geçersiz şık.");
  const sessRef = db.doc(`trainingSessions/${uid}`);
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    const [ss, us] = await tx.getAll(sessRef, userRef);
    const sess = ss.data();
    if (!sess || sess.answered || !us.exists) {
      throw fail("failed-precondition", "Aktif soru yok.");
    }
    const q = (await tx.get(db.doc(`questions/${sess.qid}`))).data();
    const correct = choice === q.correct;
    const xp = correct ? (sess.hint ? 1 : 2) : 0;
    const u = us.data();
    tx.update(sessRef, { answered: true });
    tx.update(userRef, {
      xp: (u.xp || 0) + xp,
      stats: G.mergeStats(u.stats, {
        [q.topic]: { correct: correct ? 1 : 0, total: 1 },
      }),
    });
    return { correct, correctIndex: q.correct, solution: q.solution || "", xp };
  });
});

// ---------- temizlik ----------

// Dakikada bir: 1 dakikadır boş olan ve çok eski odaları siler.
exports.cleanupRooms = onSchedule("every 1 minutes", async () => {
  const now = Date.now();
  const stale = await db
    .collection("rooms")
    .where("lastBeat", "<", now - C.STALE_MS)
    .get();
  for (const doc of stale.docs) {
    const room = doc.data();
    const tooOld = now - room.createdAt > 3 * 3600 * 1000;
    if (tooOld || G.isClosed(room, now)) await db.recursiveDelete(doc.ref);
  }
});
