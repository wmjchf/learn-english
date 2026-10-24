class VocabDueSummary {
  const VocabDueSummary({
    required this.dueCount,
    required this.inLessonCount,
    required this.flashCount,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
  });

  final int dueCount;
  final int inLessonCount;
  final int flashCount;
  final String title;
  final String subtitle;
  final String? ctaLabel;

  factory VocabDueSummary.fromJson(Map<String, dynamic>? json) {
    return VocabDueSummary(
      dueCount: (json?['dueCount'] as num?)?.toInt() ?? 0,
      inLessonCount: (json?['inLessonCount'] as num?)?.toInt() ?? 0,
      flashCount: (json?['flashCount'] as num?)?.toInt() ?? 0,
      title: json?['title'] as String? ?? '今天没有到期词',
      subtitle: json?['subtitle'] as String? ?? '',
      ctaLabel: json?['ctaLabel'] as String?,
    );
  }
}

class VocabCounts {
  const VocabCounts({
    required this.learning,
    required this.consolidating,
    required this.mastered,
  });

  final int learning;
  final int consolidating;
  final int mastered;

  factory VocabCounts.fromJson(Map<String, dynamic>? json) {
    return VocabCounts(
      learning: (json?['learning'] as num?)?.toInt() ?? 0,
      consolidating: (json?['consolidating'] as num?)?.toInt() ?? 0,
      mastered: (json?['mastered'] as num?)?.toInt() ?? 0,
    );
  }
}

class VocabItem {
  const VocabItem({
    required this.lemma,
    required this.status,
    required this.bucket,
    required this.accent,
    required this.metaLine,
    this.nextReviewAt,
    this.sourceLessonId,
    this.sourceTitle,
    this.gloss,
    this.context,
    this.root,
  });

  final String lemma;
  final String status;
  final String bucket;
  final String accent; // today | tomorrow | later
  final String metaLine;
  final String? nextReviewAt;
  final int? sourceLessonId;
  final String? sourceTitle;
  final String? gloss;
  final String? context;
  final String? root;

  factory VocabItem.fromJson(Map<String, dynamic>? json) {
    return VocabItem(
      lemma: json?['lemma'] as String? ?? '',
      status: json?['status'] as String? ?? '',
      bucket: json?['bucket'] as String? ?? '',
      accent: json?['accent'] as String? ?? 'later',
      metaLine: json?['metaLine'] as String? ?? '',
      nextReviewAt: json?['nextReviewAt'] as String?,
      sourceLessonId: (json?['sourceLessonId'] as num?)?.toInt(),
      sourceTitle: json?['sourceTitle'] as String?,
      gloss: json?['gloss'] as String?,
      context: json?['context'] as String?,
      root: json?['root'] as String?,
    );
  }
}

class VocabPayload {
  const VocabPayload({
    required this.bucket,
    required this.counts,
    required this.due,
    required this.items,
  });

  final String bucket;
  final VocabCounts counts;
  final VocabDueSummary due;
  final List<VocabItem> items;

  factory VocabPayload.fromJson(Map<String, dynamic>? json) {
    final raw = json?['items'];
    return VocabPayload(
      bucket: json?['bucket'] as String? ?? 'consolidating',
      counts: VocabCounts.fromJson(
        json?['counts'] is Map
            ? Map<String, dynamic>.from(json!['counts'] as Map)
            : null,
      ),
      due: VocabDueSummary.fromJson(
        json?['due'] is Map
            ? Map<String, dynamic>.from(json!['due'] as Map)
            : null,
      ),
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => VocabItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}
