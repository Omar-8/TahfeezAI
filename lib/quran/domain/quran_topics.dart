/// The Quran's topics: the Quranic Arabic Corpus's ontology of concepts
/// (`tool/quran_data/build_topics.py`) — each concept with its names, its
/// place among the others, and the ayahs it is tagged in — gathered into a
/// few groups for browsing.
class QuranTopics {
  const QuranTopics({required this.groups, required this.concepts});

  factory QuranTopics.fromJson(Map<String, Object?> json) {
    final concepts = {
      for (final MapEntry(key: id, value: c)
          in (json['concepts']! as Map<String, Object?>).entries)
        id: TopicConcept._fromJson(id, c! as Map<String, Object?>),
    };
    return QuranTopics(
      groups: [
        for (final g in json['groups']! as List)
          TopicGroup(
            id: (g as Map)['id'] as String,
            concepts: [
              for (final c in g['concepts'] as List) ?concepts[c as String],
            ],
          ),
      ],
      concepts: concepts,
    );
  }

  final List<TopicGroup> groups;
  final Map<String, TopicConcept> concepts;
}

/// A group of concepts (prophets, places, the hereafter…), named by the
/// app's own strings.
class TopicGroup {
  const TopicGroup({required this.id, required this.concepts});

  final String id;

  /// Its concepts, the most mentioned first.
  final List<TopicConcept> concepts;

  int get ayahCount => {for (final c in concepts) ...c.ayahs}.length;
}

class TopicConcept {
  const TopicConcept({
    required this.id,
    required this.arabic,
    required this.names,
    required this.ayahs,
  });

  factory TopicConcept._fromJson(String id, Map<String, Object?> json) =>
      TopicConcept(
        id: id,
        arabic: json['ar'] as String? ?? '',
        names: {
          for (final MapEntry(key: language, value: name)
              in (json['names']! as Map<String, Object?>).entries)
            language: name! as String,
        },
        ayahs: [for (final a in json['ayahs']! as List) a as int],
      );

  final String id;

  /// Its name in the Quran's Arabic, as the corpus gives it.
  final String arabic;

  /// Language code → its name in that language ('en' always there).
  final Map<String, String> names;

  /// The ayahs it is mentioned in (`chapter*1000+verse`), in order.
  final List<int> ayahs;

  /// Its name in [language], else English.
  String nameIn(String language) => names[language] ?? names['en']!;
}
