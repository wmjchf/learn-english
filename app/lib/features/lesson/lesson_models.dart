class LessonToken {
  const LessonToken({
    required this.surface,
    required this.lemma,
    this.isTarget = false,
    this.isReview = false,
  });

  final String surface;
  final String lemma;
  final bool isTarget;
  final bool isReview;

  factory LessonToken.fromJson(Map<String, dynamic> json) {
    return LessonToken(
      surface: json['surface'] as String? ?? '',
      lemma: json['lemma'] as String? ?? '',
      isTarget: json['isTarget'] == true || json['is_target'] == true,
      isReview: json['isReview'] == true || json['is_review'] == true,
    );
  }
}

class LessonDef {
  const LessonDef({
    required this.gloss,
    this.pos,
    this.sense,
    this.context,
    this.root,
    this.exampleEn,
    this.exampleZh,
  });

  final String gloss;
  final String? pos;
  final String? sense;
  final String? context;
  final String? root;
  final String? exampleEn;
  final String? exampleZh;

  factory LessonDef.fromJson(Map<String, dynamic> json) {
    return LessonDef(
      gloss: json['gloss'] as String? ?? '',
      pos: json['pos'] as String?,
      sense: json['sense'] as String?,
      context: json['context'] as String?,
      root: json['root'] as String?,
      exampleEn: (json['exampleEn'] ?? json['example_en']) as String?,
      exampleZh: (json['exampleZh'] ?? json['example_zh']) as String?,
    );
  }
}

class LessonScene {
  const LessonScene({
    required this.title,
    required this.roleBackground,
    required this.tasks,
  });

  final String title;
  final String roleBackground;
  final List<String> tasks;

  factory LessonScene.fromJson(Map<String, dynamic>? json) {
    final raw = json?['tasks'];
    return LessonScene(
      title: json?['title'] as String? ?? '① 场景导入（导读）',
      roleBackground: json?['roleBackground'] as String? ??
          json?['role_background'] as String? ??
          '',
      tasks: raw is List
          ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }

  /// 任务行：① a ② b ③ c
  String get tasksDisplay {
    if (tasks.isEmpty) return '';
    const marks = ['①', '②', '③', '④', '⑤'];
    final buf = StringBuffer('任务：');
    for (var i = 0; i < tasks.length; i++) {
      if (i > 0) buf.write(' ');
      buf.write('${marks[i.clamp(0, marks.length - 1)]} ${tasks[i]}');
    }
    return buf.toString();
  }
}

class LessonArticle {
  const LessonArticle({
    required this.title,
    required this.zhTitle,
    required this.zhLead,
    required this.zhPlain,
    required this.enPlain,
    required this.enTokens,
  });

  final String title;
  /// 英文标题的中文译名。
  final String zhTitle;
  final String zhLead;
  /// 短文完整中译；目标词对应中文可用 【】 标出。
  final String zhPlain;
  final String enPlain;
  final List<LessonToken> enTokens;

  /// 展示用中译：优先完整译文，否则用导读。
  String get zhDisplay {
    final plain = zhPlain.trim();
    if (plain.isNotEmpty) return plain;
    return zhLead.trim();
  }

  /// 短文标题行：英文 + 中文译名；[fallbackZh] 用于旧课无 zhTitle 时（如用 theme）。
  String titleDisplay({String fallbackZh = ''}) {
    final en = title.trim();
    final zh = zhTitle.trim().isNotEmpty ? zhTitle.trim() : fallbackZh.trim();
    if (en.isEmpty) return zh;
    if (zh.isEmpty) return en;
    return '$en（$zh）';
  }

  factory LessonArticle.fromJson(Map<String, dynamic>? json) {
    final raw = json?['enTokens'] ?? json?['en_tokens'];
    return LessonArticle(
      title: json?['title'] as String? ?? '',
      zhTitle:
          json?['zhTitle'] as String? ?? json?['zh_title'] as String? ?? '',
      zhLead: json?['zhLead'] as String? ?? json?['zh_lead'] as String? ?? '',
      zhPlain:
          json?['zhPlain'] as String? ?? json?['zh_plain'] as String? ?? '',
      enPlain: json?['enPlain'] as String? ?? json?['en_plain'] as String? ?? '',
      enTokens: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => LessonToken.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class DialogTurn {
  const DialogTurn({
    required this.who,
    required this.en,
    required this.zh,
    required this.enTokens,
  });

  final String who;
  final String en;
  /// 该轮中译；目标词对应中文可用 【】 标出。
  final String zh;
  final List<LessonToken> enTokens;

  factory DialogTurn.fromJson(Map<String, dynamic> json) {
    final raw = json['enTokens'] ?? json['en_tokens'];
    return DialogTurn(
      who: json['who'] as String? ?? '',
      en: json['en'] as String? ?? '',
      zh: json['zh'] as String? ?? '',
      enTokens: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => LessonToken.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class LessonDialog {
  const LessonDialog({
    required this.title,
    required this.zhTitle,
    required this.zhLead,
    required this.enPlain,
    required this.turns,
  });

  final String title;
  final String zhTitle;
  final String zhLead;
  final String enPlain;
  final List<DialogTurn> turns;

  bool get hasTurnZh => turns.any((t) => t.zh.trim().isNotEmpty);

  String titleDisplay({String fallbackZh = ''}) {
    final en = title.trim();
    final zh = zhTitle.trim().isNotEmpty ? zhTitle.trim() : fallbackZh.trim();
    if (en.isEmpty) return zh;
    if (zh.isEmpty) return en;
    return '$en（$zh）';
  }

  factory LessonDialog.fromJson(Map<String, dynamic>? json) {
    final raw = json?['turns'];
    return LessonDialog(
      title: json?['title'] as String? ?? '',
      zhTitle:
          json?['zhTitle'] as String? ?? json?['zh_title'] as String? ?? '',
      zhLead: json?['zhLead'] as String? ?? json?['zh_lead'] as String? ?? '',
      enPlain: json?['enPlain'] as String? ?? json?['en_plain'] as String? ?? '',
      turns: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => DialogTurn.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class ClozeItem {
  const ClozeItem({
    required this.before,
    required this.sentence,
    required this.hintZh,
    required this.answer,
    required this.after,
  });

  final String before;
  final String sentence;
  final String hintZh;
  final String answer;
  final String after;

  factory ClozeItem.fromJson(Map<String, dynamic> json) {
    return ClozeItem(
      before: json['before'] as String? ?? '',
      sentence: json['sentence'] as String? ?? '',
      hintZh: json['hintZh'] as String? ?? json['hint_zh'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      after: json['after'] as String? ?? '',
    );
  }
}

class LessonContent {
  const LessonContent({
    required this.scene,
    required this.article,
    required this.dialog,
    required this.cloze,
    required this.targetLemmas,
    required this.defs,
  });

  final LessonScene scene;
  final LessonArticle article;
  final LessonDialog dialog;
  final List<ClozeItem> cloze;
  final List<String> targetLemmas;
  final Map<String, LessonDef> defs;

  factory LessonContent.fromJson(Map<String, dynamic>? json) {
    final defsRaw = json?['defs'];
    final defs = <String, LessonDef>{};
    if (defsRaw is Map) {
      for (final e in defsRaw.entries) {
        if (e.value is Map) {
          defs[e.key.toString()] =
              LessonDef.fromJson(Map<String, dynamic>.from(e.value as Map));
        }
      }
    }
    final targets = json?['targetLemmas'] ?? json?['target_lemmas'];
    final clozeRaw = json?['cloze'];
    return LessonContent(
      scene: LessonScene.fromJson(
        json?['scene'] is Map
            ? Map<String, dynamic>.from(json!['scene'] as Map)
            : null,
      ),
      article: LessonArticle.fromJson(
        json?['article'] is Map
            ? Map<String, dynamic>.from(json!['article'] as Map)
            : null,
      ),
      dialog: LessonDialog.fromJson(
        json?['dialog'] is Map
            ? Map<String, dynamic>.from(json!['dialog'] as Map)
            : null,
      ),
      cloze: clozeRaw is List
          ? clozeRaw
              .whereType<Map>()
              .map((e) => ClozeItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      targetLemmas: targets is List
          ? targets.map((e) => e.toString()).toList()
          : const [],
      defs: defs,
    );
  }

  LessonDef? defFor(String lemma) {
    final key = lemma.trim().toLowerCase();
    if (key.isEmpty) return null;
    final direct = defs[key] ?? defs[lemma];
    if (direct != null) return direct;
    for (final e in defs.entries) {
      if (e.key.toLowerCase() == key) return e.value;
    }
    return null;
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.dayIndex,
    required this.theme,
    required this.listLabel,
    required this.title,
    required this.status,
    required this.content,
    this.generationLevel,
  });

  final int id;
  final int dayIndex;
  final String theme;
  final String listLabel;
  final String title;
  final String status;
  final String? generationLevel;
  final LessonContent content;

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: (json['id'] as num).toInt(),
      dayIndex: (json['dayIndex'] as num?)?.toInt() ??
          (json['day_index'] as num?)?.toInt() ??
          1,
      theme: json['theme'] as String? ?? '',
      listLabel: json['listLabel'] as String? ??
          json['list_label'] as String? ??
          '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'unread',
      generationLevel: json['generationLevel'] as String? ??
          json['generation_level'] as String?,
      content: LessonContent.fromJson(
        json['content'] is Map
            ? Map<String, dynamic>.from(json['content'] as Map)
            : null,
      ),
    );
  }
}
