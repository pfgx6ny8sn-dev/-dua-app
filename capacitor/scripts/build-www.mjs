// Baut den Ordner www/ für die App aus den Web-Dateien im Repo.
// Filme bleiben online (zu groß für die App) und werden von GitHub Pages geladen.
import fs from "node:fs";
import path from "node:path";
const ROOT = path.resolve(import.meta.dirname, "..", "..");
const OUT = path.resolve(import.meta.dirname, "..", "www");
const NM = path.resolve(import.meta.dirname, "..", "node_modules");
const VBASE = "https://pfgx6ny8sn-dev.github.io/-dua-app/";
const COPY = ["manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png", "mushaf.js", "mushaf_de.js", "mushaf_en.js", "mushaf_warsh.js", "fonts",
  "tafsir_ar.js", "tafsir_en.js", "asbab.js", "asbab_en.js", "push_hadith.json", "version.json", "audio"];
fs.rmSync(OUT, {recursive: true, force: true});
fs.mkdirSync(OUT, {recursive: true});
for(const f of COPY){ const s = path.join(ROOT, f); if(fs.existsSync(s)) fs.cpSync(s, path.join(OUT, f), {recursive: true}); }
// Capacitor-Laufzeit + Plugins als einfache Skripte (die App nutzt keinen Bundler)
const libs = [["@capacitor/core/dist/capacitor.js", "capacitor.js"],
  ["@capacitor/browser/dist/plugin.js", "cap-browser.js"],
  ["@capacitor/local-notifications/dist/plugin.js", "cap-local-notifications.js"]];
let tags = "";
for(const [src, dst] of libs){ const s = path.join(NM, src); if(!fs.existsSync(s)) throw new Error("fehlt: " + src); fs.copyFileSync(s, path.join(OUT, dst)); tags += `<script src="${dst}"></script>\n`; }
let html = fs.readFileSync(path.join(ROOT, "index.html"), "utf8");
// Service-Worker in der App aus (sonst bleiben alte Versionen hängen)
html = html.replace(/<script>if\("serviceWorker" in navigator[\s\S]*?<\/script>/, "");
html = html.replace(/<meta charset="UTF-8">/i, m => `${m}\n<script>window.LM_VBASE=${JSON.stringify(VBASE)};window.LM_APP=1;</script>\n${tags}`);
fs.writeFileSync(path.join(OUT, "index.html"), html);
const size = (d) => fs.readdirSync(d, {withFileTypes: true}).reduce((a, e) => a + (e.isDirectory() ? size(path.join(d, e.name)) : fs.statSync(path.join(d, e.name)).size), 0);
console.log(`www/ fertig – ${(size(OUT) / 1e6).toFixed(1)} MB`);
