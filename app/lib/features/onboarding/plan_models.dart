import 'package:app_starter/features/onboarding/bank_models.dart';

class PlanEstimate {
  const PlanEstimate({
    required this.minutes,
    required this.days,
    required this.dailyWords,
    this.wordsPerLesson = 12,
    this.warning,
  });

  final int minutes;
  final int days;
  final int dailyWords;
  final int wordsPerLesson;
  final String? warning;

  factory PlanEstimate.fromJson(Map<String, dynamic>? json) {
    return PlanEstimate(
      minutes: (json?['minutes'] as num?)?.toInt() ?? 20,
      days: (json?['days'] as num?)?.toInt() ?? 1,
      dailyWords: (json?['dailyWords'] as num?)?.toInt() ?? 30,
      wordsPerLesson: (json?['wordsPerLesson'] as num?)?.toInt() ?? 12,
      warning: json?['warning'] as String?,
    );
  }
}

class PlanContext {
  const PlanContext({
    required this.bank,
    required this.knownEstimate,
    required this.remaining,
    required this.minuteOptions,
    required this.defaultMinutes,
    required this.estimate,
    this.sceneLabels = const [],
    this.level,
  });

  final WordBank bank;
  final int knownEstimate;
  final int remaining;
  final List<int> minuteOptions;
  final int defaultMinutes;
  final PlanEstimate estimate;
  final List<String> sceneLabels;
  final String? level;

  factory PlanContext.fromJson(Map<String, dynamic> json) {
    final bankJson = json['bank'];
    final profile = json['profile'];
    return PlanContext(
      bank: WordBank.fromJson(
        bankJson is Map<String, dynamic>
            ? bankJson
            : <String, dynamic>{
                'id': 0,
                'code': '',
                'type': '',
                'title': '',
              },
      ),
      knownEstimate: (json['knownEstimate'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 1,
      minuteOptions: (json['minuteOptions'] is List)
          ? (json['minuteOptions'] as List)
              .map((e) => (e as num).toInt())
              .toList()
          : const [10, 15, 20, 30, 45, 60],
      defaultMinutes: (json['defaultMinutes'] as num?)?.toInt() ?? 20,
      estimate: PlanEstimate.fromJson(
        json['estimate'] as Map<String, dynamic>?,
      ),
      sceneLabels: json['sceneLabels'] is List
          ? (json['sceneLabels'] as List).map((e) => e.toString()).toList()
          : const [],
      level: profile is Map
          ? (profile['generationLevel'] as String?) ??
              (profile['abilityLevel'] as String?)
          : null,
    );
  }
}

class PlanReady {
  const PlanReady({
    required this.title,
    required this.subtitle,
    required this.bankLine,
    required this.days,
    required this.minutes,
    required this.level,
    required this.dayProgress,
    this.scenesLine,
  });

  final String title;
  final String subtitle;
  final String bankLine;
  final int days;
  final int minutes;
  final String level;
  final String dayProgress;
  final String? scenesLine;

  factory PlanReady.fromJson(Map<String, dynamic>? json) {
    return PlanReady(
      title: json?['title'] as String? ?? '你的计划已就绪',
      subtitle: json?['subtitle'] as String? ?? '',
      bankLine: json?['bankLine'] as String? ?? '',
      days: (json?['days'] as num?)?.toInt() ?? 1,
      minutes: (json?['minutes'] as num?)?.toInt() ?? 20,
      level: json?['level'] as String? ?? 'B1',
      dayProgress: json?['dayProgress'] as String? ?? '今天是 Day 1',
      scenesLine: json?['scenesLine'] as String?,
    );
  }
}
