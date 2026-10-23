# Little Muslim als iOS-App

Dieser Ordner macht aus der Web-App eine echte iPhone-App (Capacitor 8.5). Gebaut wird **ohne Mac** auf einem Mac-Rechner von GitHub („GitHub Actions“).

## Was die App-Version anders macht
- Alle Dateien liegen in der App (offline). Nur die Filme werden weiter online von GitHub Pages geladen.
- Erinnerungen (Gebete, Athkār, al-Mulk/al-Kahf, Hadith) laufen als **Mitteilungen direkt auf dem Gerät** – ohne Server.
- Links zu Quellen öffnen sich in einem Safari-Fenster.
- Kein Service-Worker (sonst bleiben alte Versionen hängen).

## Einmal einrichten
1. **Apple-Entwicklerkonto** anlegen: https://developer.apple.com/programs/ (99 $ im Jahr).
2. **App in App Store Connect anlegen** (https://appstoreconnect.apple.com → Apps → +):
   - Bundle-ID: `de.littlemuslim.app` (vorher unter developer.apple.com → Identifiers registrieren)
   - Name z. B. „Little Muslim – Duas & Qur'an“ (Wörter wie „für Kinder“ sind der Kinder-Kategorie vorbehalten)
   - Kategorie: **Bildung**
3. **API-Schlüssel** erstellen: App Store Connect → Benutzer und Zugriff → Integrationen → App Store Connect API → Schlüssel hinzufügen (Zugriff „App Manager“). Die `.p8`-Datei herunterladen (geht nur einmal!), Key-ID und Issuer-ID notieren.
4. **Secrets im GitHub-Repo** eintragen (Settings → Secrets and variables → Actions → New repository secret):
   - `APPLE_TEAM_ID` – Team-ID (developer.apple.com → Membership)
   - `ASC_KEY_ID` – Key-ID
   - `ASC_ISSUER_ID` – Issuer-ID
   - `ASC_KEY_P8` – kompletter Inhalt der `.p8`-Datei

## App bauen und hochladen
GitHub → **Actions** → „iOS-App bauen“ → **Run workflow** → Version eingeben (z. B. 1.0.0).
- Ohne Secrets: prüft nur, ob die App baut.
- Mit Secrets: signiert die App und lädt sie zu **TestFlight** hoch. Nach 10–30 Minuten erscheint sie dort; über die TestFlight-App auf dem iPhone kannst du sie testen.

## Vor dem Einreichen
- `datenschutz.html` im Repo: Name, Anschrift und E-Mail eintragen, DPA mit Supabase abschließen. Die Adresse `https://pfgx6ny8sn-dev.github.io/-dua-app/datenschutz.html` in App Store Connect als Datenschutz-URL angeben.
- App-Datenschutz in App Store Connect: „Name“ und „Spielinhalte/Fortschritt“ (nur bei Familien-Funktion), nicht mit Identität verknüpft, kein Tracking.
- Screenshots (6,9″ iPhone) und Beschreibung.
