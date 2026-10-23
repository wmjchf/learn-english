import 'package:app_starter/features/profile/user_profile.dart';

class MeHero {
  const MeHero({
    required this.title,
    required this.abilityLine,
    required this.note,
    required this.bankTitle,
    required this.abilityLevel,
    required this.generationLevel,
  });

  final String title;
  final String abilityLine;
  final String note;
  final String bankTitle;
  final String abilityLevel;
  final String generationLevel;

  factory MeHero.fromJson(Map<String, dynamic>? json) {
    return MeHero(
      title: json?['title'] as String? ?? '',
      abilityLine: json?['abilityLine'] as String? ?? '',
      note: json?['note'] as String? ?? '改动只影响之后的文章。',
      bankTitle: json?['bankTitle'] as String? ?? '',
      abilityLevel: json?['abilityLevel'] as String? ?? '—',
      generationLevel: json?['generationLevel'] as String? ?? '—',
    );
  }
}

class MeStats {
  const MeStats({
    required this.vocab,
    required this.vocabLabel,
    required this.weekDelta,
    required this.weekDeltaLabel,
    required this.streakDays,
    required this.streakLabel,
    required this.streakFootnote,
    required this.longestStreak,
  });

  final int vocab;
  final String vocabLabel;
  final int weekDelta;
  final String weekDeltaLabel;
  final int streakDays;
  final String streakLabel;
  final String streakFootnote;
  final int longestStreak;

  factory MeStats.fromJson(Map<String, dynamic>? json) {
    return MeStats(
      vocab: (json?['vocab'] as num?)?.toInt() ?? 0,
      vocabLabel: json?['vocabLabel'] as String? ?? '0',
      weekDelta: (json?['weekDelta'] as num?)?.toInt() ?? 0,
      weekDeltaLabel: json?['weekDeltaLabel'] as String? ?? '本周暂无增长',
      streakDays: (json?['streakDays'] as num?)?.toInt() ?? 0,
      streakLabel: json?['streakLabel'] as String? ?? '0 天',
      streakFootnote: json?['streakFootnote'] as String? ?? '历史最长',
      longestStreak: (json?['longestStreak'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeUser {
  const MeUser({required this.phone, required this.nickname});

  final String phone;
  final String nickname;

  factory MeUser.fromJson(Map<String, dynamic>? json) {
    return MeUser(
      phone: json?['phone'] as String? ?? '',
      nickname: json?['nickname'] as String? ?? '',
    );
  }
}

class MeSummary {
  const MeSummary({
    required this.user,
    required this.hero,
    required this.stats,
    this.profile,
  });

  final MeUser user;
  final MeHero hero;
  final MeStats stats;
  final UserProfile? profile;

  factory MeSummary.fromJson(Map<String, dynamic>? json) {
    return MeSummary(
      user: MeUser.fromJson(
        json?['user'] is Map
            ? Map<String, dynamic>.from(json!['user'] as Map)
            : null,
      ),
      hero: MeHero.fromJson(
        json?['hero'] is Map
            ? Map<String, dynamic>.from(json!['hero'] as Map)
            : null,
      ),
      stats: MeStats.fromJson(
        json?['stats'] is Map
            ? Map<String, dynamic>.from(json!['stats'] as Map)
            : null,
      ),
      profile: json?['profile'] is Map
          ? UserProfile.fromJson(Map<String, dynamic>.from(json!['profile'] as Map))
          : null,
    );
  }
}
