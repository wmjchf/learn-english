import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/core/ui/blocking_overlay.dart';
import 'package:app_starter/features/library/library_models.dart';
import 'package:app_starter/features/library/library_repository.dart';
import 'package:app_starter/features/lesson/lesson_article_page.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';

/// 文章库 Tab：对齐 Figma Phone/文章库。
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _repo = LibraryRepository();
  final _lessonRepo = LessonRepository();

  String _filter = 'all';
  LibraryPayload? _data;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blue = Color(0xFF2563EB);
  static const _hero = Color(0xFF1E3A8A);
  static const _heroLabel = Color(0xFF93C5FD);
  static const _heroMeta = Color(0xFFBFDBFE);
  static const _border = Color(0xFFE2E8F0);
  static const _chipBg = Color(0xFFEFF6FF);

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
      final data = await _repo.list(status: _filter);
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

  Future<void> _setFilter(String status) async {
    if (_filter == status) return;
    setState(() => _filter = status);
    await _load();
  }

  Future<void> _openLesson(int id) async {
    try {
      AppToast.loading(context, '打开文章…');
      final lesson = await _lessonRepo.getById(id);
      if (!mounted) return;
      AppToast.hide(context);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonArticlePage(lesson: lesson),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.hide(context);
      AppToast.show(
        context,
        e is ApiException ? e.message : '打开失败',
      );
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    final quota = _data?.quota;
    if (quota != null && !quota.canGenerateFree) {
      AppToast.show(context, quota.hint);
      return;
    }

    setState(() => _generating = true);
    try {
      final result = await BlockingOverlay.run(
        context,
        child: const _GeneratingCard(),
        task: () => _repo.generate(),
      );
      if (!mounted || result == null) return;
      AppToast.show(context, '新文章已生成');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonArticlePage(lesson: result.lesson),
        ),
      );
      if (mounted) {
        setState(() => _filter = 'all');
        await _load();
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e is ApiException ? e.message : '生成失败',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
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
                          '文章库',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _text,
                            height: 34 / 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '读过的都在这。想换一篇，再生成一次。',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted,
                            height: 20 / 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _GenerateHero(
                          hint: _data?.quota.hint ??
                              '今天还可免费生成 1 次，之后需付费。',
                          enabled: !_generating &&
                              (_data?.quota.canGenerateFree ?? true),
                          onGenerate: _generate,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _FilterChip(
                              label: '全部',
                              selected: _filter == 'all',
                              onTap: () => _setFilter('all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '未读',
                              selected: _filter == 'unread',
                              onTap: () => _setFilter('unread'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: '已读',
                              selected: _filter == 'done',
                              onTap: () => _setFilter('done'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if ((_data?.items ?? []).isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              '还没有文章。去今日读一篇，或点上方生成。',
                              style: TextStyle(fontSize: 13, color: _meta),
                            ),
                          )
                        else
                          ..._data!.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LessonRow(
                                item: item,
                                onTap: () => _openLesson(item.id),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _GenerateHero extends StatelessWidget {
  const _GenerateHero({
    required this.hint,
    required this.enabled,
    required this.onGenerate,
  });

  final String hint;
  final bool enabled;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: _LibraryPageState._hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '手动再生成',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _LibraryPageState._heroLabel,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '自动篇不够学，或不满意？',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 28 / 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 13,
              color: _LibraryPageState._heroMeta,
              height: 18 / 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: enabled ? onGenerate : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBFDBFE),
                foregroundColor: _LibraryPageState._hero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                enabled ? '生成新文章' : '今日免费已用完',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
          color: selected ? _LibraryPageState._chipBg : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? _LibraryPageState._blue
                : _LibraryPageState._border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? _LibraryPageState._blue
                : _LibraryPageState._muted,
          ),
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.item, required this.onTap});

  final LibraryLessonCard item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isDone;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _LibraryPageState._border),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: unread
                      ? _LibraryPageState._blue
                      : _LibraryPageState._border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: unread
                            ? _LibraryPageState._blue
                            : _LibraryPageState._meta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.theme.isNotEmpty ? item.theme : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _LibraryPageState._text,
                        height: 22 / 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.metaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _LibraryPageState._meta,
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

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.4),
          SizedBox(height: 16),
          Text(
            '正在生成新文章…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '大约需要一两分钟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
