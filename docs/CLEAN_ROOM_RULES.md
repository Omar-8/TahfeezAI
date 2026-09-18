# Tahfeez AI — Clean-Room Rules

These rules are project requirements, not legal advice.

Tahfeez AI is an independent Quran application.

The public project **AlfaazPlus/QuranApp** may be studied to understand:

- user-visible functionality;
- workflows;
- information architecture;
- state transitions;
- Quran-domain requirements;
- common Material design patterns;
- performance expectations;
- offline requirements;
- feature relationships.

## Do not mechanically copy

Do not:

- copy Kotlin or Java source into Tahfeez;
- transliterate Kotlin/Java functions into Dart line by line;
- copy comments;
- copy internal class names unnecessarily;
- copy original drawable resources;
- copy logos;
- copy launcher icons;
- copy illustrations;
- copy wallpapers;
- copy screenshots into the application;
- copy custom icon artwork;
- copy exact theme constants merely because they exist in the reference;
- copy large blocks of app copy or localized strings;
- import a reference database until its contents and upstream licenses have been verified;
- assume the repository's GPL license automatically grants redistribution rights for every third-party dataset, font, audio recording, translation, or tafsir resource contained or referenced by the project.

## Tahfeez must use

- independently written Dart/Flutter code;
- Tahfeez AI naming;
- Tahfeez AI branding;
- independently selected theme tokens;
- original or separately licensed icons/assets;
- independently licensed Quran resources;
- independently designed responsive layouts;
- its own backup/resource manifest schemas where practical.

## Functional parity is an acceptable requirement

Tahfeez may intentionally implement equivalent capabilities such as:

- Quran reading modes;
- Quran navigation;
- translation/tafsir workflows;
- search capabilities;
- word-by-word capabilities;
- recitation controls;
- bookmarks and notes;
- offline downloads;
- resource update states;
- themes;
- reminders;
- settings;
- reading history;
- responsive reader behavior.

The implementation must still be independently written.

## Visual reference rule

The design target is approximately **50–60% familiarity**, not a pixel-identical clone.

It is acceptable to learn from:

- information hierarchy;
- which actions are primary vs secondary;
- common card/list/sheet patterns;
- Quran-reader ergonomics;
- general Material 3 conventions;
- useful component density;
- discoverability of reader/audio/settings functions.

Do not deliberately recreate a distinctive branded screen pixel-for-pixel.

If a layout can be improved while preserving the user need, prefer the Tahfeez design direction.

## Resource register

Every external resource shipped or downloaded by Tahfeez must be listed in:

`docs/THIRD_PARTY_RESOURCES.md`

For each resource record:

- name;
- type;
- source URL;
- upstream project;
- license;
- attribution requirement;
- redistribution permission;
- offline redistribution permission;
- modification permission;
- version;
- checksum/hash strategy;
- notes.

Do not add a resource dependency without recording it.

## Quran correctness

The Quran text is not ordinary UI copy.

Never:

- silently edit Quran text;
- normalize stored canonical Quran text destructively;
- use generated AI text as Quran text;
- replace an authoritative dataset with model-generated content.

Search normalization must operate on derived/indexed representations while preserving canonical source text.

## Implementation discipline

Milestone 0 is allowed to study the reference repository deeply and create a behavioral specification.

After that, implementation milestones should primarily use the frozen specification in `docs/reference/`.

When additional reference investigation is necessary, record the observed behavior in the reference documentation before implementing it.
