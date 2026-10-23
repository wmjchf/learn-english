class UserProfile {
  const UserProfile({
    required this.onboardingStep,
    this.abilityLevel,
    this.generationLevel,
    this.jobCode,
    this.jobRaw,
    this.scenes = const [],
    this.interests = const [],
    this.dailyMinutes,
    this.targetDays,
    this.primaryBankId,
    this.timezone,
  });

  final String onboardingStep;
  final String? abilityLevel;
  final String? generationLevel;
  final String? jobCode;
  final String? jobRaw;
  final List<String> scenes;
  final List<String> interests;
  final int? dailyMinutes;
  final int? targetDays;
  final int? primaryBankId;
  final String? timezone;

  bool get isOnboardingDone => onboardingStep == 'done';

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    final map = json ?? const <String, dynamic>{};
    return UserProfile(
      onboardingStep: (map['onboardingStep'] as String?) ?? 'interest',
      abilityLevel: map['abilityLevel'] as String?,
      generationLevel: map['generationLevel'] as String?,
      jobCode: map['jobCode'] as String?,
      jobRaw: map['jobRaw'] as String?,
      scenes: _stringList(map['scenes']),
      interests: _stringList(map['interests']),
      dailyMinutes: (map['dailyMinutes'] as num?)?.toInt(),
      targetDays: (map['targetDays'] as num?)?.toInt(),
      primaryBankId: (map['primaryBankId'] as num?)?.toInt(),
      timezone: map['timezone'] as String?,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}
