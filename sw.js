/* Offline-Start: App-Seite und Symbole werden gespeichert, Filme werden normal geladen. */
const C = "lm-v125";
const CORE = ["./", "index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(C).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.origin !== location.origin || u.pathname.endsWith(".mp4")) return;
  const fresh = e.request.mode === "navigate" || u.pathname.endsWith("/") || u.pathname.endsWith(".html") || u.pathname.endsWith("version.json");
  e.respondWith(fetch(fresh ? new Request(u.href, {cache: "no-store", credentials: "same-origin"}) : e.request).then(r => { if (r.ok) { const cp = r.clone(); caches.open(C).then(c => c.put(e.request, cp)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match("index.html"))));
});
/* Gebets-Push-Nachrichten */
self.addEventListener("push", e => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch (_) { d = {title: "Little Muslim", body: e.data ? e.data.text() : ""}; }
  e.waitUntil(self.registration.showNotification(d.title || "Little Muslim", {body: d.body || "", tag: d.tag || "prayer", icon: "icon-192.png", badge: "icon-192.png", renotify: true, data: {url: d.url || "./"}}));
});
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || "./", go = url.includes("#") ? url.split("#")[1] : "";
  e.waitUntil(self.clients.matchAll({type: "window", includeUncontrolled: true}).then(cs => { for (const c of cs) { if ("focus" in c) { if (go) c.postMessage({lmGo: go}); return c.focus(); } } return self.clients.openWindow(url); }));
});
