# QUL issue #596: Licensing clarification — Madinah V2 layout (mushaf-layout/10) for offline iOS app

- URL: https://github.com/TarteelAI/quranic-universal-library/issues/596
- Opened by ahmad-atef on 2026-05-05T10:56:01Z; state: closed, closed 2026-05-06T20:57:38Z
- Retrieved through the GitHub API on 2026-10-11 (raw JSON beside this file).

## Question

Salam,

I'm building a small personal iOS app (Rafek AlBaqara) that helps users stay
consistent with reading Surat Al-Baqarah daily, with a calm, non-judgmental
tone — not a memorisation app, not monetised at launch.

I'd like to bundle the **KFGQPC V2 layout (1421H print)** SQLite from
https://qul.tarteel.ai/resources/mushaf-layout/10 so the 48 Al-Baqarah pages
render fully offline. The KFGQPC V2 font is sourced separately from
qurancomplex.org and embedded in the app to render the PUA codepoints in
the layout SQLite.

I've read the FAQ — in particular #9 (commercial use permitted with per-
resource license review). The resource page for Madinah V2 doesn't surface
a per-asset license, so I wanted to confirm directly before bundling:

1. Is the V2 layout SQLite covered by a permissive license that allows
   offline bundling in a third-party iOS app distributed via the App Store?
2. What attribution would you like in the app's About / Credits screen
   (linkback, logo, specific wording)?
3. Are there constraints I should be aware of — e.g. modification of the
   layout, re-export to other formats, sharing the bundled SQLite outside
   the running app?

I'm aware of #589 and am filing this as a narrower, per-resource ask that
should be easier to answer.

Jazakum Allah khayran.

## Comment by naveed-ahmad (MEMBER) — 2026-05-06T20:57:38Z
Permalink: https://github.com/TarteelAI/quranic-universal-library/issues/596#issuecomment-4392094153

All layouts, including Madinah V2, are available for free and can be used in both personal and commercial projects. You’re welcome to bundle the SQLite in your app, use it offline, modify it, or transform it into other formats as needed.

Attribution is optional. But a simple credit such as “Data provided by QUL” with a link back is much appreciated.
