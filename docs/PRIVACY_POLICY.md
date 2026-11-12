# TahfeezAI — Privacy Policy

_Last updated: 11 November 2026_

TahfeezAI helps you read and memorize the Quran. It is built to keep your data on your phone. There are no accounts, no ads, no analytics and no tracking.

## What stays on your phone

- **Your recitation.** When you recite, the microphone audio is analysed on your phone by the app's own speech model, to follow your place and point out mistakes. The audio is never sent anywhere and is not saved: once a recitation ends, its audio is gone.
- **Your memorization data:** which ayahs you have memorized, your test results, your plans, your bookmarks and your settings. They are stored only in the app's storage on your phone.
- **Reminders.** The daily reminder is scheduled on your phone; nothing is sent to a server.

We (the developers) never receive any of this data, and we have no server that stores it.

## When the app uses the internet

Only to play recitation audio, and only when you ask for it:

- **Ayah recitations** stream from the Islamic Network audio service (`cdn.islamic.network`, run by alquran.cloud), or, for some reciters, from EveryAyah (`everyayah.com`).
- **Single-word audio** streams from Quran.com's audio service (`audio.qurancdn.com`).
- **Listen to the correction** asks Quran.com (`api.quran.com`, `api.qurancdn.com`) where each word falls in the reciter's recording, and for some reciters plays that recording from QuranicAudio (`download.quranicaudio.com`). The timings are kept only until the app closes.
- **Downloading a reciter** for offline listening fetches that reciter's audio files from the same service and stores them on your phone; you can delete them at any time.
- **Translations, tafsir and word meanings** other than English and Arabic are downloaded on Android and iOS from the app's own open-source repository on GitHub (`github.com/Omar-8/TahfeezAI`, its release files), when the app's language needs them or when you download one, and stored on your phone; you can delete them at any time. Each download is checked against a fingerprint built into the app before it is used.

These requests contain only the name of the audio file (which reciter and which ayah or word). Like any internet request, they also reveal your device's IP address to that service, which is governed by its own privacy terms. No other information about you is sent. Everything else — the Quran text and the English and Arabic translations, tafsir and word meanings — is part of the app and works without internet; a downloaded translation, tafsir or word-meaning set works without internet too.

On Android the app also asks Google Play, on your phone, whether an update is available, and may show Google Play's own rating box now and then; both are handled by Google Play under its terms, and the app sends nothing of its own. On iPhone and iPad the app asks the App Store (`itunes.apple.com`) for the version number of the app's listing, to know whether an update is available; that request names only the app, not you, and like any request reveals your IP address to Apple. Sharing the app hands a short text with its store link to the app you choose.

## In a web browser

The web version works the same way: your recitation is checked inside your browser and never sent anywhere, and your memorization data, bookmarks and settings are kept in your browser's storage on your device. Clearing the site's data in your browser deletes them. In addition:

- **The app's files and its recitation model** (about 91 MB, fetched the first time you open a Mushaf page, then kept by your browser) come from the website that hosts the app. Like any website, its host receives these requests, including your IP address, under its own terms.
- **Fonts.** The engine the app is built with (Flutter) loads its default font and, where the app's own fonts lack a character (for example Japanese or Korean translations), a matching font from Google Fonts (`fonts.gstatic.com`). These requests name only the font; like any request, they reveal your IP address to Google.
- Downloading reciters for offline listening and the daily reminder are not available in the browser.

## Reciters' photos

Some reciters are shown with a small photo beside their name. The photos are part of the app (no internet is used to show them) and come from Wikimedia Commons, credited here as Commons states their author and licence:

- Mahmoud Khalil Al-Husary — Egyptian Government (identity card), public domain
- Muhammad Siddiq Al-Minshawi — unknown photographer, public domain
- Abdul Basit Abdus-Samad — unknown photographer, Muslim News (South Africa) 1966, public domain
- Abdur-Rahman As-Sudais — Prime Minister's Office, Government of India, GODL-India
- Saud Ash-Shuraym — Vice President's Secretariat, Government of India, GODL-India
- Yasser Al-Dossary — MAL MALDIVE, CC BY-SA 4.0
- Nasser Al-Qatami — Ayman dhū alghiná, CC BY-SA 4.0
- Shahriar Parhizgar — Mostafameraji, CC BY-SA 4.0
- Karim Mansoori — Mostafameraji, CC BY-SA 4.0
- Muhammad Jibreel — Alhidaya Croydon, CC BY 3.0
- Mishary Alafasy — quranic.ru, "copyrighted free use"
- Maher Al-Muaiqly — Real avdulmouhd, CC BY-SA 4.0
- Saad Al-Ghamdi — الشيخ هيثم الدخين, CC BY-SA 4.0
- Ahmad al-Ajamy — أحمد زين, CC BY-SA 3.0
- Ayman Suwaid — propagerlislam.net, public domain
- Ali Jaber — Engalali9, CC0
- Abdullah Awad Al-Juhani — الشيخ هيثم الدخين, CC BY-SA 4.0
- Abdullah Matroud — tvquran.com, CC BY-SA 4.0

The photos were cropped and made smaller. If you hold the rights to one of them, or are its subject, and want it removed, write to the address below and it will be taken out of the app. Reciters without a photo are shown by the first letter of their name.

## Backups

**Settings → Your data → Export** saves your memorization data, bookmarks and settings to a file **you** choose. Where that file goes (your phone, a cloud drive, a message) is up to you. **Import** reads such a file back. The app never uploads backups by itself.

## Permissions

- **Microphone** — to follow and check your recitation, on the phone only. Used only while you are reciting.
- **Notifications** — for the optional daily memorization reminder.
- **Internet** — for streaming and downloading recitation audio, and downloading translations, tafsir and word meanings.
- **Vibration** — to signal a mistake while you recite.
- **Run at startup** — to keep your daily reminder after the phone restarts.

## Deleting your data

**Settings → Your data → Reset all data** deletes all of your memorization data, bookmarks and settings. Uninstalling the app deletes everything it stored, including downloaded recitations, translations, tafsir and word meanings.

## Children

The app is suitable for all ages and collects no personal information from anyone, including children.

## Changes

If this policy changes, the new version will be published here with a new date.

## Contact

Questions about privacy: **tahfeez.ai.app@gmail.com**
