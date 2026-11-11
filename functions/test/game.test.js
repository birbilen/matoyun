const test = require("node:test");
const assert = require("node:assert");
const G = require("../game");
const { C } = G;

function player(name, t) {
  return {
    name, avatar: "piyon", score: 0, totalMs: 0, correctCount: 0,
    answeredCount: 0, answered: false, left: false, reaction: null,
    joinedAt: t, lastSeen: t,
  };
}
function setup(n = 2, total = 2) {
  const players = {};
  ["a", "b", "c", "d"].slice(0, n).forEach((u, i) => (players[u] = player(u, 1000 + i)));
  const room = {
    code: "123456", hostUid: "a", status: "countdown", topic: "karisik",
    total, index: -1, players, countdownEndsAt: 4000, emptySince: null,
    question: null, reveal: null, updatedAt: 1000,
  };
  const questions = Array.from({ length: total }, (_, i) => ({
    id: "q" + i, topic: "uslu_ifadeler", text: "?", options: ["1", "2", "3", "4"],
    correct: 1, solution: "s",
  }));
  return { room, priv: { questions, answers: {}, tally: {} } };
}
const beat = (room, now) => Object.values(room.players).forEach((p) => (p.lastSeen = now));

test("puanlama: doğru 100 + hız bonusu, yanlış -30", () => {
  assert.equal(G.scoreDelta(true, 20000), 200);
  assert.equal(G.scoreDelta(true, 7900), 135);
  assert.equal(G.scoreDelta(true, 0), 100);
  assert.equal(G.scoreDelta(false, 15000), -30);
});

test("maç akışı, sıfır tabanı ve eşitlik bozma", () => {
  const { room, priv } = setup(2, 2);
  G.tick(room, priv, 3000);
  assert.equal(room.status, "countdown");
  G.tick(room, priv, 4000);
  assert.equal(room.status, "playing");
  assert.equal(room.question.correct, undefined); // doğru şık telefona gitmez

  // a 5. saniyede doğru, b yanlış cevaplar
  priv.answers["0"] = { a: { choice: 1, ms: 5000 }, b: { choice: 0, ms: 2000 } };
  room.players.a.answered = room.players.b.answered = true;
  G.tick(room, priv, 9000);
  assert.equal(room.status, "reveal");
  assert.equal(room.players.a.score, 175);
  assert.equal(room.players.b.score, 0); // -30 sıfırın altına inmez
  assert.equal(room.reveal.results.b.delta, 0);
  assert.equal(room.reveal.correctIndex, 1);

  beat(room, 15000);
  G.tick(room, priv, 15000);
  assert.equal(room.status, "playing");
  assert.equal(room.index, 1);

  // kimse cevaplamaz, süre dolar
  beat(room, 35000);
  G.tick(room, priv, 35000);
  assert.equal(room.status, "reveal");
  assert.equal(room.players.a.totalMs, 25000);
  beat(room, 41000);
  assert.equal(G.tick(room, priv, 41000), true);
  assert.equal(room.status, "finished");
  assert.deepEqual(G.ranking(room).map((r) => r.uid), ["a", "b"]);
});

test("eşit puanda toplam süresi kısa olan önde", () => {
  const { room } = setup(2);
  room.players.a.score = room.players.b.score = 300;
  room.players.a.totalMs = 9000;
  room.players.b.totalMs = 7000;
  assert.equal(G.ranking(room)[0].uid, "b");
});

test("bağlantısı kopan beklenmez", () => {
  const { room, priv } = setup(2, 1);
  G.tick(room, priv, 4000);
  room.players.a.lastSeen = 4000 + C.STALE_MS; // yalnızca a bağlı
  priv.answers["0"] = { a: { choice: 1, ms: 1000 } };
  room.players.a.answered = true;
  G.tick(room, priv, 4000 + C.STALE_MS);
  assert.equal(room.status, "reveal");
  assert.equal(room.reveal.results.b.choice, null);
});

test("kurucu çıkınca yönetim en eski oyuncuya geçer", () => {
  const { room, priv } = setup(3);
  room.status = "lobby";
  delete room.players.a;
  G.tick(room, priv, 2000);
  assert.equal(room.hostUid, "b");
});

test("kurucu 1 dakika yoksa yönetim devredilir, öncesinde devredilmez", () => {
  const { room, priv } = setup(2);
  room.status = "lobby";
  room.players.b.lastSeen = 1000 + C.HOST_STALE_MS - 1;
  G.tick(room, priv, 1000 + C.HOST_STALE_MS - 1);
  assert.equal(room.hostUid, "a");
  room.players.b.lastSeen = 1000 + C.HOST_STALE_MS;
  G.tick(room, priv, 1000 + C.HOST_STALE_MS);
  assert.equal(room.hostUid, "b");
});

test("boş oda 1 dakika sonra kapanır", () => {
  const { room, priv } = setup(1);
  room.status = "lobby";
  delete room.players.a; // son oyuncu çıktı
  G.tick(room, priv, 5000);
  assert.equal(room.emptySince, 5000);
  assert.equal(G.isClosed(room, 5000 + C.EMPTY_CLOSE_MS - 1), false);
  assert.equal(G.isClosed(room, 5000 + C.EMPTY_CLOSE_MS), true);
});

test("bağlantısı kopan tek oyuncunun odası da kapanır, dönerse kapanmaz", () => {
  const { room, priv } = setup(1);
  room.status = "lobby";
  const gone = 1000 + C.STALE_MS;
  assert.equal(G.isClosed(room, gone + C.EMPTY_CLOSE_MS - 1), false);
  assert.equal(G.isClosed(room, gone + C.EMPTY_CLOSE_MS), true);
  room.players.a.lastSeen = gone + 30000; // geri döndü
  G.tick(room, priv, gone + 30000);
  assert.equal(room.emptySince, null);
});

test("ödüller: kazanan 20 Taş, günlük sınır 100", () => {
  const rank = [
    { uid: "a", correct: 3, answered: 5 },
    { uid: "b", correct: 1, answered: 5 },
    { uid: "c", correct: 0, answered: 0 },
  ];
  const users = {
    a: { badges: [], tasDaily: { day: "2026-11-11", amount: 95 } },
    b: { badges: ["ilk_mac"], tasDaily: { day: "2026-11-10", amount: 100 } },
    c: { badges: [] },
  };
  const r = G.rewards(rank, users, "2026-11-11");
  assert.equal(r.a.tas, 5); // sınıra takıldı
  assert.equal(r.a.xp, 80);
  assert.deepEqual(r.a.badges, ["ilk_mac", "ilk_galibiyet"]);
  assert.equal(r.b.tas, 5);
  assert.equal(r.c, undefined); // hiç cevap vermeyen ödül almaz
});
