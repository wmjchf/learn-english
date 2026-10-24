import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_article_page.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/vocab/review_page.dart';
import 'package:app_starter/features/vocab/vocab_models.dart';
import 'package:app_starter/features/vocab/vocab_repository.dart';

/// 生词本 Tab：对齐 Figma Phone/生词本。
class VocabPage extends StatefulWidget {
  const VocabPage({super.key});

  @override
  State<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends State<VocabPage> {
  final _repo = VocabRepository();
  final _lessonRepo = LessonRepository();

  String _bucket = 'consolidating';
  VocabPayload? _data;
  bool _loading = true;
  String? _error;

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _hero = Color(0xFF1E3A8A);
  static const _heroLabel = Color(0xFF93C5FD);
  static const _heroMeta = Color(0xFFBFDBFE);
  static const _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.list(bucket: _bucket);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  Future<void> _setBucket(String bucket) async {
    if (_bucket == bucket) return;
    setState(() => _bucket = bucket);
    await _load();
  }

  Future<void> _startReview() async {
    final due = _data?.due.dueCount ?? 0;
    if (due <= 0) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ReviewPage()),
    );
    if (mounted) _load();
  }

  Future<void> _openSource(VocabItem item) async {
    final id = item.sourceLessonId;
    if (id == null) return;
    try {
      final lesson = await _lessonRepo.getById(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonArticlePage(
            lesson: lesson,
            focusLemma: item.lemma,
          ),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      /* 静默失败 */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: _loading && _data == null
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null && _data == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      children: [
                        const Text(
                          '生词本',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 34 / 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '到期优先复现进文章；多出来的再闪卡。',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted,
                            height: 20 / 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DueHero(
                          due: _data!.due,
                          onStart: _startReview,
                        ),
                        const SizedBox(height: 16),
                        _BucketChips(
                          counts: _data!.counts,
                          selected: _bucket,
                          onSelect: _setBucket,
                        ),
                        const SizedBox(height: 10),
                        if (_data!.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Text(
                              _emptyHint(_bucket),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _meta,
                              ),
                            ),
                          )
                        else
                          ..._data!.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _WordRow(
                                item: item,
                                onTap: () => _openSource(item),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _emptyHint(String bucket) {
    switch (bucket) {
      case 'learning':
        return '开始读日课后，目标词会出现在这里。';
      case 'mastered':
        return '点「认识」或复习通过后会出现在这里。';
      default:
        return '点词「不认识」可加入待巩固。';
    }
  }

}

class _DueHero extends StatelessWidget {
  const _DueHero({required this.due, required this.onStart});

  final VocabDueSummary due;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: _VocabPageState._hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日到期',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _VocabPageState._heroLabel,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            due.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 30 / 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            due.subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: _VocabPageState._heroMeta,
              height: 18 / 13,
            ),
          ),
          if (due.ctaLabel != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _VocabPageState._hero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  due.ctaLabel!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BucketChips extends StatelessWidget {
  const _BucketChips({
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  final VocabCounts counts;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final chips = [
      ('learning', '学习中 ${counts.learning}'),
      ('consolidating', '待巩固 ${counts.consolidating}'),
      ('mastered', '已掌握 ${counts.mastered}'),
    ];
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _Chip(
            label: chips[i].$2,
            selected: selected == chips[i].$1,
            onTap: () => onSelect(chips[i].$1),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _VocabPageState._blueSoft : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? _VocabPageState._blue
                : _VocabPageState._border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? _VocabPageState._blue
                : _VocabPageState._muted,
          ),
        ),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.item, required this.onTap});

  final VocabItem item;
  final VoidCallback onTap;

  Color get _barColor {
    switch (item.accent) {
      case 'today':
        return _VocabPageState._blue;
      case 'tomorrow':
        return const Color(0xFF93C5FD);
      default:
        return _VocabPageState._border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _VocabPageState._border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: _barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.lemma,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _VocabPageState._text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.metaLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _VocabPageState._meta,
                        height: 17 / 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
