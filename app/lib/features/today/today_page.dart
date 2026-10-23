import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_article_page.dart';
import 'package:app_starter/features/today/today_models.dart';
import 'package:app_starter/features/today/today_repository.dart';
import 'package:app_starter/features/vocab/review_page.dart';

/// 今日 Tab：对齐 Figma Phone/今日。
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _repo = TodayRepository();
  TodayPayload? _data;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _meta = Color(0xFF64748B);
  static const _metaLight = Color(0xFF94A3B8);
  static const _hero = Color(0xFF1E3A8A);
  static const _heroLabel = Color(0xFF93C5FD);
  static const _heroMeta = Color(0xFFBFDBFE);
  static const _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool upgradeSeed = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var data = await _repo.fetch();
      // 种子稿自动升级为 AI 定制（未完成时）
      if (upgradeSeed &&
          data.lesson.isSeed &&
          data.lesson.status != 'done') {
        if (mounted) {
          setState(() {
            _data = data;
            _loading = false;
            _generating = true;
          });
        }
        try {
          data = await _repo.regenerate();
        } catch (e) {
          if (mounted) {
            AppToast.show(
              context,
              e is ApiException ? e.message : 'AI 生成失败，先读示例稿',
            );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _generating = false;
        _error = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  Future<void> _regenerateManual() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final data = await _repo.regenerate();
      if (!mounted) return;
      setState(() {
        _data = data;
        _generating = false;
      });
      AppToast.show(context, '已按你的画像生成新篇');
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      AppToast.show(
        context,
        e is ApiException ? e.message : '生成失败',
      );
    }
  }

  Future<void> _startReading() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const LessonArticlePage(),
      ),
    );
    if (result == true || mounted) {
      await _load();
    }
  }

  Future<void> _goReview() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ReviewPage(),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _load(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else
              RefreshIndicator(
                onRefresh: () => _load(upgradeSeed: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '今日',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _text,
                              height: 34 / 28,
                            ),
                          ),
                        ),
                        if (_data!.lesson.status != 'done')
                          TextButton(
                            onPressed: _generating ? null : _regenerateManual,
                            child: const Text(
                              '换一篇',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '连胜 ${_data!.streakDays} 天',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _meta,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '今日任务 ${_data!.tasksDone} / ${_data!.tasksTotal}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _metaLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _HeroCard(
                      lesson: _data!.lesson,
                      onStart: _startReading,
                    ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '到期生词 ${_data!.review.dueCount}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _data!.review.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _metaLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 41,
                              child: FilledButton(
                                onPressed: _data!.review.dueCount > 0
                                    ? _goReview
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  disabledBackgroundColor:
                                      const Color(0xFFBFDBFE),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '去复习',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),
                        Text(
                          _data!.plan.dayLine,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _meta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _data!.plan.metaLine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _metaLight,
                          ),
                        ),
                      ],
                    ),
                  ),
            if (_generating)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                  child: const Center(
                    child: _GeneratingCard(),
                  ),
                ),
              ),
          ],
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
            '正在按你的画像写今日文章…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '水平 · 职业 · 场景 · 词库',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.lesson, required this.onStart});

  final TodayLessonCard lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: _TodayPageState._hero,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.isPersonalized ? '今天的文章 · AI 定制' : '今天的文章',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _TodayPageState._heroLabel,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            lesson.theme.isNotEmpty ? lesson.theme : lesson.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 34 / 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            lesson.metaLine,
            style: const TextStyle(
              fontSize: 13,
              color: _TodayPageState._heroMeta,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _TodayPageState._hero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                lesson.ctaLabel,
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
