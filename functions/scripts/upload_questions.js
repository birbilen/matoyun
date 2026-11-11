#!/usr/bin/env node
// Soruları CSV dosyasından (ya da Google E-Tablo'nun CSV bağlantısından)
// Firestore'a yükler ve soru dizinini (meta/questionIndex) yeniden kurar.
//
// Kullanım (functions klasöründe):
//   npm run sorular:yukle -- ../data/sorular_ornek.csv --emulator
//   npm run sorular:yukle -- "https://docs.google.com/.../pub?output=csv" --project PROJE_KIMLIGI
//
// --emulator : yerel emülatöre yükler (hesap gerekmez)
// --project  : gerçek Firebase projesine yükler. Önce hizmet hesabı anahtarını
//              indir ve GOOGLE_APPLICATION_CREDENTIALS değişkenine yolunu yaz.

const fs = require("fs");
const admin = require("firebase-admin");
const { TOPICS } = require("../game");

const args = process.argv.slice(2);
const source = args.find((a) => !a.startsWith("--"));
const useEmulator = args.includes("--emulator");
const projIdx = args.indexOf("--project");
const projectId = useEmulator
  ? "demo-matduellosu"
  : projIdx >= 0
    ? args[projIdx + 1]
    : undefined;

if (!source || (!useEmulator && !projectId)) {
  console.error(
    "Kullanım: node scripts/upload_questions.js <dosya.csv | CSV bağlantısı> (--emulator | --project PROJE_KIMLIGI)"
  );
  process.exit(1);
}
if (useEmulator) {
  process.env.FIRESTORE_EMULATOR_HOST =
    process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
}

// Tırnak içindeki virgülleri ve satır sonlarını destekleyen küçük CSV okuyucu.
function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && text[i + 1] === "\n") i++;
      row.push(cell);
      cell = "";
      if (row.some((c) => c.trim() !== "")) rows.push(row);
      row = [];
    } else cell += ch;
  }
  row.push(cell);
  if (row.some((c) => c.trim() !== "")) rows.push(row);
  return rows;
}

function toQuestions(rows) {
  const header = rows[0].map((h) => h.trim().replace(/^﻿/, ""));
  const need = ["id", "konu", "zorluk", "metin", "sik_a", "sik_b", "sik_c", "sik_d", "dogru", "cozum", "gorsel", "mod"];
  for (const n of need) {
    if (!header.includes(n)) throw new Error(`Eksik sütun: ${n}`);
  }
  const errors = [];
  const seen = new Set();
  const questions = rows.slice(1).map((r, i) => {
    const line = i + 2;
    const v = Object.fromEntries(header.map((h, j) => [h, (r[j] || "").trim()]));
    const q = {
      id: v.id,
      topic: v.konu,
      difficulty: Number(v.zorluk),
      text: v.metin,
      options: [v.sik_a, v.sik_b, v.sik_c, v.sik_d],
      correct: Number(v.dogru),
      solution: v.cozum,
      image: v.gorsel || null,
      mode: v.mod || "ikisi",
    };
    const bad = (msg) => errors.push(`Satır ${line} (${q.id || "?"}): ${msg}`);
    if (!/^[A-Za-z0-9_-]+$/.test(q.id)) bad("id boş ya da geçersiz");
    if (seen.has(q.id)) bad("id tekrar ediyor");
    seen.add(q.id);
    if (!TOPICS.includes(q.topic)) bad(`bilinmeyen konu "${q.topic}"`);
    if (![1, 2, 3].includes(q.difficulty)) bad("zorluk 1, 2 ya da 3 olmalı");
    if (!q.text) bad("metin boş");
    if (q.options.some((o) => !o)) bad("4 şık da dolu olmalı");
    if (new Set(q.options).size !== 4) bad("şıklar birbirinden farklı olmalı");
    if (v.dogru === "" || ![0, 1, 2, 3].includes(q.correct)) {
      bad("dogru 0, 1, 2 ya da 3 olmalı (0 = ilk şık)");
    }
    if (!["duello", "antrenman", "ikisi"].includes(q.mode)) {
      bad("mod duello, antrenman ya da ikisi olmalı");
    }
    return q;
  });
  if (errors.length) throw new Error("Hatalı satırlar:\n" + errors.join("\n"));
  return questions;
}

async function main() {
  const text = /^https?:\/\//.test(source)
    ? await (await fetch(source)).text()
    : fs.readFileSync(source, "utf8");
  const questions = toQuestions(parseCsv(text));

  admin.initializeApp({ projectId });
  const db = admin.firestore();

  const index = { duello: {}, antrenman: {} };
  const add = (mode, q) => (index[mode][q.topic] = index[mode][q.topic] || []).push(q.id);
  for (let i = 0; i < questions.length; i += 400) {
    const batch = db.batch();
    for (const q of questions.slice(i, i + 400)) {
      const { id, ...data } = q;
      batch.set(db.doc(`questions/${id}`), data);
      if (q.mode !== "antrenman") add("duello", q);
      if (q.mode !== "duello") add("antrenman", q);
    }
    await batch.commit();
  }
  await db.doc("meta/questionIndex").set(index);
  console.log(
    `${questions.length} soru yüklendi (${useEmulator ? "emülatör" : projectId}).`
  );
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
