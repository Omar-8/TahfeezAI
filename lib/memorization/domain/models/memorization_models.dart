/// How one ayah went in one recitation test.
enum AyahGrade {
  /// A word was wrong or skipped (or revealed by hand in hide mode).
  fail,

  /// The words were right, but with a self-correction or a pronunciation
  /// mistake.
  hard,

  /// Clean.
  good,
}

/// Where an ayah is in memorization.
enum MemoryStatus {
  /// Being learned: tested, but not yet recited cleanly from memory (with
  /// hide mode on).
  learning,

  /// Memorized: recited from memory without a mistake in the words, or
  /// marked as already known.
  memorized,
}

/// What Tahfeez knows about the user's memory of one ayah.
class AyahMemory {
  const AyahMemory({
    required this.ayahId,
    required this.status,
    this.verified = true,
    this.stability,
    this.lastReviewed,
    this.learnedOn,
    this.reviews = 0,
  });

  final int ayahId;
  final MemoryStatus status;

  /// Recited in the app at least once. Parts the user marked as already
  /// memorized are unverified (and have no [stability]) until then.
  final bool verified;

  /// In days: how long after [lastReviewed] the ayah is still recalled with
  /// 90% likelihood (see `StrengthModel`). `null` before any test.
  final double? stability;

  final DateTime? lastReviewed;

  /// When it became [MemoryStatus.memorized] through the app's tests; `null`
  /// for parts marked as already known.
  final DateTime? learnedOn;

  /// Tests it was graded in.
  final int reviews;

  AyahMemory copyWith({
    MemoryStatus? status,
    bool? verified,
    double? stability,
    DateTime? lastReviewed,
    DateTime? learnedOn,
    int? reviews,
  }) => AyahMemory(
    ayahId: ayahId,
    status: status ?? this.status,
    verified: verified ?? this.verified,
    stability: stability ?? this.stability,
    lastReviewed: lastReviewed ?? this.lastReviewed,
    learnedOn: learnedOn ?? this.learnedOn,
    reviews: reviews ?? this.reviews,
  );

  @override
  bool operator ==(Object other) =>
      other is AyahMemory &&
      other.ayahId == ayahId &&
      other.status == status &&
      other.verified == verified &&
      other.stability == stability &&
      other.lastReviewed == lastReviewed &&
      other.learnedOn == learnedOn &&
      other.reviews == reviews;

  @override
  int get hashCode => Object.hash(
    ayahId,
    status,
    verified,
    stability,
    lastReviewed,
    learnedOn,
    reviews,
  );

  @override
  String toString() =>
      'AyahMemory($ayahId, ${status.name}, verified $verified, '
      'S $stability, last $lastReviewed, reviews $reviews)';
}

/// One ayah's result in one recitation test.
class AyahAttempt {
  const AyahAttempt({
    required this.ayahId,
    required this.sessionId,
    required this.at,
    required this.grade,
    required this.words,
    this.wrong = 0,
    this.skipped = 0,
    this.selfCorrected = 0,
    this.pronunciation = 0,
    this.hidden = false,
  });

  final int ayahId;
  final String sessionId;
  final DateTime at;
  final AyahGrade grade;

  /// The ayah's words, and of them: said wrong, skipped (or revealed by
  /// hand), corrected by the reciter, heard with a pronunciation mistake.
  final int words, wrong, skipped, selfCorrected, pronunciation;

  /// Recited with hide mode on (from memory).
  final bool hidden;

  @override
  String toString() =>
      'AyahAttempt($ayahId, ${grade.name}, $words words: wrong $wrong, '
      'skipped $skipped, corrected $selfCorrected, pronunciation '
      '$pronunciation, hidden $hidden)';
}
