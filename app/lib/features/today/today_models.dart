class TodayLessonCard {
  const TodayLessonCard({
    required this.id,
    required this.theme,
    required this.title,
    required this.status,
    required this.source,
    required this.dayIndex,
    required this.sceneHint,
    required this.targetWordCount,
    required this.estMinutes,
    required this.ctaLabel,
    this.listLabel,
  });

  final int id;
  final String theme;
  final String title;
  final String status;
  final String source;
  final int dayIndex;
  final String? listLabel;
  final String sceneHint;
  final int targetWordCount;
  final int estMinutes;
  final String ctaLabel;

  bool get isPersonalized => source == 'personalized';
  bool get isSeed => source == 'seed';

  String get metaLine =>
      'Day $dayIndex · $targetWordCount 个目标词 · 约 $estMinutes 分钟';

  factory TodayLessonCard.fromJson(Map<String, dynamic>? json) {
    return TodayLessonCard(
      id: (json?['id'] as num?)?.toInt() ?? 0,
      theme: json?['theme'] as String? ?? '',
      title: json?['title'] as String? ?? '',
      status: json?['status'] as String? ?? 'unread',
      source: json?['source'] as String? ?? 'seed',
      dayIndex: (json?['dayIndex'] as num?)?.toInt() ?? 1,
      listLabel: json?['listLabel'] as String?,
      sceneHint: json?['sceneHint'] as String? ?? '',
      targetWordCount: (json?['targetWordCount'] as num?)?.toInt() ?? 0,
      estMinutes: (json?['estMinutes'] as num?)?.toInt() ?? 8,
      ctaLabel: json?['ctaLabel'] as String? ?? '开始阅读',
    );
  }
}

class TodayReview {
  const TodayReview({
    required this.dueCount,
    required this.inLessonCount,
    required this.subtitle,
  });

  final int dueCount;
  final int inLessonCount;
  final String subtitle;

  factory TodayReview.fromJson(Map<String, dynamic>? json) {
    return TodayReview(
      dueCount: (json?['dueCount'] as num?)?.toInt() ?? 0,
      inLessonCount: (json?['inLessonCount'] as num?)?.toInt() ?? 0,
      subtitle: json?['subtitle'] as String? ?? '暂无到期生词',
    );
  }
}

class TodayPlanMeta {
  const TodayPlanMeta({
    required this.dayIndex,
    required this.totalDays,
    required this.bankTitle,
    required this.paceLabel,
    required this.dayLine,
    required this.metaLine,
  });

  final int dayIndex;
  final int totalDays;
  final String bankTitle;
  final String paceLabel;
  final String dayLine;
  final String metaLine;

  factory TodayPlanMeta.fromJson(Map<String, dynamic>? json) {
    return TodayPlanMeta(
      dayIndex: (json?['dayIndex'] as num?)?.toInt() ?? 1,
      totalDays: (json?['totalDays'] as num?)?.toInt() ?? 1,
      bankTitle: json?['bankTitle'] as String? ?? '',
      paceLabel: json?['paceLabel'] as String? ?? '节奏正常',
      dayLine: json?['dayLine'] as String? ?? 'Day 1 / 1',
      metaLine: json?['metaLine'] as String? ?? '',
    );
  }
}

class TodayPayload {
  const TodayPayload({
    required this.streakDays,
    required this.tasksDone,
    required this.tasksTotal,
    required this.lesson,
    required this.review,
    required this.plan,
    this.lessonPending = false,
  });

  final int streakDays;
  final int tasksDone;
  final int tasksTotal;
  final TodayLessonCard lesson;
  final TodayReview review;
  final TodayPlanMeta plan;

  /// 今日尚无日课，需先触发生成。
  final bool lessonPending;

  bool get needsGenerate =>
      lessonPending || lesson.id <= 0 || lesson.status == 'generating';

  factory TodayPayload.fromJson(Map<String, dynamic>? json) {
    return TodayPayload(
      streakDays: (json?['streakDays'] as num?)?.toInt() ?? 0,
      tasksDone: (json?['tasksDone'] as num?)?.toInt() ?? 0,
      tasksTotal: (json?['tasksTotal'] as num?)?.toInt() ?? 2,
      lessonPending: json?['lessonPending'] == true,
      lesson: TodayLessonCard.fromJson(
        json?['lesson'] is Map
            ? Map<String, dynamic>.from(json!['lesson'] as Map)
            : null,
      ),
      review: TodayReview.fromJson(
        json?['review'] is Map
            ? Map<String, dynamic>.from(json!['review'] as Map)
            : null,
      ),
      plan: TodayPlanMeta.fromJson(
        json?['plan'] is Map
            ? Map<String, dynamic>.from(json!['plan'] as Map)
            : null,
      ),
    );
  }
}
