# Licensing evidence — Mushaf data (collected 2026-10-11)

Local copies of what the licensing decisions in
`docs/THIRD_PARTY_RESOURCES.md` ("Mushaf licensing, 2026-10-11") rest on, in
case the pages change or disappear. Each file's SHA-256 is in `SHA256SUMS`
(check with `sha256sum -c SHA256SUMS` in this directory).

## QUL (Tarteel) — GitHub, TarteelAI/quranic-universal-library

Each issue as Markdown (question, then every comment with its author, role and
timestamp, and its permalink) and as the GitHub API's raw JSON. Retrieved with
`gh api repos/TarteelAI/quranic-universal-library/issues/<n>[/comments]`.

| File | What it shows |
|---|---|
| `qul-github/issue-596.md` | **QUL team (naveed-ahmad, MEMBER), 2026-05-06**, on the KFGQPC V2 layout (`mushaf-layout/10`): all layouts free for personal and commercial use; bundling, offline use, modification and conversion allowed; attribution optional ("Data provided by QUL" appreciated). |
| `qul-github/issue-719.md` | **QUL team, 2026-08-18**: the original author is the King Fahd Complex; "most resources from Quran complex were released under CC BY 4.0"; ask the publisher for exact terms. |
| `qul-github/issue-803.md` | **QUL team, 2026-10-07**: datasets generated and maintained by QUL "are available for commercial use"; licence information to be added per resource. |
| `qul-github/issue-768.md` | Another developer's request for the V1/V2 layouts, and a formal letter sent to the King Fahd Complex (2026-09-27). |

## QUL — the website (screenshots by the project owner, logged in, 2026-10-11)

`qul-screenshots/`: the KFGQPC V2 and V4 layout pages and the QPC V2 Glyph –
Word by Word page (resource 61), with **no licence shown**; QUL's FAQ answer on
commercial use ("review the licensing terms for each resource"); Tarteel's
terms of service (2021), which concern Tarteel's services, not QUL data
licences.

## Quran.ws (Quran Engine) and the King Fahd Complex's usage rights

| File | What it is |
|---|---|
| `quran-engine/LICENSE-b1233ef.txt` | `LICENSE` of github.com/quran-ws/quran-engine at commit `b1233efed9938572854138980df9461929adafa3` ("Adopt the Quran.ws licence notice", Abdullah Ibeid, 2026-09-11): data under CC BY 4.0 with attribution waived for use inside a product; the King Fahd Complex's usage-rights statement reproduced in full, Arabic and English (free use including "in websites, software, and other similar intermediates"). |
| `quran-engine/LICENSE-v0.2.2.txt` | The same file at tag `v0.2.2` (`4ad5c1292ac88d56b5fc7d58fce46c459231b096`), the engine version Tahfeez builds — byte-identical. |
| `quran-engine/quran-ws-licensing-page.html` | https://quran.ws/docs/reference/licensing as served on 2026-10-11. |

The King Fahd Complex's own site (qurancomplex.gov.sa) could not be reached
from the machine that collected these; its statement is the copy in the
`LICENSE` above.
