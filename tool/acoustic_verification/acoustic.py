"""Quran acoustic verification prototype.

reference(sura, aya)        expected CTC tokens with word / Uthmani-char mapping
align(logp, tokens)         CTC Viterbi forced alignment (optional tokens allowed)
verify(logp, tokens, al)    per-token verdicts from local CTC likelihood ratios
"""
import json, math
from dataclasses import dataclass, field
import numpy as np
from quran_transcript import Aya, quran_phonetizer, MoshafAttributes
from quran_transcript.phonetics.search import get_phonetic_to_char_uthmani

VOCAB = ['', 'ء', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض',
         'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي', 'ا', 'ۦ', 'ۥ',
         'َ', 'ُ', 'ِ', '۪', 'ـ', 'ٲ', 'ڇ', 'ں', '۾', 'ۜ', 'ؙ']
ID = {c: i for i, c in enumerate(VOCAB) if c}
BLANK = 0
SHORT = [ID['َ'], ID['ُ'], ID['ِ']]
VOWEL_NAME = {ID['َ']: 'FATHA', ID['ُ']: 'DAMMA', ID['ِ']: 'KASRA'}
LONG = {ID[c] for c in 'اۥۦـ'} | {ID['ں'], ID['۾']}          # lengths not judged
MARKERS = {ID['ڇ'], ID['ۜ']}                                 # qalqala, sakt: optional
VOWELISH = set(SHORT) | LONG | {ID['۪'], ID['ؙ']}
CONSONANTS = [ID[c] for c in 'ءبتثجحخدذرزسشصضطظعغفقكلمنهوي']
TANWEEN = set('ًٌٍ') | {'ࣰ', 'ࣱ', 'ࣲ'}
MOSHAF = MoshafAttributes(rewaya="hafs", madd_monfasel_len=4, madd_mottasel_len=4,
                          madd_mottasel_waqf=4, madd_aared_len=2)
FRAME_S = 0.04


def has_letter(t):
    return any("ء" <= c <= "ي" or c == "ٱ" for c in t)


@dataclass
class Token:
    label: int
    unit: int              # sound unit (phonetizer word group)
    word: int              # Tahfeez word index within the ayah
    uth_char: str          # the Uthmani character it comes from
    letter: int            # ordinal of the base letter within its word
    kind: str              # vowel | long | consonant | marker
    geminate: bool = False  # second copy of a doubled (shadda) consonant
    optional: bool = False
    unit_final_vowel: bool = False
    wasl_hamza: bool = False  # optional hamzat-wasl onset after a pause
    count: int = 1          # the phonetizer's repeat count: a madd's or a
                            # ghunnah's length in harakat (on the long / the
                            # geminate token)

    @property
    def sym(self):
        return VOCAB[self.label]


def reference(uthmani: str) -> list[Token]:
    out = quran_phonetizer(uthmani, MOSHAF, remove_spaces=False)
    ph = out.phonemes
    ph2uth = get_phonetic_to_char_uthmani(out.mappings)
    # Uthmani char -> Tahfeez word (letter tokens only) and base-letter ordinal
    word_of, letter_of = [], []
    word, letter, in_letters = -1, -1, False
    for tok_i, tok in enumerate(uthmani.split(' ')):
        is_word = has_letter(tok)
        if is_word:
            word += 1
            letter = -1
        for c in tok:
            if ("ء" <= c <= "ي" or c in "ٱٰ") and c != "ـ":
                letter += 1
            word_of.append(word if is_word else max(word, 0))
            letter_of.append(max(letter, 0))
        word_of.append(-1)
        letter_of.append(-1)  # the space
    tokens: list[Token] = []
    unit = 0
    i = 0
    while i < len(ph):
        c = ph[i]
        if c == ' ':
            unit += 1
            i += 1
            continue
        j = i
        while j < len(ph) and ph[j] == c:
            j += 1
        u = ph2uth.get(i, len(uthmani) - 1)
        u = min(u, len(uthmani) - 1)
        w = word_of[u] if word_of[u] >= 0 else word_of[max(0, u - 1)]
        base = dict(unit=unit, word=w, uth_char=uthmani[u], letter=letter_of[u])
        lab = ID[c]
        if lab in MARKERS:
            tokens.append(Token(lab, kind='marker', optional=True, **base))
        elif lab in VOWELISH:
            tokens.append(Token(lab, kind='vowel' if lab in SHORT else 'long',
                                count=j - i, **base))
        else:
            tokens.append(Token(lab, kind='consonant', **base))
            if j - i >= 2:  # shadda / geminate (its count: the ghunnah's length)
                tokens.append(Token(lab, kind='consonant', geminate=True, count=j - i, **base))
        i = j
    # unit-final short vowels: dropped at a pause (waqf)
    for k, t in enumerate(tokens):
        last = k + 1 == len(tokens) or tokens[k + 1].unit != t.unit
        if t.kind == 'vowel' and last:
            t.unit_final_vowel = True
    return tokens


# ---------------------------------------------------------------- alignment

# Sounds whose length varies (madd ا ۦ ۥ, ghunnah ں): the model spells a
# long one as the symbol repeated with blanks between; one expected token may
# take the symbol again after a blank (as lib/ai/acoustic/ctc.dart).
STRETCH = True


def _stretchable(label):
    return STRETCH and label in {ID['ا'], ID['ۦ'], ID['ۥ'], ID['ں']}


def _states(tokens):
    """CTC states: blank, tok0, blank, tok1, ..., blank."""
    labels = []
    for t in tokens:
        labels += [BLANK, t.label]
    labels.append(BLANK)
    return labels


def align(logp: np.ndarray, tokens: list[Token], optional_mask=None):
    """Viterbi over the CTC graph. Tokens with optional_mask[k] may be
    skipped. Returns per-token (start_frame, end_frame) or None if skipped,
    and the path score."""
    T = len(logp)
    labels = _states(tokens)
    S = len(labels)
    opt = optional_mask if optional_mask is not None else [t.optional for t in tokens]
    NEG = -1e30
    # predecessors of each state
    preds = [[] for _ in range(S)]
    for s in range(S):
        preds[s].append(s)
        if s >= 1:
            preds[s].append(s - 1)
        if s >= 2 and labels[s] != BLANK and labels[s] != labels[s - 2]:
            preds[s].append(s - 2)
    # a stretchable token, after the blank that follows it, again
    for s in range(1, S - 1, 2):
        if _stretchable(labels[s]):
            preds[s].append(s + 1)
    # skipping optional token k (state 2k+1): its surroundings connect
    for k, o in enumerate(opt):
        if not o:
            continue
        s = 2 * k + 1
        # blank before -> blank after
        preds[s + 1].append(s - 1)
        # previous token -> blank after ; blank before / prev token -> next token
        if s - 2 >= 0:
            preds[s + 1].append(s - 2)
        if s + 2 < S:
            preds[s + 2].append(s - 1)
            if s - 2 >= 0 and labels[s + 2] != labels[s - 2]:
                preds[s + 2].append(s - 2)
    # chained optional skips are rare; ignore
    dp = np.full(S, NEG)
    dp[0] = logp[0, labels[0]]
    dp[1] = logp[0, labels[1]]
    if opt and opt[0] and S > 3:
        dp[2] = logp[0, BLANK]
        dp[3] = logp[0, labels[3]]
    back = np.zeros((T, S), dtype=np.int32)
    lab = np.array(labels)
    for t in range(1, T):
        new = np.full(S, NEG)
        emit = logp[t, lab]
        for s in range(S):
            best, arg = NEG, s
            for p in preds[s]:
                if dp[p] > best:
                    best, arg = dp[p], p
            new[s] = best + emit[s]
            back[t, s] = arg
        dp = new
    end = S - 1 if dp[S - 1] >= dp[S - 2] else S - 2
    if opt and opt[-1] and dp[S - 3] > dp[end]:
        end = S - 3
    score = dp[end]
    path = [end]
    for t in range(T - 1, 0, -1):
        path.append(back[t, path[-1]])
    path.reverse()
    spans = [None] * len(tokens)
    for t, s in enumerate(path):
        if s % 2 == 1:
            k = s // 2
            if spans[k] is None:
                spans[k] = [t, t]
            else:
                spans[k][1] = t
    return spans, score, path


# ------------------------------------------------------ local CTC likelihood

def ctc_logprob(logp: np.ndarray, labels: list[int]) -> float:
    """log P(labels | frames) with the CTC forward algorithm (all paths)."""
    ext = [BLANK]
    for l in labels:
        ext += [l, BLANK]
    S, T = len(ext), len(logp)
    if T == 0:
        return -1e30
    NEG = -1e30
    a = np.full(S, NEG)
    a[0] = logp[0, BLANK]
    if S > 1:
        a[1] = logp[0, ext[1]]
    ext_a = np.array(ext)
    skip = np.zeros(S, bool)
    for s in range(2, S):
        skip[s] = ext[s] != BLANK and ext[s] != ext[s - 2]
    back = np.array([s % 2 == 1 and s + 1 < S and _stretchable(ext[s]) for s in range(S)])
    for t in range(1, T):
        prev1 = np.concatenate([[NEG], a[:-1]])
        prev2 = np.concatenate([[NEG, NEG], a[:-2]])
        prev2 = np.where(skip, prev2, NEG)
        nxt = np.where(back, np.concatenate([a[1:], [NEG]]), NEG)
        a = np.logaddexp(np.logaddexp(np.logaddexp(a, prev1), prev2), nxt) + logp[t, ext_a]
    return float(np.logaddexp(a[-1], a[-2]) if S > 1 else a[-1])


# ------------------------------------------------------------- verification

@dataclass
class Verdict:
    k: int
    token: Token
    kind: str               # CORRECT, WRONG_LETTER, WRONG_VOWEL, MISSING_VOWEL,
                            # SUKUN_ERROR, SHADDA_ERROR, UNCERTAIN, PAUSE, SKIPPED
    span: tuple | None
    confidence: float       # mean posterior of the expected symbol over its frames
    competitor: str = ''
    llr: float = 0.0        # best alternative minus expected (log-likelihood)
    observed: str = ''


@dataclass
class Thresholds:
    error: float = 2.0       # alternative must win by this much (nats)
    letter_error: float = 2.0  # ... for a wrong letter
    correct: float = 1.0     # expected must win by this much to be CORRECT
    pause_frames: int = 6    # blank run after a unit counting as a pause (240 ms)
    context: int = 2         # neighbouring tokens in the local window
    tajweed: bool = True     # judge tajweed (as the Dart AcousticThresholds)
    qalqala_error: float = 3.0  # a qalqala echo missing: margin of "without"


def _window(tokens, spans, k, ctx, T):
    """Frame range and token range around token k for local rescoring."""
    lo, hi = k, k
    got = 0
    while lo > 0 and got < ctx:
        lo -= 1
        if spans[lo] is not None:
            got += 1
    got = 0
    while hi < len(tokens) - 1 and got < ctx:
        hi += 1
        if spans[hi] is not None:
            got += 1
    first = next((spans[i][0] for i in range(lo, hi + 1) if spans[i]), 0)
    last = next((spans[i][1] for i in range(hi, lo - 1, -1) if spans[i]), T - 1)
    # include the blanks just around the window
    f0 = first
    f1 = last
    prev_end = next((spans[i][1] for i in range(lo - 1, -1, -1) if spans[i]), -1)
    next_start = next((spans[i][0] for i in range(hi + 1, len(tokens)) if spans[i]), T)
    f0 = max(prev_end + 1, first - 3)
    f1 = min(next_start - 1, last + 3)
    return lo, hi, f0, f1


def _plain_of_hidden(t):
    """The plain letter a hidden nasal is said as without its rule (as the
    Dart verifier's _plainOfHidden): ں as ن; ۾ as م where it hides a mīm,
    else as ن (iqlāb)."""
    if t.label == ID['ں']:
        return ID['ن']
    if t.label == ID['۾']:
        return ID['م'] if t.uth_char == 'م' else ID['ن']
    return None


def _alternatives(tokens, spans, k):
    """(kind, observed, replacement label list for token k) alternatives."""
    t = tokens[k]
    out = []
    plain = _plain_of_hidden(t) if t.kind == 'long' else None
    if plain is not None:
        return [('WRONG_LETTER', VOCAB[plain], [plain])]
    if t.kind == 'vowel' and t.label in SHORT:
        for v in SHORT:
            if v != t.label:
                out.append(('WRONG_VOWEL', VOWEL_NAME[v], [v]))
        out.append(('MISSING_VOWEL', 'SUKUN', []))
    elif t.kind == 'consonant':
        if t.geminate:
            out.append(('SHADDA_ERROR', 'NO_SHADDA', []))
        else:
            for c in CONSONANTS:
                if c != t.label:
                    out.append(('WRONG_LETTER', VOCAB[c], [c]))
            nxt = tokens[k + 1] if k + 1 < len(tokens) else None
            follows_vowel = nxt is not None and nxt.kind in ('vowel', 'long') and nxt.unit == t.unit
            doubled = nxt is not None and nxt.geminate
            if not follows_vowel and not doubled:
                # sakin consonant: a vowel inserted after it
                for v in SHORT:
                    out.append(('SUKUN_ERROR', VOWEL_NAME[v], [t.label, v]))
            if not doubled and follows_vowel:
                out.append(('SHADDA_ERROR', 'EXTRA_SHADDA', [t.label, t.label]))
    return out


MADD_SHORT_SHARE = 0.65  # a 4- or 6-count madd held for less than this share


def _beat(tokens, spans):
    """The reciter's beat (one haraka, frames): half the median length of
    the two-count madds aligned that a vowel follows in their unit (one
    before a stop is often held longer); None with fewer than two (as the
    Dart verifier's _beat)."""
    def before_vowel(k):  # a short vowel follows in its unit (not before a stop)
        return any(u.kind == 'vowel' for u in tokens[k + 1:] if u.unit == tokens[k].unit)
    halves = sorted((spans[k][1] - spans[k][0] + 1) / 2 for k, t in enumerate(tokens)
                    if t.kind == 'long' and t.count == 2 and _plain_of_hidden(t) is None
                    and spans[k] is not None and before_vowel(k))
    if len(halves) < 2:
        return None
    mid = len(halves) // 2
    return halves[mid] if len(halves) % 2 else (halves[mid - 1] + halves[mid]) / 2


def verify(logp, tokens, spans, th: Thresholds = Thresholds()):
    T = len(logp)
    post = np.exp(logp)
    verdicts = []
    beat = _beat(tokens, spans) if th.tajweed else None
    for k, t in enumerate(tokens):
        sp = spans[k]
        if (beat is not None and sp is not None and t.kind == 'long' and t.count >= 4
                and _plain_of_hidden(t) is None):
            beats = (sp[1] - sp[0] + 1) / beat
            if beats < MADD_SHORT_SHARE * t.count:
                verdicts.append(Verdict(k, t, 'MADD_SHORT', tuple(sp), 0.0, '', beats, str(round(beats))))
                continue
        if th.tajweed and t.optional and t.label == ID['ڇ']:
            # a qalqala letter's echo: said with it, or clearly without
            lo, hi, f0, f1 = _window(tokens, spans, k, th.context, T)
            before = [tokens[i].label for i in range(lo, k) if spans[i] is not None]
            after = [tokens[i].label for i in range(k + 1, hi + 1) if spans[i] is not None]
            seg_lp = logp[f0:f1 + 1]
            llr = ctc_logprob(seg_lp, before + after) - ctc_logprob(seg_lp, before + [t.label] + after)
            missing = llr >= th.qalqala_error
            verdicts.append(Verdict(k, t, 'QALQALA_MISSING' if missing else 'CORRECT',
                                    tuple(sp) if sp else None, 0.0, '', llr,
                                    'NO_QALQALA' if missing else ''))
            continue
        if sp is None:
            if not t.unit_final_vowel:
                verdicts.append(Verdict(k, t, 'SKIPPED', None, 0.0))
                continue
            # Dropped at a pause - unless a different vowel was said there.
            lo, hi, f0, f1 = _window(tokens, spans, k, th.context, T)
            before = [tokens[i].label for i in range(lo, k) if spans[i] is not None]
            after = [tokens[i].label for i in range(k + 1, hi + 1) if spans[i] is not None]
            seg_lp = logp[f0:f1 + 1]
            ok = max(ctc_logprob(seg_lp, before + after),
                     ctc_logprob(seg_lp, before + [t.label] + after))
            best, obs = -1e30, ''
            for v in SHORT:
                if v != t.label:
                    s_ = ctc_logprob(seg_lp, before + [v] + after)
                    if s_ > best:
                        best, obs = s_, VOWEL_NAME[v]
            llr = best - ok
            kind = 'WRONG_VOWEL' if llr >= th.error else 'PAUSE' if llr <= -th.correct else 'UNCERTAIN'
            verdicts.append(Verdict(k, t, kind, None, 0.0, '', llr, obs))
            continue
        conf = float(post[sp[0]:sp[1] + 1, t.label].mean())
        seg = post[sp[0]:sp[1] + 1].copy()
        seg[:, t.label] = 0
        seg[:, BLANK] = 0
        comp = VOCAB[int(seg.mean(0).argmax())]
        hidden = t.kind == 'long' and _plain_of_hidden(t) is not None
        if (t.kind in ('long', 'marker') and not hidden) or t.label not in SHORT and t.kind == 'vowel':
            verdicts.append(Verdict(k, t, 'CORRECT', tuple(sp), conf, comp))
            continue
        lo, hi, f0, f1 = _window(tokens, spans, k, th.context, T)
        window_labels = [tokens[i].label for i in range(lo, hi + 1) if spans[i] is not None]
        idx = sum(1 for i in range(lo, k) if spans[i] is not None)
        seg_lp = logp[f0:f1 + 1]
        base = ctc_logprob(seg_lp, window_labels)
        best_kind, best_obs, best = None, '', -1e30
        for kind, obs, repl in _alternatives(tokens, spans, k):
            alt = window_labels[:idx] + repl + window_labels[idx + 1:]
            s = ctc_logprob(seg_lp, alt)
            if s > best:
                best, best_kind, best_obs = s, kind, obs
        if best_kind is None:
            verdicts.append(Verdict(k, t, 'CORRECT', tuple(sp), conf, comp))
            continue
        llr = best - base
        if llr >= (th.letter_error if best_kind == 'WRONG_LETTER' else th.error):
            kind = best_kind
        elif llr <= -th.correct:
            kind = 'CORRECT'
        else:
            kind = 'UNCERTAIN'
        verdicts.append(Verdict(k, t, kind, tuple(sp), conf, comp, llr, best_obs))
    return verdicts


def align_with_waqf(logp, tokens, th: Thresholds = Thresholds()):
    """Unit-final vowels may be dropped only at a pause: align with them
    optional; a dropped one not followed by a pause is aligned again as
    required so it gets verified."""
    opt = [t.optional or t.unit_final_vowel for t in tokens]
    spans, score, path = align(logp, tokens, opt)
    redo = False
    for k, t in enumerate(tokens):
        if t.unit_final_vowel and spans[k] is None and k + 1 < len(tokens):
            prev_end = next((spans[i][1] for i in range(k - 1, -1, -1) if spans[i]), 0)
            next_start = next((spans[i][0] for i in range(k + 1, len(tokens)) if spans[i]), len(logp))
            if next_start - prev_end - 1 < th.pause_frames:
                opt[k] = False
                redo = True
    if redo:
        spans, score, path = align(logp, tokens, opt)
    return spans


def explain(tokens, spans, verdicts, words):
    lines = []
    for v in verdicts:
        t = v.token
        sp = '-' if v.span is None else f"{v.span[0]*FRAME_S:5.2f}-{(v.span[1]+1)*FRAME_S:5.2f}s"
        lines.append(f"w{t.word:<2} {words[t.word] if 0 <= t.word < len(words) else '?':<14} "
                     f"char {t.uth_char!r:5} {t.sym:2} {t.kind:9}{'+sh' if t.geminate else '   '} "
                     f"{sp:13} p={v.confidence:4.2f} rival={v.competitor or '-':2} "
                     f"llr={v.llr:6.2f} {v.kind}{' -> ' + v.observed if v.kind not in ('CORRECT', 'UNCERTAIN', 'PAUSE', 'SKIPPED') else ''}")
    return '\n'.join(lines)


# ------------------------------------------------ pauses: waqf and ibtida

def _letter_tokens(uthmani):
    """Uthmani space-separated tokens, with each word's letter-word index."""
    toks, word = [], -1
    for tok in uthmani.split(' '):
        if has_letter(tok):
            word += 1
        toks.append((tok, word))
    return toks


def unit_splits(uthmani: str, tokens: list[Token]):
    """Per sound unit of several words (joined in flow, e.g. by idgham across
    a word boundary), its pronunciation when the reciter stops inside it,
    after word k: {unit: {k: tokens}} — the words up to k as said at a stop
    (from the phonetizer on the ayah cut after k, so their start keeps its
    context) and the rest as started afresh (on the ayah from word k + 1).
    A split whose parts don't cover exactly the unit's words is left out."""
    parts = _letter_tokens(uthmani)
    units = {}
    for t in tokens:
        units.setdefault(t.unit, []).append(t)
    out = {}
    for u, ts in units.items():
        words = sorted({t.word for t in ts})
        if len(words) < 2:
            continue
        default = [(t.label, t.geminate) for t in ts]
        for k in words[:-1]:
            left_text = ' '.join(tok for tok, w in parts if 0 <= w <= k)
            right_text = ' '.join(tok for tok, w in parts if w > k)
            try:
                left, right = reference(left_text), reference(right_text)
            except Exception:
                continue
            left = [t for t in left if t.unit == left[-1].unit]
            right = [t for t in right if t.unit == 0]
            for t in right:
                t.word += k + 1
            if (sorted({t.word for t in left}) != [w for w in words if w <= k]
                    or sorted({t.word for t in right}) != [w for w in words if w > k]):
                continue
            pick = left + right
            for t in pick:
                t.unit = u
            if [(t.label, t.geminate) for t in pick] != default:
                out.setdefault(u, {})[k] = pick
    return out


def unit_variants(uthmani: str, tokens: list[Token]):
    """Per sound unit, its pronunciation when the reciter stops after it
    (waqf), starts with it (ibtida), or both — from the phonetizer itself,
    on the ayah text cut there. Only variants that differ are returned."""
    parts = _letter_tokens(uthmani)
    units = {}
    for t in tokens:
        units.setdefault(t.unit, []).append(t)
    out = {}
    last_unit = tokens[-1].unit
    for u, ts in units.items():
        w0, w1 = min(t.word for t in ts), max(t.word for t in ts)
        default = [(t.label, t.geminate) for t in ts]
        var = {}
        for kind, lo, hi in (('waqf', 0, w1), ('ibtida', w0, None), ('both', w0, w1)):
            if kind in ('waqf', 'both') and u == last_unit:
                continue  # already the ayah's own waqf form
            if kind in ('ibtida', 'both') and u == 0:
                continue
            text = ' '.join(tok for tok, w in parts
                            if lo <= w and (hi is None or w <= hi) and w >= 0)
            try:
                ref = reference(text)
            except Exception:
                continue
            first_unit = [t for t in ref if t.unit == 0]
            last = [t for t in ref if t.unit == ref[-1].unit]
            pick = {'waqf': last, 'ibtida': first_unit, 'both': ref}[kind]
            if kind == 'both' and len({t.unit for t in ref}) != 1:
                continue
            for t in pick:
                t.word += lo
                t.unit = u
            if [(t.label, t.geminate) for t in pick] != default:
                var[kind] = pick
        if var:
            out[u] = var
    return out


def _unit_spans(tokens, spans):
    first, last = {}, {}
    for k, t in enumerate(tokens):
        if spans[k] is None:
            continue
        first.setdefault(t.unit, spans[k][0])
        last[t.unit] = spans[k][1]
    return first, last


STOP_INSIDE_FRAMES = 8  # a stop inside a unit: 320 ms of silence at least


def _pause_within(logp, f0, f1, th):
    """A run of max(th.pause_frames, STOP_INSIDE_FRAMES) frames in f0+1..f1-1
    where nothing beats the blank (as the Dart verifier's _pauseWithin)."""
    run = 0
    for f in range(f0 + 1, f1):
        run = run + 1 if logp[f].max() <= logp[f, BLANK] else 0
        if run >= max(th.pause_frames, STOP_INSIDE_FRAMES):
            return True
    return False


def verify_ayah(logp, tokens, variants, th: Thresholds = Thresholds(),
                open_start=False, open_end=False, splits=None):
    """Two passes: align, find the reciter's pauses, switch the units around
    each pause to their waqf / ibtida forms, align again and verify.
    Returns (tokens used, spans, verdicts)."""
    T = len(logp)
    spans = align_with_waqf(logp, tokens, th)
    first, last = _unit_spans(tokens, spans)
    units = sorted(first)
    pause_after = set()
    for a, b in zip(units, units[1:]):
        if first[b] - last[a] - 1 >= th.pause_frames:
            pause_after.add(a)
    if units and not open_end:
        pause_after.add(units[-1])
    starts = {b for a, b in zip(units, units[1:]) if a in pause_after}
    if units and not open_start:
        starts.add(units[0])
    chosen, final_vowel = [], {}
    by_unit = {}
    for t in tokens:
        by_unit.setdefault(t.unit, []).append(t)
    order = sorted(by_unit)
    for n, u in enumerate(order):
        split_after = None
        v = variants.get(u, {})
        kind = ('both' if u in starts and u in pause_after else
                'waqf' if u in pause_after else 'ibtida' if u in starts else None)
        ts = v.get(kind) if kind else None
        if ts is None and kind == 'both':
            ts = v.get('waqf') or v.get('ibtida')
        if ts is not None and u in first:
            # Let the audio decide: the unit (with its neighbours) as said
            # in flow versus at the pause.
            prev_u = order[n - 1] if n > 0 else None
            next_u = order[n + 1] if n + 1 < len(order) else None
            f0 = first[prev_u] if prev_u in first else first[u]
            f1 = last[next_u] if next_u in last else last[u]
            f0, f1 = max(0, f0 - 2), min(T - 1, f1 + 2)
            ctx_before = [t.label for t in by_unit.get(prev_u, [])]
            ctx_after = [t.label for t in by_unit.get(next_u, [])]
            seg = logp[f0:f1 + 1]
            flow = ctc_logprob(seg, ctx_before + [t.label for t in by_unit[u]] + ctx_after)
            paused = ctc_logprob(seg, ctx_before + [t.label for t in ts] + ctx_after)
            if paused <= flow:
                ts = None
        # Stopping inside a unit of several words: its split forms, where a
        # pause was heard inside it (unit_splits; as the Dart verifier).
        if splits and u in splits and u in first and _pause_within(logp, first[u], last[u], th):
            prev_u = order[n - 1] if n > 0 else None
            next_u = order[n + 1] if n + 1 < len(order) else None
            f0 = first[prev_u] if prev_u in first else first[u]
            f1 = last[next_u] if next_u in last else last[u]
            f0, f1 = max(0, f0 - 2), min(T - 1, f1 + 2)
            ctx_before = [t.label for t in by_unit.get(prev_u, [])]
            ctx_after = [t.label for t in by_unit.get(next_u, [])]
            seg = logp[f0:f1 + 1]
            score = lambda xs: ctc_logprob(seg, ctx_before + [t.label for t in xs] + ctx_after)
            best = score(ts if ts is not None else by_unit[u])
            for k_, pick in splits[u].items():
                sc = score(pick)
                if sc > best:
                    best, ts, split_after = sc, pick, k_
        if ts is not None:
            if split_after is not None:
                # stopped inside the unit after word k: its last vowel dropped
                of_word = [t for t in by_unit[u] if t.word == split_after]
                if of_word and of_word[-1].kind == 'vowel' and of_word[-1].label in SHORT:
                    final_vowel[u] = (of_word[-1], split_after)
            else:
                fv = [t for t in by_unit[u] if t.unit_final_vowel]
                if u in pause_after and fv:
                    final_vowel[u] = (fv[0], None)
            chosen += [Token(**{**t.__dict__}) for t in ts]
        else:
            chosen += by_unit[u]
    spans = align_with_waqf(logp, chosen, th)
    verdicts = verify(logp, chosen, spans, th)
    # A different vowel said just before a pause is still a mistake.
    for u, (vowel, last_word) in final_vowel.items():
        ks = [k for k, t in enumerate(chosen) if t.unit == u and spans[k] is not None
              and (last_word is None or t.word <= last_word)]
        if not ks:
            continue
        k = ks[-1]
        lo = max(0, k - th.context)
        f0 = spans[lo][0] if spans[lo] else spans[k][0]
        nxt = next((spans[i][0] for i in range(k + 1, len(chosen)) if spans[i]), T)
        f1 = min(T - 1, nxt - 1, spans[k][1] + 12)
        seg = logp[f0:f1 + 1]
        before = [chosen[i].label for i in range(lo, k + 1) if spans[i] is not None]
        ok = max(ctc_logprob(seg, before), ctc_logprob(seg, before + [vowel.label]))
        best, obs = -1e30, ''
        for v in SHORT:
            if v != vowel.label:
                s_ = ctc_logprob(seg, before + [v])
                if s_ > best:
                    best, obs = s_, VOWEL_NAME[v]
        llr = best - ok
        kind = 'WRONG_VOWEL' if llr >= th.error else None if llr <= -th.correct else 'UNCERTAIN'
        if kind:
            verdicts.append(Verdict(k, vowel, kind, None, 0.0, '', llr, obs))
    return chosen, spans, verdicts


def join_forms(uth_a: str, uth_b: str):
    """The last sound unit of ayah A and the first of ayah B when the two are
    recited joined (wasl), from the phonetizer on their words run together
    with a word of context on each side (so neither looks like an ayah's
    start or end). Returns (A's last unit tokens, B's first unit tokens),
    word indices in their own ayahs, or None when the join merges them."""
    ta, tb = reference(uth_a), reference(uth_b)
    ua, ub = ta[-1].unit, tb[0].unit
    a_words = sorted({t.word for t in ta if t.unit == ua})
    b_words = sorted({t.word for t in tb if t.unit == ub})
    wa = [w for w in uth_a.split(' ') if has_letter(w)]
    wb = [w for w in uth_b.split(' ') if has_letter(w)]
    a0 = max(0, a_words[0] - 1)
    b1 = min(len(wb) - 1, b_words[-1] + 1)
    part_a = wa[a0:a_words[-1] + 1]
    part_b = wb[0:b1 + 1]
    try:
        joined = reference(' '.join(part_a + part_b))
        n_a = len({t.unit for t in reference(' '.join(part_a))})
        n_b = len({t.unit for t in reference(' '.join(part_b))})
    except Exception:
        return None
    if len({t.unit for t in joined}) != n_a + n_b:
        return None
    out_a, out_b = [], []
    for t in joined:
        if t.unit == n_a - 1:
            t.word += a0
            t.unit = ua
            out_a.append(t)
        elif t.unit == n_a:
            t.word -= len(part_a)
            t.unit = ub
            out_b.append(t)
    if not out_a or not out_b or any(t.word < 0 for t in out_b):
        return None
    return out_a, out_b
