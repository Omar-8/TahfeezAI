"""Does the teacher's own ghunnah output (its `ghonna` level: maghnoon / not
maghnoon per sound) tell a ghunnah held from one missed? On QDAT's expert labels for
the ghunnah of «إِنَّكَ» (5:109 words 7-14, held-out speakers: the qdath pack).

  python ghunnah_teacher_probe.py [--limit N] [--teacher teachers/teacher_ft5.pt] [--show 1]

Per clip: the probability the teacher gives "maghnoon" on the doubled noon's sound;
then how well that separates the experts' applied from missed.
"""
import argparse, json, os

import numpy as np
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--limit', type=int, default=0)
    p.add_argument('--teacher', default='')
    p.add_argument('--show', type=int, default=0)
    a = p.parse_args()
    from quran_muaalem import Muaalem
    from quran_transcript import Aya, quran_phonetizer, MoshafAttributes
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device='cpu', dtype=torch.float32)
    if a.teacher:
        m.model.load_state_dict(torch.load(os.path.join(HERE, a.teacher), map_location='cpu'))
    moshaf = MoshafAttributes(rewaya='hafs', madd_monfasel_len=4, madd_mottasel_len=4,
                              madd_mottasel_waqf=4, madd_aared_len=4)
    ref = quran_phonetizer(Aya(5, 109).get_by_imlaey_words(7, 8).uthmani, moshaf, remove_spaces=True)
    if a.show:
        print('reference sounds:', [(s.phonemes, s.ghonna) for s in ref.sifat])
    cases = json.load(open(os.path.join(ART, 'qdath_cases.json')))
    audio = np.load(os.path.join(ART, 'qdath_audio.npz'))
    labels = json.load(open(os.path.join(ART, 'qdat_labels.json')))
    # The doubled noon of «إِنَّكَ»: the reference's first sound group made of noons
    # after «لَنَآ» — found by position in the reference.
    groups = [s.phonemes for s in ref.sifat]
    k = next(i for i, g in enumerate(groups) if 'ن' in g and i > 0 and 'ء' in groups[i - 1])
    rows, counts = [], []
    for i, c in enumerate(cases):
        lab = labels.get(c['name'], {}).get('the_tight_noon')
        if lab is None:
            continue
        out = m([audio[f'c{i}']], [ref], sampling_rate=16000)[0]
        sifat = out.sifat
        # the sound the teacher heard at that reference position (aligned by the decoder)
        hit = [s for s in sifat if s.phonemes_group and 'ن' in s.phonemes_group]
        # its decode keeps the reference's groups where it can: take the same index if present
        s = sifat[k] if k < len(sifat) and 'ن' in (sifat[k].phonemes_group or '') else (hit[1] if len(hit) > 1 else None)
        if s is None or s.ghonna is None:
            continue
        pg = s.ghonna.prob if s.ghonna.text == 'maghnoon' else 1 - s.ghonna.prob
        rows.append((lab >= 1, pg, s.phonemes_group))
        counts.append((lab >= 1, s.phonemes_group.count('ن')))
        if a.show and len(rows) <= a.show:
            print(c['name'], 'applied' if lab >= 1 else 'missed', [(x.phonemes_group, x.ghonna.text if x.ghonna else None,
                   round(x.ghonna.prob, 2) if x.ghonna else None) for x in sifat])
        if a.limit and len(rows) >= a.limit:
            break
    ok = [p for ap, p, _ in rows if ap]
    miss = [p for ap, p, _ in rows if not ap]
    auc = np.mean([[1.0 if b > x else 0.5 if b == x else 0.0 for b in ok] for x in miss]) if ok and miss else float('nan')
    print(f'clips: applied {len(ok)}, missed {len(miss)}; P(maghnoon) median applied '
          f'{np.median(ok):.2f}, missed {np.median(miss) if miss else float("nan"):.2f}; AUC {auc:.2f}')
    import collections
    for applied in (True, False):
        print('noons heard,', 'applied' if applied else 'missed', dict(sorted(collections.Counter(n for ap, n in counts if ap == applied).items())))
    for t in (0.5, 0.7, 0.9):
        print(f'  maghnoon below {t}: missed caught {np.mean([x < t for x in miss]) * 100:.1f}%, '
              f'applied flagged {np.mean([x < t for x in ok]) * 100:.1f}%')


if __name__ == '__main__':
    main()
