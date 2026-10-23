/// 自评中文六档 ↔ 内部出题起始 CEFR（不写入能力水平）。
class SelfAssessTier {
  const SelfAssessTier({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startLevel,
  });

  final String id;
  final String title;
  final String subtitle;

  /// 仅作出题引导；不出现在自评 UI。
  final String startLevel;
}

const kDefaultStartLevel = 'B1';

const kSelfAssessTiers = <SelfAssessTier>[
  SelfAssessTier(
    id: 'entry',
    title: '零基础/入门',
    subtitle: '认识少量简单单词短句，难以读懂完整句子',
    startLevel: 'A1',
  ),
  SelfAssessTier(
    id: 'beginner',
    title: '初级',
    subtitle: '看懂简短日常短句，连续段落读起来比较吃力',
    startLevel: 'A2',
  ),
  SelfAssessTier(
    id: 'intermediate',
    title: '中级',
    subtitle: '读懂短篇故事、简单短文，遇到长文章会很吃力',
    startLevel: 'B1',
  ),
  SelfAssessTier(
    id: 'upper',
    title: '中高级',
    subtitle: '流畅阅读外刊/科普短文，少量生词不阻碍理解',
    startLevel: 'B2',
  ),
  SelfAssessTier(
    id: 'advanced',
    title: '高级',
    subtitle: '通读英文原版读物，读懂隐含观点，熟练掌握地道表达',
    startLevel: 'C1',
  ),
  SelfAssessTier(
    id: 'native',
    title: '母语级',
    subtitle: '自由阅读各类原著、专业文章，语义细节全部吃透',
    startLevel: 'C2',
  ),
];

String startLevelForTierId(String? tierId) {
  if (tierId == null) return kDefaultStartLevel;
  for (final t in kSelfAssessTiers) {
    if (t.id == tierId) return t.startLevel;
  }
  return kDefaultStartLevel;
}
