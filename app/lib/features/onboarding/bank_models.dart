class WordBank {
  const WordBank({
    required this.id,
    required this.code,
    required this.type,
    required this.title,
    this.subtitle,
    this.targetSize,
    this.wordCount,
  });

  final int id;
  final String code;
  final String type;
  final String title;
  final String? subtitle;
  final int? targetSize;
  final int? wordCount;

  factory WordBank.fromJson(Map<String, dynamic> json) {
    return WordBank(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      targetSize: (json['targetSize'] as num?)?.toInt(),
      wordCount: (json['wordCount'] as num?)?.toInt(),
    );
  }
}
