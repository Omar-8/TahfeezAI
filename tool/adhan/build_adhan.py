"""The adhan sounds for prayer-time notifications (owner, 2026-11-21), from
Wikimedia Commons and the Internet Archive (licences and authors in
docs/THIRD_PARTY_RESOURCES.md and the About credits).

    python3 tool/adhan/build_adhan.py <folder with the downloaded files>

Each recording, silence trimmed and loudness evened (−16 LUFS), becomes:
- android/app/src/main/res/raw/adhan_<id>.ogg — the whole adhan, the
  notification channel's sound;
- assets/adhan/<id>.caf — its first 30 s (iOS plays no longer), copied to
  Library/Sounds on an iPhone at run time;
- assets/adhan/<id>.mp3 — the same 30 s, heard in the app before choosing.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'android/app/src/main/res/raw'
ASSETS = ROOT / 'assets/adhan'

# id → its file (downloaded under that name in the folder).
SOURCES = {
    # Internet Archive (owner, 2026-11-22: "proper high quality"): known
    # muezzins, marked public domain by their uploaders — not the rights
    # holders; shipped credited, removed if a rights holder asks.
    'mulla': 'archive-mulla.mp3',        # Ali Mulla, Al-Masjid al-Haram
    'surayhi': 'archive-surayhi.mp3',    # Abdul Majeed Al-Surayhi, Quba
    'harak': 'archive-harak.mp3',        # Abdulnasser Harak, Egypt
    'aqsa': 'archive-aqsa.mp3',          # Naji Qazzaz, Al-Aqsa
    # Wikimedia Commons, free licences.
    'madinah': '33937 ejaz215 call-to-prayer-from-the-prophet-s-mo.ogg',
    'azeez': 'The Adhan - Muslim Call to Prayer - Aaqib Azeez.mp3',
    'andrewler': 'Azan.ogg',
    'synagda': 'Beautiful adhan.ogg',
    'ayodele': 'Call to prayer.ogg',
}

CLIP = 30  # seconds: an iPhone's limit for a notification sound.

TRIM = ('silenceremove=start_periods=1:start_threshold=-45dB:'
        'start_silence=0.2,areverse,silenceremove=start_periods=1:'
        'start_threshold=-45dB:start_silence=0.4,areverse')
LOUD = 'loudnorm=I=-16:TP=-1.5:LRA=11'


def run(*args):
    # (-vn: no cover art carried over from an MP3's tags.)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', *args[:2], '-vn', *args[2:]],
                   check=True)


def main(src: Path):
    RAW.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    for id_, name in SOURCES.items():
        f = src / name
        clip = (f'{TRIM},{LOUD},atrim=0:{CLIP},'
                f'afade=t=out:st={CLIP - 2.5}:d=2.5')
        # (22 kHz mono: a voice, small — the app's download size.)
        run('-i', str(f), '-af', f'{TRIM},{LOUD},aresample=22050', '-ac', '1',
            '-c:a', 'libvorbis', '-q:a', '0', '-map_metadata', '-1',
            str(RAW / f'adhan_{id_}.ogg'))
        run('-i', str(f), '-af', f'{clip},aresample=16000', '-ac', '1',
            '-c:a', 'adpcm_ima_qt', '-f', 'caf', str(ASSETS / f'{id_}.caf'))
        run('-i', str(f), '-af', f'{clip},aresample=44100', '-ac', '1',
            '-c:a', 'libmp3lame', '-b:a', '32k', '-map_metadata', '-1',
            str(ASSETS / f'{id_}.mp3'))
        print(id_, *(p.stat().st_size // 1024 for p in (
            RAW / f'adhan_{id_}.ogg', ASSETS / f'{id_}.caf',
            ASSETS / f'{id_}.mp3')), 'KB')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
