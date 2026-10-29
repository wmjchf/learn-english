import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_dialog_page.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/lesson/widgets/lesson_generating_view.dart';
import 'package:app_starter/features/lesson/widgets/lesson_listen_bar.dart';
import 'package:app_starter/features/lesson/widgets/token_text.dart';
import 'package:app_starter/features/lesson/widgets/word_sheet.dart';
import 'package:app_starter/features/lesson/widgets/zh_marked_text.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 日课短文：对齐 Figma Phone/日课短文。
class LessonArticlePage extends StatefulWidget {
  const LessonArticlePage({
    super.key,
    this.lesson,
    this.lessonId,
    this.firstDay = false,
    this.focusLemma,
  });

  final Lesson? lesson;

  /// 已有日课 id（如从今日进入）：直接拉取，不走「生成中」页。
  final int? lessonId;

  /// 画像完成后进第一篇：用生成中界面（可能触发后端首次成文）。
  final bool firstDay;

  /// 生词本跳转：在文中用特殊样式标出该词。
  final String? focusLemma;

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
  late final Set<String> _focus = {
    if (widget.focusLemma != null && widget.focusLemma!.trim().isNotEmpty)
      widget.focusLemma!.trim().toLowerCase(),
  };

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
      final Lesson lesson;
      if (widget.lessonId != null) {
        lesson = await _repo.getById(widget.lessonId!);
      } else {
        // 无 id：拉今日（首日可能现场生成）
        lesson = await _repo.today();
      }
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
    _maybeJumpDialogForFocus(_lesson ?? lesson);
  }

  bool _lemmaInArticle(Lesson lesson, String lemma) {
    final key = lemma.toLowerCase();
    return lesson.content.article.enTokens
        .any((t) => t.lemma.toLowerCase() == key);
  }

  bool _lemmaInDialog(Lesson lesson, String lemma) {
    final key = lemma.toLowerCase();
    for (final turn in lesson.content.dialog.turns) {
      if (turn.enTokens.any((t) => t.lemma.toLowerCase() == key)) {
        return true;
      }
    }
    return false;
  }

  /// 生词本跳转：词只在对话里时，自动进入对话页并高亮。
  void _maybeJumpDialogForFocus(Lesson lesson) {
    final focus = widget.focusLemma?.trim();
    if (focus == null || focus.isEmpty) return;
    if (_lemmaInArticle(lesson, focus)) return;
    if (!_lemmaInDialog(lesson, focus)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _goDialog();
    });
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

  void _goDialog() {
    final lesson = _lesson;
    if (lesson == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonDialogPage(
          lesson: lesson,
          knownLemmas: _known,
          tempHighlightLemmas: _tempHl,
          focusLemma: widget.focusLemma,
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
      // 仅首日成文用完整生成页；今日「开始阅读」只是打开已有文章
      if (widget.firstDay) {
        return const Scaffold(
          backgroundColor: Color(0xFFF8FAFC),
          body: LessonGeneratingView(
            title: '正在写你的 Day 1',
            subtitle: '按水平 · 职业 · 场景 · 词库定制第一篇',
          ),
        );
      }
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                      scene.title.contains('场景导入') &&
                              !scene.title.contains('导读')
                          ? scene.title.replaceFirst(
                              '场景导入',
                              '场景导入（导读）',
                            )
                          : scene.title,
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
                    const SizedBox(height: 8),
                    TokenText(
                      tokens: article.enTokens,
                      onTap: _onToken,
                      knownLemmas: _known,
                      tempHighlightLemmas: _tempHl,
                      focusLemmas: _focus,
                    ),
                    if (article.zhDisplay.isNotEmpty) ...[
                      const SizedBox(height: 10),
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
                                    '中文翻译',
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
                              const SizedBox(height: 6),
                              ZhMarkedText(
                                text: article.zhDisplay,
                                extraHighlights: glossHighlightPhrases(
                                  lesson.content.targetLemmas.map(
                                    (l) =>
                                        lesson.content.defFor(l)?.gloss ?? '',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
              LessonListenBar(
                tts: _tts,
                text: article.enPlain,
                idleLabel: '听一遍短文',
                accent: _blue,
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
