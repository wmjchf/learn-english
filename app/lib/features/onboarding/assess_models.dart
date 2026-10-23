class AssessOption {
  const AssessOption({required this.id, required this.label});

  final String id;
  final String label;

  factory AssessOption.fromJson(Map<String, dynamic> json) {
    return AssessOption(
      id: json['id'].toString(),
      label: json['label'] as String? ?? '',
    );
  }
}

class AssessQuestion {
  const AssessQuestion({
    required this.id,
    required this.word,
    required this.prompt,
    required this.options,
    this.phonetic,
  });

  final int id;
  final String word;
  final String? phonetic;
  final String prompt;
  final List<AssessOption> options;

  factory AssessQuestion.fromJson(Map<String, dynamic> json) {
    final raw = json['options'];
    final options = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AssessOption.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AssessOption>[];
    return AssessQuestion(
      id: (json['id'] as num).toInt(),
      word: json['word'] as String? ?? '',
      phonetic: json['phonetic'] as String?,
      prompt: json['prompt'] as String? ?? '这个词更接近哪个意思？',
      options: options,
    );
  }
}

class AssessProgress {
  const AssessProgress({required this.current, required this.total});

  final int current;
  final int total;

  factory AssessProgress.fromJson(Map<String, dynamic>? json) {
    return AssessProgress(
      current: (json?['current'] as num?)?.toInt() ?? 1,
      total: (json?['total'] as num?)?.toInt() ?? 12,
    );
  }
}

class AssessResult {
  const AssessResult({
    required this.level,
    required this.estimatedVocab,
  });

  final String level;
  final int estimatedVocab;

  factory AssessResult.fromJson(Map<String, dynamic>? json) {
    return AssessResult(
      level: json?['level'] as String? ?? 'B1',
      estimatedVocab: (json?['estimatedVocab'] as num?)?.toInt() ?? 2500,
    );
  }
}

class AssessTurn {
  const AssessTurn({
    required this.finished,
    this.sessionId,
    this.question,
    this.progress,
    this.result,
  });

  final bool finished;
  final int? sessionId;
  final AssessQuestion? question;
  final AssessProgress? progress;
  final AssessResult? result;

  factory AssessTurn.fromJson(Map<String, dynamic> json) {
    return AssessTurn(
      finished: json['finished'] == true,
      sessionId: (json['sessionId'] as num?)?.toInt(),
      question: json['question'] is Map<String, dynamic>
          ? AssessQuestion.fromJson(json['question'] as Map<String, dynamic>)
          : null,
      progress: AssessProgress.fromJson(
        json['progress'] as Map<String, dynamic>?,
      ),
      result: json['result'] is Map<String, dynamic>
          ? AssessResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
    );
  }
}
