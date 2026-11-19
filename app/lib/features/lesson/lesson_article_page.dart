import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_cloze_page.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/lesson/widgets/lesson_generating_view.dart';
import 'package:app_starter/features/lesson/widgets/token_text.dart';
import 'package:app_starter/features/lesson/widgets/word_sheet.dart';
import 'package:app_starter/features/lesson/widgets/word_walkthrough_sheet.dart';
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
  final Map<String, GlobalKey> _lemmaKeys = {};
  final _scrollController = ScrollController();
  bool _walkingWords = false;
  /// 过词时底部单词卡约占屏高比例（与 walkthrough maxHeight 对齐）
  static const _walkSheetFraction = 0.58;

  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF7AC70C);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF8A94A6);
  static const _task = Color(0xFF4A5568);
  static const _sceneBg = Color(0xFFE8EFFD);
  static const _sceneBorder = Color(0xFFD9F99D);
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
    _scrollController.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (widget.lesson != null) {
      _rebuildLemmaKeys(widget.lesson!);
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
      _rebuildLemmaKeys(lesson);
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
      if (mounted) {
        _rebuildLemmaKeys(next);
        setState(() => _lesson = next);
      }
    } catch (_) {
      _rebuildLemmaKeys(lesson);
    }
  }

  void _rebuildLemmaKeys(Lesson lesson) {
    _lemmaKeys.clear();
    for (final t in lesson.content.article.enTokens) {
      final lemma = t.lemma.trim().toLowerCase();
      if (lemma.isEmpty) continue;
      if (t.isTarget || lesson.content.targetLemmas.any((e) => e.toLowerCase() == lemma)) {
        _lemmaKeys.putIfAbsent(lemma, GlobalKey.new);
      }
    }
    for (final raw in lesson.content.targetLemmas) {
      final lemma = raw.trim().toLowerCase();
      if (lemma.isEmpty) continue;
      _lemmaKeys.putIfAbsent(lemma, GlobalKey.new);
    }
  }

  void _scrollToLemma(String lemma) {
    final keyLemma = lemma.trim().toLowerCase();
    if (keyLemma.isEmpty) return;
    void apply() {
      if (!mounted) return;
      setState(() {
        _walkingWords = true;
        _zhExpanded = false;
        _focus
          ..clear()
          ..add(keyLemma);
      });
      // 等场景/中译收起、focus 重建后再量位置强制滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _forceScrollLemmaIntoPeek(keyLemma);
        });
      });
    }

    // 避开 bottom sheet 构建期同步 setState
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  /// 把目标词滚进底部单词卡上方的可见带（红框区域）。
  /// 不能只用 ensureVisible：词若已在整屏视口内（只是被 sheet 挡住）会不滚。
  void _forceScrollLemmaIntoPeek(String keyLemma) {
    if (!mounted || !_scrollController.hasClients) return;
    final tokenCtx = _lemmaKeys[keyLemma]?.currentContext;
    if (tokenCtx == null) return;

    final tokenBox = tokenCtx.findRenderObject();
    if (tokenBox is! RenderBox || !tokenBox.hasSize) return;

    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    // 单词卡上方可见带：词放在中间偏上，上下都能露出一句语境
    final peekTop = media.padding.top + 12;
    final peekBottom = screenH * (1 - _walkSheetFraction) - 8;
    final peekH = (peekBottom - peekTop).clamp(80.0, screenH);
    final desiredGlobalY = peekTop + peekH * 0.38;

    final tokenTopGlobal = tokenBox.localToGlobal(Offset.zero).dy;
    final tokenH = tokenBox.size.height;
    final tokenBottomGlobal = tokenTopGlobal + tokenH;

    // 已在可见带内且上下还有余量，就不动，避免滚太狠
    final hasRoomAbove = tokenTopGlobal >= peekTop + 28;
    final hasRoomBelow = tokenBottomGlobal <= peekBottom - 28;
    if (hasRoomAbove && hasRoomBelow) return;

    final delta = tokenTopGlobal - desiredGlobalY;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    if ((target - _scrollController.offset).abs() < 2) return;

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _endWalkthroughFocus() {
    if (!mounted) return;
    setState(() {
      _walkingWords = false;
      _zhExpanded = true;
      _focus
        ..clear()
        ..addAll({
          if (widget.focusLemma != null && widget.focusLemma!.trim().isNotEmpty)
            widget.focusLemma!.trim().toLowerCase(),
        });
    });
    // 回到顶部，场景导读重新可见
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
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
      onKnow: _markKnow,
      onUnknownHighlight: _markUnknown,
    );
  }

  void _markKnow(String lemma, {String? gloss}) {
    final lesson = _lesson;
    if (lesson == null) return;
    final key = lemma.trim().toLowerCase();
    setState(() {
      _known.add(key);
      _tempHl.remove(key);
    });
    _words.markKnown(key, lessonId: lesson.id).catchError((Object e) {
      if (mounted) {
        AppToast.show(
          context,
          e is ApiException ? e.message : '标记失败',
        );
      }
      return null;
    });
  }

  void _markUnknown(String lemma, {String? gloss, bool toast = true}) {
    final lesson = _lesson;
    if (lesson == null) return;
    final key = lemma.trim().toLowerCase();
    setState(() {
      _tempHl.add(key);
    });
    final resolved = (gloss != null && gloss.isNotEmpty)
        ? gloss
        : lesson.content.defFor(key)?.gloss;
    _words
        .markVocab(key, lessonId: lesson.id, gloss: resolved)
        .then((_) {
      if (toast && mounted) AppToast.show(context, '已加入生词本');
    }).catchError((Object e) {
      if (mounted) {
        AppToast.show(
          context,
          e is ApiException ? e.message : '加入失败',
        );
      }
      return null;
    });
  }

  Future<void> _goWordWalkthrough() async {
    final lesson = _lesson;
    if (lesson == null) return;
    if (orderedTargetTokens(lesson.content).isEmpty) {
      AppToast.show(context, '暂无目标词');
      return;
    }
    final completed = await showLessonWordWalkthrough(
      context: context,
      content: lesson.content,
      tts: _tts,
      lessonId: lesson.id,
      onKnow: _markKnow,
      onUnknownHighlight: (lemma, {String? gloss}) =>
          _markUnknown(lemma, gloss: gloss, toast: false),
      onLemmaFocused: _scrollToLemma,
    );
    if (!mounted) return;
    // 无论过完还是下滑关闭，都恢复场景导读等
    _endWalkthroughFocus();
    if (completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goCloze();
      });
    }
  }

  void _goCloze() {
    final lesson = _lesson;
    if (lesson == null) return;
    if (lesson.content.cloze.isEmpty) {
      AppToast.show(context, '单词已过完');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonClozePage(lesson: lesson),
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            // 过词时垫高底部，才能把靠后的词滚进单词卡上方的可见带
            padding: EdgeInsets.fromLTRB(
              14,
              2,
              14,
              _walkingWords
                  ? MediaQuery.sizeOf(context).height * _walkSheetFraction + 48
                  : 12,
            ),
            children: [
              _Header(
                dayIndex: lesson.dayIndex,
                onBack: _back,
              ),
              if (!_walkingWords) ...[
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _text,
                          height: 22 / 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.listLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 18 / 13,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                          height: 18 / 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scene.roleBackground,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _text,
                          height: 20 / 14,
                        ),
                      ),
                      if (scene.tasksDisplay.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          scene.tasksDisplay,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _task,
                            height: 18 / 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else
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
                      '📖 短文：${article.titleDisplay(fallbackZh: lesson.theme)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 20 / 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TokenText(
                      tokens: article.enTokens,
                      onTap: _onToken,
                      knownLemmas: _known,
                      tempHighlightLemmas: _tempHl,
                      focusLemmas: _focus,
                      lemmaKeys: _lemmaKeys,
                      fontSize: 17,
                    ),
                    if (article.zhDisplay.isNotEmpty && !_walkingWords) ...[
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _blue,
                                      height: 18 / 13,
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
                                      fontSize: 13,
                                      color: _muted,
                                      height: 18 / 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_zhExpanded) ...[
                              const SizedBox(height: 6),
                              ZhMarkedText(
                                text: article.zhDisplay,
                                fontSize: 16,
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
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: _goWordWalkthrough,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                '我已看完，过一遍单词',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
                    color: Color(0xFF7AC70C),
                    height: 18 / 20,
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '返回',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7AC70C),
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
