"""How many noons / meems a teacher's own decoding hears on a ghunnah: per (clip,
word) target, the decoded sound groups aligned to the expected ones (the package's
multilevel decode), and the letter count in the group(s) of the target word's doubled
noon / meem. The original Muaalem writes a held ghunnah «إِنَّ» as «ننننَ» (4).

  python ghunnah_decode_probe.py <pack> <targets.json> <out.json> [--teacher PATH]
targets.json: [{"key", "clip", "ayahId", "word"}...]; out: key -> {expected, heard}.
"""
import argparse, json, os

import numpy as np
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('pack'); p.add_argument('targets'); p.add_argument('out')
    p.add_argument('--teacher', default='')
    a = p.parse_args()
    from quran_muaalem import Muaalem
    from quran_transcript import Aya, quran_phonetizer, MoshafAttributes
    dev = 'cuda' if torch.cuda.is_available() else 'cpu'
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device=dev, dtype=torch.float32)
    if a.teacher:
        m.model.load_state_dict(torch.load(a.teacher, map_location='cpu'))
        m.model.to(dev)
    moshaf = MoshafAttributes(rewaya='hafs', madd_monfasel_len=4, madd_mottasel_len=4,
                              madd_mottasel_waqf=4, madd_aared_len=4)
    audio = np.load(os.path.join(ART, f'{a.pack}_audio.npz'))
    out = {}
    for t in json.load(open(a.targets)):
        s, v = t['ayahId'] // 1000, t['ayahId'] % 1000
        aya = Aya(s, v)
        n = len(aya.get().uthmani.split())
        ref = quran_phonetizer(aya.get_by_imlaey_words(0, n).uthmani, moshaf, remove_spaces=True)
        # The target word's groups: phonetize the words before it, then through it.
        before = len(quran_phonetizer(aya.get_by_imlaey_words(0, t['word']).uthmani, moshaf,
                                      remove_spaces=True).sifat) if t['word'] else 0
        upto = len(quran_phonetizer(aya.get_by_imlaey_words(0, t['word'] + 1).uthmani, moshaf,
                                    remove_spaces=True).sifat)
        x = audio[f"c{t['clip']}"].astype(np.float32)
        if np.abs(x).max() > 2:
            x = x / 32767
        res = m([x], [ref], sampling_rate=16000)[0]
        exp_groups = [g.phonemes for g in ref.sifat[before:upto]]
        got = [g.phonemes_group for g in res.sifat[before:upto]] if len(res.sifat) >= upto else None
        def nasal(gs):
            # the longest run of one nasal letter in a group: the doubled noon / meem
            best = 0
            for g in gs or []:
                for ch in 'نم':
                    best = max(best, g.count(ch))
            return best
        out[t['key']] = {'expected': nasal(exp_groups), 'heard': nasal(got) if got is not None else None,
                         'expGroups': exp_groups, 'gotGroups': got,
                         'allExp': [g.phonemes for g in ref.sifat],
                         'allGot': [g.phonemes_group for g in res.sifat]}
        print(t['key'], out[t['key']]['expected'], out[t['key']]['heard'], got, flush=True)
    json.dump(out, open(a.out, 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
