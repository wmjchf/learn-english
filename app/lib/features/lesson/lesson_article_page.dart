import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_dialog_page.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/lesson/widgets/lesson_generating_view.dart';
import 'package:app_starter/features/lesson/widgets/token_text.dart';
import 'package:app_starter/features/lesson/widgets/word_sheet.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 日课短文：对齐 Figma Phone/日课短文。
class LessonArticlePage extends StatefulWidget {
  const LessonArticlePage({super.key, this.lesson, this.firstDay = false});

  final Lesson? lesson;

  /// 画像完成后进第一篇：用更完整的生成中界面。
  final bool firstDay;

  @override
  State<LessonArticlePage> createState() => _LessonArticlePageState();
}

class _LessonArticlePageState extends State<LessonArticlePage> {
  final _repo = LessonRepository();
  final _words = WordRepository();
  final _tts = LessonTts();

  Lesson? _lesson;
  bool _loading = true;
  String? _error;
  bool _zhExpanded = true;
  final Set<String> _known = {};
  final Set<String> _tempHl = {};

  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF1A56DB);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF8A94A6);
  static const _task = Color(0xFF4A5568);
  static const _sceneBg = Color(0xFFE8EFFD);
  static const _sceneBorder = Color(0xFFBFDBFE);
  static const _cardBg = Color(0xFFF8F9FC);
  static const _cardBorder = Color(0xFFE3E7EE);
  static const _zhBg = Color(0xFFF0F3F9);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (widget.lesson != null) {
      setState(() {
        _lesson = widget.lesson;
        _loading = false;
      });
      _openIfNeeded(widget.lesson!);
      return;
    }
    try {
      final lesson = await _repo.today();
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _loading = false;
      });
      await _openIfNeeded(lesson);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载日课失败';
      });
    }
  }

  Future<void> _openIfNeeded(Lesson lesson) async {
    // 始终打 open：unread→reading，并同步目标词进「学习中」
    try {
      final next = await _repo.open(lesson.id);
      if (mounted) setState(() => _lesson = next);
    } catch (_) {}
  }

  void _onToken(LessonToken token) {
    final lesson = _lesson;
    if (lesson == null) return;
    showWordSheet(
      context: context,
      token: token,
      content: lesson.content,
      tts: _tts,
      lessonId: lesson.id,
      onKnow: (lemma, {String? gloss}) async {
        setState(() {
          _known.add(lemma);
          _tempHl.remove(lemma);
        });
        try {
          await _words.markKnown(lemma, lessonId: lesson.id);
        } catch (e) {
          if (mounted) {
            AppToast.show(
              context,
              e is ApiException ? e.message : '标记失败',
            );
          }
        }
      },
      onUnknownHighlight: (lemma, {String? gloss}) async {
        setState(() {
          _tempHl.add(lemma);
        });
        final resolved =
            (gloss != null && gloss.isNotEmpty)
                ? gloss
                : lesson.content.defFor(lemma)?.gloss;
        try {
          await _words.markVocab(
            lemma,
            lessonId: lesson.id,
            gloss: resolved,
          );
          if (mounted) AppToast.show(context, '已加入生词本');
        } catch (e) {
          if (mounted) {
            AppToast.show(
              context,
              e is ApiException ? e.message : '加入失败',
            );
          }
        }
      },
    );
  }

  Future<void> _listenArticle() async {
    final plain = _lesson?.content.article.enPlain ?? '';
    await _tts.speak(plain);
  }

  void _goDialog() {
    final lesson = _lesson;
    if (lesson == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonDialogPage(
          lesson: lesson,
          knownLemmas: _known,
          tempHighlightLemmas: _tempHl,
          onKnownChanged: (s) => setState(() {
            _known
              ..clear()
              ..addAll(s);
          }),
          onTempChanged: (s) => setState(() {
            _tempHl
              ..clear()
              ..addAll(s);
          }),
        ),
      ),
    );
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: LessonGeneratingView(
          title: widget.firstDay || widget.lesson == null
              ? '正在写你的 Day 1'
              : '正在准备今日文章',
          subtitle: widget.firstDay || widget.lesson == null
              ? '按水平 · 职业 · 场景 · 词库定制第一篇'
              : '按你的画像生成今日短文与回填',
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _error != null
            ? _ErrorBody(
                message: _error!,
                onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _boot();
                },
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final lesson = _lesson!;
    final scene = lesson.content.scene;
    final article = lesson.content.article;
    final dialog = lesson.content.dialog;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            children: [
              _Header(
                dayIndex: lesson.dayIndex,
                onBack: _back,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Day ${lesson.dayIndex}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lesson.theme,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 19 / 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                lesson.listLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  height: 15 / 11,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _sceneBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _sceneBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                        height: 15 / 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.roleBackground,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _text,
                        height: 16 / 12,
                      ),
                    ),
                    if (scene.tasksDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        scene.tasksDisplay,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _task,
                          height: 15 / 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📖 短文：${article.title}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 18 / 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _zhBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '中文导读（先读）',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _blue,
                                    height: 15 / 11,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(
                                  () => _zhExpanded = !_zhExpanded,
                                ),
                                child: Text(
                                  _zhExpanded ? '收起' : '展开',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                    height: 15 / 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_zhExpanded) ...[
                            const SizedBox(height: 4),
                            Text(
                              article.zhLead,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF555555),
                                height: 15 / 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TokenText(
                      tokens: article.enTokens,
                      onTap: _onToken,
                      knownLemmas: _known,
                      tempHighlightLemmas: _tempHl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _goDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Text(
                      "💬 下一段：对话 ${dialog.title} ›",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _blue,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 41,
                child: FilledButton(
                  onPressed: _listenArticle,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '听一遍短文',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 43,
                child: OutlinedButton(
                  onPressed: _goDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '进入对话',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.dayIndex, required this.onBack});

  final int dayIndex;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Row(
              children: [
                Text(
                  '‹',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                    height: 18 / 20,
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2563EB),
                    height: 20 / 16,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Day $dayIndex',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
