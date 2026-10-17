// Little Muslim – Push: läuft jede Minute (pg_cron). Gebetszeiten + Erinnerungen wie auf dem Home-Bildschirm
// (Morgen-/Abend-Athkar, al-Mulk am Abend, al-Kahf am Freitag, Hadith des Tages). Schon erledigt → keine Erinnerung.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

/* ---- Gebetszeiten (gleiche Rechnung wie in der App) ---- */
const dtr = (d: number) => d * Math.PI / 180, rtd = (r: number) => r * 180 / Math.PI;
const sin = (d: number) => Math.sin(dtr(d)), cos = (d: number) => Math.cos(dtr(d)), tan = (d: number) => Math.tan(dtr(d));
const asin = (x: number) => rtd(Math.asin(x)), acos = (x: number) => rtd(Math.acos(x)), atan2 = (y: number, x: number) => rtd(Math.atan2(y, x)), acot = (x: number) => rtd(Math.atan(1 / x));
const fix = (a: number, b: number) => { a = a - b * Math.floor(a / b); return a < 0 ? a + b : a; };
const fixA = (a: number) => fix(a, 360), fixH = (a: number) => fix(a, 24);
function julian(y: number, m: number, d: number) { if (m <= 2) { y--; m += 12; } const A = Math.floor(y / 100), B = 2 - A + Math.floor(A / 4); return Math.floor(365.25 * (y + 4716)) + Math.floor(30.6001 * (m + 1)) + d + B - 1524.5; }
function sunPos(jd: number) {
  const D = jd - 2451545.0, g = fixA(357.529 + 0.98560028 * D), q = fixA(280.459 + 0.98564736 * D);
  const L = fixA(q + 1.915 * sin(g) + 0.020 * sin(2 * g)), e = 23.439 - 0.00000036 * D;
  const RA = atan2(cos(e) * sin(L), cos(L)) / 15;
  return { decl: asin(sin(e) * sin(L)), eqt: q / 15 - fixH(RA) };
}
type M = { fajr: number; isha?: number; ishaMin?: number; asrF: number };
function compute(date: { y: number; m: number; d: number }, lat: number, lng: number, m: M) {
  const jd = julian(date.y, date.m, date.d) - lng / (15 * 24);
  const mid = (t: number) => fixH(12 - sunPos(jd + t).eqt);
  const angTime = (ang: number, t: number, ccw?: boolean) => { const dec = sunPos(jd + t).decl, noon = mid(t); const T = acos((-sin(ang) - sin(dec) * sin(lat)) / (cos(dec) * cos(lat))) / 15; return noon + (ccw ? -T : T); };
  const asr = (f: number, t: number) => { const dec = sunPos(jd + t).decl; return angTime(-acot(f + tan(Math.abs(lat - dec))), t); };
  let t: Record<string, number> = { fajr: 5, sunrise: 6, dhuhr: 12, asr: 13, sunset: 18, isha: 18 };
  for (let k = 0; k < 2; k++) {
    const p = (x: number) => x / 24;
    t = { fajr: angTime(m.fajr, p(t.fajr), true), sunrise: angTime(0.833, p(t.sunrise), true), dhuhr: mid(p(t.dhuhr)), asr: asr(m.asrF, p(t.asr)), sunset: angTime(0.833, p(t.sunset)), isha: m.ishaMin ? 0 : angTime(m.isha!, p(t.isha)) };
  }
  t.maghrib = t.sunset;
  if (m.ishaMin) t.isha = t.maghrib + m.ishaMin / 60;
  const night = fixH(t.sunrise - t.sunset), diff = (a: number, b: number) => fixH(b - a);
  const pf = m.fajr / 60 * night;
  if (isNaN(t.fajr) || diff(t.fajr, t.sunrise) > pf) t.fajr = t.sunrise - pf;
  if (!m.ishaMin) { const pi = m.isha! / 60 * night; if (isNaN(t.isha) || diff(t.sunset, t.isha) > pi) t.isha = t.sunset + pi; }
  const out: Record<string, number> = {}; for (const k in t) out[k] = t[k] - lng / 15; return out;
}
const METHODS: Record<string, { fajr: number; isha?: number; ishaMin?: number }> = {
  mwl: { fajr: 18, isha: 17 }, uoif: { fajr: 12, isha: 12 }, isna: { fajr: 15, isha: 15 }, egypt: { fajr: 19.5, isha: 17.5 }, makkah: { fajr: 18.5, ishaMin: 90 },
};
function dayParts(date: Date, tz: string) {
  const p = new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(date);
  const g = (t: string) => +p.find((x) => x.type === t)!.value; return { y: g("year"), m: g("month"), d: g("day") };
}
/* Unterschied Ortszeit – UTC in ms für einen Zeitpunkt */
function tzOff(ms: number, tz: string) {
  const p = new Intl.DateTimeFormat("en-US", { timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(new Date(ms));
  const g = (t: string) => +p.find((x) => x.type === t)!.value;
  return Date.UTC(g("year"), g("month") - 1, g("day"), g("hour") % 24, g("minute"), g("second")) - Math.floor(ms / 1000) * 1000;
}
function times(now: Date, s: Sub) {
  const d = dayParts(now, s.tz), m = { ...(METHODS[s.method] || METHODS.mwl), asrF: s.asr || 1 };
  const utc = compute(d, s.lat, s.lng, m), ms0 = Date.UTC(d.y, d.m - 1, d.d), out: Record<string, number> = {};
  for (const k in utc) { let ms = ms0 + utc[k] * 3600e3; ms = Math.round(ms / 60000) * 60000 + (k === "dhuhr" ? 60000 : 0); out[k] = ms; }
  const off = tzOff(now.getTime(), s.tz), local = (h: number, mi: number) => Date.UTC(d.y, d.m - 1, d.d, h, mi) - off;
  const ymd = `${d.y}-${String(d.m).padStart(2, "0")}-${String(d.d).padStart(2, "0")}`;
  const doy = Math.round((Date.UTC(d.y, d.m - 1, d.d) - Date.UTC(d.y, 0, 0)) / 864e5);
  return { t: out, key: `${d.y}-${d.m}-${d.d}`, ymd, local, friday: new Date(Date.UTC(d.y, d.m - 1, d.d)).getUTCDay() === 5, doy };
}

/* ---- Texte ---- */
const N: Record<string, [string, string, string]> = {
  fajr: ["Fadschr", "Fajr", "الفجر"], sunrise: ["Schurūq", "Sunrise", "الشروق"], dhuhr: ["Dhuhr", "Dhuhr", "الظهر"],
  asr: ["ʿAṣr", "ʿAsr", "العصر"], maghrib: ["Maghrib", "Maghrib", "المغرب"], isha: ["ʿIschāʾ", "ʿIshāʾ", "العشاء"],
};
const hhmm = (ms: number, tz: string) => new Intl.DateTimeFormat("de-DE", { timeZone: tz, hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(ms));
/* Hadith des Tages – gleiche Liste und Reihenfolge wie in der App (Tag des Jahres % Anzahl) */
let HD: [string, string, string][] = [], HDt = 0;
async function loadHD() {
  if (HD.length && Date.now() - HDt < 6 * 3600e3) return;
  try { const r = await fetch("https://pfgx6ny8sn-dev.github.io/-dua-app/push_hadith.json", { cache: "no-store" }); if (r.ok) { HD = await r.json(); HDt = Date.now(); } } catch (_) { /* ohne Liste: kein Hadith-Push */ }
}
/* Erinnerungen wie die Karten auf dem Home-Bildschirm */
const X: Record<string, { need: string; go: string; de: [string, string]; en: [string, string] }> = {
  sabah: { need: "athkar", go: "go-ak-s", de: ["☀️ Athkār aṣ-Ṣabāḥ", "Jetzt die Morgen-Adhkār sprechen · أَذْكَارُ الصَّبَاح"], en: ["☀️ Athkār aṣ-Ṣabāḥ", "Time for your morning adhkār · أَذْكَارُ الصَّبَاح"] },
  masa: { need: "athkar", go: "go-ak-m", de: ["🌙 Athkār al-Masāʾ", "Jetzt die Abend-Adhkār sprechen · أَذْكَارُ المَسَاء"], en: ["🌙 Athkār al-Masāʾ", "Time for your evening adhkār · أَذْكَارُ المَسَاء"] },
  mulk: { need: "wird", go: "go-mulk", de: ["🌙 Nicht vergessen: Sūrat al-Mulk", "Vor dem Schlafen · 30 Verse · ca. 5 Min."], en: ["🌙 Don't forget: Sūrat al-Mulk", "Before sleep · 30 verses · about 5 min."] },
  kahf: { need: "wird", go: "go-kahf", de: ["🕌 Heute ist Freitag: Sūrat al-Kahf", "Wer am Freitag al-Kahf liest, dem leuchtet ein Licht bis zum nächsten Freitag."], en: ["🕌 It's Friday: Sūrat al-Kahf", "Whoever reads al-Kahf on Friday, a light shines for him until the next Friday."] },
  hadith: { need: "hadith", go: "go-hadith", de: ["📜 Hadith des Tages", ""], en: ["📜 Hadith of the day", ""] },
};

type Sub = { endpoint: string; p256dh: string; auth: string; lat: number; lng: number; tz: string; method: string; asr: number; prayers: string[]; before: string; lang: string; place: string; sent: string | null; extras: string[] | null; done: string | null };

Deno.serve(async (req) => {
  const { data: cfg } = await sb.from("push_config").select("k,v");
  const C = Object.fromEntries((cfg || []).map((r: { k: string; v: string }) => [r.k, r.v]));
  if (!C.cron_secret || req.headers.get("x-cron") !== C.cron_secret) return new Response("forbidden", { status: 403 });
  webpush.setVapidDetails(C.vapid_subject || "https://pfgx6ny8sn-dev.github.io/-dua-app/", C.vapid_public, C.vapid_private);
  const { data: subs, error } = await sb.from("push_subs").select("*");
  if (error) return new Response(error.message, { status: 500 });
  await loadHD();
  const now = Date.now(); let sent = 0; const gone: string[] = [];
  await Promise.all((subs as Sub[] || []).map(async (s) => {
    try {
      const T = times(new Date(now), s), { t, key } = T, en = s.lang === "en";
      const send = async (tag: string, payload: Record<string, string>) => {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, JSON.stringify(payload), { TTL: 1800, urgency: "high" });
        sent++;
        const list = [tag, ...(s.sent || "").split(",").filter(Boolean)].slice(0, 24).join(",");
        await sb.from("push_subs").update({ sent: list }).eq("endpoint", s.endpoint);
        s.sent = list;
      };
      /* 1. Gebete */
      const offs = s.before === "both" ? [10, 0] : s.before === "10" ? [10] : [0];
      for (const k of s.prayers || []) {
        if (!t[k]) continue;
        for (const o of offs) {
          const at = t[k] - o * 60000, tag = `${key}:${k}:${o}`;
          if (now < at || now >= at + 90000 || (s.sent || "").includes(tag)) continue;
          const nm = N[k][en ? 1 : 0], title = o ? (en ? `⏳ ${nm} in ${o} minutes` : `⏳ Gleich ${nm} – in ${o} Min.`) : (k === "sunrise" ? (en ? `🌅 Sunrise – Fajr time has ended` : `🌅 Sonnenaufgang – die Fadschr-Zeit ist vorbei`) : (en ? `🕌 Time for ${nm}` : `🕌 Zeit für ${nm}`));
          const body = `${N[k][2]} · ${hhmm(t[k], s.tz)} · ${s.place || ""}`.trim();
          await send(tag, { title, body, tag: `prayer-${k}`, url: `./#go-${k}` });
        }
      }
      /* 2. Erinnerungen wie auf dem Home-Bildschirm */
      const ex = s.extras || ["athkar", "wird", "hadith"], done = s.done || "";
      const due: [string, number][] = [["sabah", t.fajr + 30 * 60000], ["masa", t.asr + 30 * 60000], ["mulk", t.isha + 30 * 60000], ["hadith", T.local(7, 30)]];
      if (T.friday) due.push(["kahf", T.local(10, 0)]);
      for (const [id, at] of due) {
        const x = X[id]; if (!x || !ex.includes(x.need) || !at) continue;
        const tag = `${key}:x:${id}`;
        if (now < at || now >= at + 90000 || (s.sent || "").includes(tag)) continue;
        if (id !== "hadith" && done.includes(`${T.ymd}:${id}`)) continue;
        let [title, body] = en ? x.en : x.de;
        if (id === "hadith" && !HD.length) continue;
        if (id === "hadith") { const h = HD[T.doy % HD.length]; body = `${en ? h[1] : h[0]} (${h[2]})`; }
        await send(tag, { title, body, tag: `lm-${id}`, url: `./#${x.go}` });
      }
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) gone.push(s.endpoint);
    }
  }));
  if (gone.length) await sb.from("push_subs").delete().in("endpoint", gone);
  return new Response(JSON.stringify({ subs: subs?.length || 0, sent, removed: gone.length }), { headers: { "Content-Type": "application/json" } });
});
