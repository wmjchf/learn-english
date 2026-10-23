class GenerateQuota {
  const GenerateQuota({
    required this.dailyFree,
    required this.used,
    required this.remaining,
    required this.canGenerateFree,
    required this.hint,
  });

  final int dailyFree;
  final int used;
  final int remaining;
  final bool canGenerateFree;
  final String hint;

  factory GenerateQuota.fromJson(Map<String, dynamic>? json) {
    return GenerateQuota(
      dailyFree: (json?['dailyFree'] as num?)?.toInt() ?? 1,
      used: (json?['used'] as num?)?.toInt() ?? 0,
      remaining: (json?['remaining'] as num?)?.toInt() ?? 0,
      canGenerateFree: json?['canGenerateFree'] == true,
      hint: json?['hint'] as String? ?? '',
    );
  }
}

class LibraryLessonCard {
  const LibraryLessonCard({
    required this.id,
    required this.theme,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.isToday,
    required this.targetWordCount,
    required this.knownCount,
    required this.sceneTag,
    required this.metaLine,
  });

  final int id;
  final String theme;
  final String title;
  final String status;
  final String statusLabel;
  final bool isToday;
  final int targetWordCount;
  final int knownCount;
  final String sceneTag;
  final String metaLine;

  bool get isDone => status == 'done';

  factory LibraryLessonCard.fromJson(Map<String, dynamic> json) {
    return LibraryLessonCard(
      id: (json['id'] as num).toInt(),
      theme: json['theme'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'unread',
      statusLabel: json['statusLabel'] as String? ?? '',
      isToday: json['isToday'] == true,
      targetWordCount: (json['targetWordCount'] as num?)?.toInt() ?? 0,
      knownCount: (json['knownCount'] as num?)?.toInt() ?? 0,
      sceneTag: json['sceneTag'] as String? ?? '',
      metaLine: json['metaLine'] as String? ?? '',
    );
  }
}

class LibraryPayload {
  const LibraryPayload({
    required this.items,
    required this.quota,
  });

  final List<LibraryLessonCard> items;
  final GenerateQuota quota;

  factory LibraryPayload.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return LibraryPayload(
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => LibraryLessonCard.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      quota: GenerateQuota.fromJson(
        json['quota'] is Map
            ? Map<String, dynamic>.from(json['quota'] as Map)
            : null,
      ),
    );
  }
}
