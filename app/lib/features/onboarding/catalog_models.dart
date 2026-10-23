class CatalogItem {
  const CatalogItem({
    required this.code,
    required this.label,
    this.subtitle,
    this.allowCustom = false,
  });

  final String code;
  final String label;
  final String? subtitle;
  final bool allowCustom;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      code: json['code'] as String,
      label: json['label'] as String,
      subtitle: json['subtitle'] as String?,
      allowCustom: json['allowCustom'] == true,
    );
  }
}

class CatalogList {
  const CatalogList({required this.maxSelect, required this.items});

  final int maxSelect;
  final List<CatalogItem> items;

  factory CatalogList.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => CatalogItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CatalogItem>[];
    return CatalogList(
      maxSelect: (json['maxSelect'] as num?)?.toInt() ?? 1,
      items: items,
    );
  }
}
