# Tahfeez AI — Product Brief

## Vision

Tahfeez AI is a modern, elegant, offline-first Quran application that combines:

- high-quality Quran reading;
- accurate Mushaf presentation;
- translations and tafsir;
- Quran search;
- recitation audio;
- bookmarks and reading history;
- Quran reference collections;
- memorization planning and revision;
- future AI-assisted recitation tracking and mistake detection.

The app should be useful even if the AI features are never enabled.

## Platforms

Primary targets:

- Android
- iOS
- Web / installable PWA

The shared Flutter codebase should contain the majority of domain, data, application, and UI code. Platform-specific adapters are acceptable for capabilities such as widgets, notifications, background execution, audio sessions, file picking, and browser persistence.

## Offline requirement

The application is **offline-first**, with different guarantees per platform.

### Android and iOS

- Core Quran reading must work fully offline.
- Mushaf must work fully offline.
- Quran navigation/search must work fully offline.
- Bundled starter translations/tafsir must work fully offline.
- Bookmarks, history, memorization, and settings must work fully offline.
- Downloaded optional resources must remain usable offline.

### Web

- Offline support is optional.
- Do not block development on PWA persistence or browser storage guarantees.
- Web may fetch resources over the network.
- Preserve the same domain/repository APIs so behavior stays consistent — platform differences belong in adapters/implementations, not in different contracts.

The network is otherwise used for obtaining optional resources, updates, and optional enhanced AI services.

## Brand

Name: **Tahfeez AI**

Tahfeez AI must have:

- its own logo;
- its own launcher icon;
- its own color system;
- its own card treatment;
- its own icons or licensed icon set;
- its own illustrations;
- its own writing/copy;
- its own responsive layouts.

QuranApp is a reference application, not a skin to reproduce.

## Design target

Tahfeez AI should feel approximately 50–60% familiar to a QuranApp user because it uses successful Quran-reader conventions and Material patterns, but it should be immediately recognizable as a different product.

Tahfeez should generally feel:

- more modern;
- more spacious;
- softer;
- calmer;
- more premium;
- stronger in light mode;
- increasingly memorization-centered as later milestones are added.

## Core product areas

### Read
- verse-by-verse reader
- Mushaf reader
- Surah/Juz/Hizb/Page navigation
- multiple scripts
- translations
- tafsir
- word-by-word
- search

### Listen
- reciters
- translation audio
- repeat
- speed
- verse synchronization
- downloads
- background playback

### Organize
- bookmarks
- range bookmarks
- notes
- reading history
- import/export

### Explore
- Verse of the Day
- Quran collections
- topics
- duas
- prophets and references

### Memorize
- memorization plans
- listen/repeat
- hide/reveal
- review scheduling
- strength tracking
- testing

### AI
- live Quran location detection
- live word following
- constrained sequence alignment
- skipped/incorrect/added word detection
- hesitation/self-correction events
- adaptive review coach
- possible on-device recognition later
