"""Spliced real-voice mistakes for training (option A): a reciter's own recording of a
word that differs from the expected word by one sound (a vowel, a consonant, a
shadda, a sukun, a dropped vowel: calibration_pairs.edits) is put in place of the
expected word in another of that reciter's ayahs. The clip's CTC target is what is
now said, so a model trained on it learns to hear the mistake rather than the text.
Every spliced clip comes with its unspliced control (target: the expected sounds).

  python splice_train_data.py <out dir> [--pairs-per-reciter 300] [--part K --parts N]

Reciters: everyayah.com, none of the calibration or test reciters (Shuraym, Ghamdi,
Shaatree, Maher, Alafasy, Husary, Mansoori, Parhizgar). Ayahs: none in
blocked_ayahs.json (the final test's and the calibration's), as context or source.
Writes shard_70NN.npz (distill_student.py's format, with targets), held/shard_79NN.npz (two
held-out reciters, for validation) and splice_meta_K.json.
"""
import argparse, collections, json, os, random, subprocess, tempfile, urllib.request
from concurrent.futures import ThreadPoolExecutor
import numpy as np

import distill_student as ds
from build_calibration import align, cut_points, splice
from calibration_pairs import edits, words_of
from diverse_data import teacher_frames

HERE = os.path.dirname(os.path.abspath(__file__))
RECITERS = ['Abdul_Basit_Murattal_192kbps', 'Abdullah_Basfar_192kbps', 'Abdurrahmaan_As-Sudais_192kbps',
            'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net', 'Hani_Rifai_192kbps', 'Hudhaify_128kbps',
            'Ibrahim_Akhdar_64kbps', 'Minshawy_Murattal_128kbps', 'Mohammad_al_Tablaway_128kbps',
            'Muhammad_Ayyoub_128kbps', 'Muhammad_Jibreel_128kbps', 'Mustafa_Ismail_48kbps',
            'Salaah_AbdulRahman_Bukhatir_128kbps', 'Muhsin_Al_Qasim_192kbps',
            'Abdullaah_3awwaad_Al-Juhaynee_128kbps', 'Salah_Al_Budair_128kbps', 'Abdullah_Matroud_128kbps',
            'Ahmed_Neana_128kbps', 'Muhammad_AbdulKareem_128kbps', 'khalefa_al_tunaiji_64kbps',
            'Khaalid_Abdullaah_al-Qahtaanee_192kbps', 'Yasser_Ad-Dussary_128kbps', 'Nasser_Alqatami_128kbps',
            'Ali_Hajjaj_AlSuesy_128kbps', 'Sahl_Yassin_128kbps', 'aziz_alili_128kbps', 'Yaser_Salamah_128kbps',
            'Akram_AlAlaqimy_128kbps', 'Ali_Jaber_64kbps', 'Fares_Abbad_64kbps', 'Ayman_Sowaid_64kbps']
HELD_OUT = {'Fares_Abbad_64kbps', 'Ali_Jaber_64kbps'}   # validation reciters: <out>/held/shard_79NN
CATEGORIES = ['vowel_DAMMA_FATHA', 'vowel_DAMMA_KASRA', 'vowel_FATHA_KASRA', 'consonant',
              'shadda_missing', 'shadda_extra', 'sukun', 'missing_vowel']
MAX_COST = 0.6
MARKS = 'ڇۜ'   # qalqala, sakt: in the transcripts, not in calibration_pairs.words_of


def fetch(folder, aid):
    url = f'https://everyayah.com/data/{folder}/{aid // 1000:03d}{aid % 1000:03d}.mp3'
    with tempfile.NamedTemporaryFile(suffix='.mp3') as f:
        urllib.request.urlretrieve(url, f.name)
        pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f.name, '-ar', '16000', '-ac', '1',
                              '-f', 's16le', '-'], check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2').astype(np.float32) / 32767


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--pairs-per-reciter', type=int, default=300)
    p.add_argument('--part', type=int, default=0)
    p.add_argument('--parts', type=int, default=1)
    p.add_argument('--shard-clips', type=int, default=2000)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ref = json.load(open(os.path.join(HERE, 'phonetic_reference_hafs.json')))['ayahs']
    blocked = {s * 1000 + o for s, o in json.load(open(os.path.join(HERE, 'blocked_ayahs.json')))}
    # ---- interior words of short ayahs, and their one-sound minimal pairs
    pool, nwords = collections.defaultdict(list), {}
    for key, row in ref.items():
        aid = int(key)
        if aid in blocked:
            continue
        ws = words_of(row)
        nwords[aid] = max(ws) + 1
        if nwords[aid] > 25:
            continue
        for w, snd in ws.items():
            if 0 < w < nwords[aid] - 1:
                pool[snd].append((aid, w))
    by_cat = collections.defaultdict(list)
    for snd in pool:
        for cat, r in edits(snd):
            if r in pool:
                by_cat[cat].append((snd, r))
    print({c: len(v) for c, v in by_cat.items()}, flush=True)
    t = ds.load_teacher()
    fe = getattr(t.processor, 'feature_extractor', t.processor)
    tokens = lambda aid: [(ds.ID[c], ord(w) - 48, bool((ord(f) - 64) & (8 | 32)))
                          for c, w, f in zip(ref[str(aid)]['t'], ref[str(aid)]['w'], ref[str(aid)]['f'])]
    reciters = RECITERS[a.part::a.parts]
    os.makedirs(os.path.join(a.out, 'held'), exist_ok=True)
    shards = {'train': ([], 7000 + 100 * a.part), 'held': ([], 7900 + 10 * a.part)}
    where = {'train': a.out, 'held': os.path.join(a.out, 'held')}
    counts = {'train': 0, 'held': 0}
    meta, stats = [], collections.Counter()

    def flush(kind, force=False):
        clips, base = shards[kind]
        while len(clips) >= a.shard_clips or (force and clips):
            part, rest = clips[:a.shard_clips], clips[a.shard_clips:]
            np.savez(os.path.join(where[kind], f'shard_{base + counts[kind]:04d}.npz'),
                     audio=np.concatenate([x for x, _, _ in part]).astype(np.int16),
                     offsets=np.cumsum([0] + [len(x) for x, _, _ in part]),
                     targets=np.array([tg for _, tg, _ in part] + [None], dtype=object)[:-1],
                     ayahs=np.array([aid for _, _, aid in part], np.int32))
            counts[kind] += 1
            clips[:] = rest

    for folder in reciters:
        kind = 'held' if folder in HELD_OUT else 'train'
        rng = random.Random(folder)
        cache = {}
        # The candidate pairs, drawn up front so their recordings download in
        # parallel (one at a time, the build waits on everyayah, not the GPU).
        cands = []
        for k in range(a.pairs_per_reciter * 4):
            cat = CATEGORIES[k % len(CATEGORIES)]
            e, r = rng.choice(by_cat[cat])
            cands.append((cat, e, r, rng.choice(pool[e]), rng.choice(pool[r])))
        pool_x = ThreadPoolExecutor(16)
        audio = {}
        for _, _, _, (x, _), (y, _) in cands:
            for aid in (x, y):
                if aid not in audio:
                    audio[aid] = pool_x.submit(fetch, folder, aid)

        def get(aid):
            if aid not in cache:
                try:
                    w = audio[aid].result()
                    lp = teacher_frames(t, fe, w).cpu().numpy()
                    spans, cost = align(lp, tokens(aid))
                    cache[aid] = (w, cut_points(spans, nwords[aid], len(w)), cost)
                except Exception:
                    cache[aid] = None
            return cache[aid]

        made, controls, used = collections.Counter(), set(), collections.Counter()
        for cat, e, r, (ctx_aid, ctx_w), (src_aid, src_w) in cands:
            if sum(made.values()) >= a.pairs_per_reciter:
                break
            if used[(e, r)] >= 2:            # rare categories: no word pair learnt by heart
                continue
            if src_aid == ctx_aid:
                continue
            c, s = get(ctx_aid), get(src_aid)
            if c is None or s is None:
                stats['download failed'] += 1; continue
            (cw, cpos, ccost), (sw, spos, scost) = c, s
            if ccost > MAX_COST or scost > MAX_COST or ctx_w not in cpos or src_w not in spos:
                stats['poor alignment'] += 1; continue
            spliced = splice(cw, cpos[ctx_w], sw, spos[src_w])
            if not 1 <= len(spliced) / 16000 <= 20:
                stats['length'] += 1; continue
            # The targets in the training transcripts' format (ds.spoken): the
            # source word's own sounds, lengths and marks, in the context's place.
            expected = ds.sounds_of(ref[str(ctx_aid)])
            swapped = [x for x in ds.sounds_of(ref[str(src_aid)]) if x[2] == src_w]
            said = []
            for k, x in enumerate(expected):
                if x[2] == ctx_w:
                    if k == 0 or expected[k - 1][2] != ctx_w:
                        said += swapped
                    continue
                said.append(x)
            if (''.join(c for c, _, w in expected if w == ctx_w and c not in MARKS) != e
                    or ''.join(c for c, _, _ in swapped if c not in MARKS) != r):
                stats['word sounds differ in context'] += 1; continue
            clips = shards[kind][0]
            clips.append(((np.clip(spliced, -1, 1) * 32767).astype(np.int16), ds.spoken(said), ctx_aid))
            if ctx_aid not in controls:
                controls.add(ctx_aid)
                clips.append(((np.clip(cw, -1, 1) * 32767).astype(np.int16),
                              ds.spoken(expected), ctx_aid))
            meta.append(dict(reciter=folder, category=cat, ayahId=ctx_aid, word=ctx_w, expected=e,
                             recited=r, srcAyahId=src_aid, srcWord=src_w, held=kind == 'held'))
            made[cat] += 1
            used[(e, r)] += 1
            flush(kind)
        for f in audio.values():
            f.cancel()
        pool_x.shutdown(wait=False, cancel_futures=True)
        stats.update({f'made {k}': v for k, v in made.items()})
        print(folder, kind, dict(made), f'{len(cache)} ayahs', flush=True)
    flush('train', True); flush('held', True)
    json.dump(dict(stats=stats, pairs=meta), open(os.path.join(a.out, f'splice_meta_{a.part}.json'), 'w'),
              ensure_ascii=False, indent=0)
    print('done', a.part, dict(stats), flush=True)


if __name__ == '__main__':
    main()
