import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/sentence_cloze.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 例句闭眼回填：一页一句；同句多词合填。
/// 填错先展示正确答案再进下一题；本轮走完后只刷错题，直到全对再打卡。
class LessonClozePage extends StatefulWidget {
  const LessonClozePage({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonClozePage> createState() => _LessonClozePageState();
}

class _LessonClozePageState extends State<LessonClozePage> {
  final _repo = LessonRepository();
  final _words = WordRepository();
  final _tts = LessonTts();

  late final List<SentenceClozePageData> _bank;
  late List<SentenceClozePageData> _queue;
  final List<SentenceClozePageData> _missedThisRound = [];

  late List<TextEditingController> _controllers;
  late List<FocusNode> _foci;
  final _scroll = ScrollController();
  final _questionKey = GlobalKey();

  int _index = 0;
  int _round = 1;
  bool _judged = false;
  bool? _pageOk;
  int _wrongTotal = 0;
  bool _submitting = false;
  bool _advancing = false;

  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF7AC70C);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE3E7EE);
  static const _ok = Color(0xFF16A34A);
  static const _okSoft = Color(0xFFDCFCE7);
  static const _bad = Color(0xFFDC2626);
  static const _badSoft = Color(0xFFFEE2E2);
  static const _warnSoft = Color(0xFFFEF3C7);
  static const _warnText = Color(0xFFB45309);

  SentenceClozePageData get _current => _queue[_index];

  bool get _isRetryRound => _round > 1;

  @override
  void initState() {
    super.initState();
    _bank = buildSentenceClozePages(widget.lesson.content);
    _queue = List<SentenceClozePageData>.from(_bank);
    _controllers = [];
    _foci = [];
    _setupFieldsForPage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _foci.isEmpty) return;
      _foci.first.requestFocus();
      _ensureQuestionVisible();
    });
  }

  void _disposeFields() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _foci) {
      f.dispose();
    }
    _controllers = [];
    _foci = [];
  }

  void _setupFieldsForPage() {
    _disposeFields();
    if (_queue.isEmpty || _index < 0 || _index >= _queue.length) return;
    final n = _queue[_index].blanks.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _foci = List.generate(n, (_) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) _ensureQuestionVisible();
      });
      return node;
    });
  }

  /// 键盘弹出后把例句滚到可视区顶部，避免挡住题目。
  void _ensureQuestionVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      final ctx = _questionKey.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.02,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _disposeFields();
    _scroll.dispose();
    _tts.dispose();
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool _blankMatches(int i) {
    final blank = _current.blanks[i];
    final typed = _norm(_controllers[i].text);
    if (typed.isEmpty) return false;
    return typed == _norm(blank.answer) || typed == _norm(blank.surface);
  }

  bool _allMatch() {
    for (var i = 0; i < _current.blanks.length; i++) {
      if (!_blankMatches(i)) return false;
    }
    return true;
  }

  bool _allFilled() {
    for (final c in _controllers) {
      if (_norm(c.text).isEmpty) return false;
    }
    return true;
  }

  /// 多空未填完时：跳到下一空 / 第一个空缺，不校验。
  bool _focusNextBlankIfNeeded() {
    if (_current.blanks.length <= 1 || _allFilled()) return false;
    final focused = _foci.indexWhere((f) => f.hasFocus);
    var target = -1;
    if (focused >= 0 && focused < _foci.length - 1) {
      target = focused + 1;
    }
    if (target < 0 || _norm(_controllers[target].text).isNotEmpty) {
      target = -1;
      for (var i = 0; i < _controllers.length; i++) {
        if (_norm(_controllers[i].text).isEmpty) {
          target = i;
          break;
        }
      }
    }
    if (target < 0 || target >= _foci.length) return false;
    _foci[target].requestFocus();
    _ensureQuestionVisible();
    return true;
  }

  Future<void> _markWrongVocab(String answer) async {
    final lemma = answer.trim().toLowerCase();
    if (lemma.isEmpty) return;
    try {
      final gloss = widget.lesson.content.defFor(lemma)?.gloss;
      await _words.markVocab(
        lemma,
        lessonId: widget.lesson.id,
        gloss: gloss,
      );
    } catch (_) {}
  }

  Future<void> _completeLesson() async {
    setState(() => _submitting = true);
    var toast = '打卡成功';
    try {
      final result = await _repo.complete(widget.lesson.id);
      if (result.already) {
        toast = '今日已打卡';
      } else if (result.streakDelta > 0) {
        final n = result.currentStreak;
        toast = n != null ? '打卡成功 · 连胜 $n 天' : '打卡成功 · 连胜 +1';
      }
    } catch (_) {}
    if (!mounted) return;
    AppToast.show(context, toast);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _refocusFirst() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _foci.isEmpty) return;
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted || _foci.isEmpty) return;
        if (!_foci.first.hasFocus) _foci.first.requestFocus();
        _ensureQuestionVisible();
      });
    });
  }

  void _startRetryRound() {
    final next = List<SentenceClozePageData>.from(_missedThisRound);
    _missedThisRound.clear();
    for (final f in _foci) {
      f.unfocus();
    }
    setState(() {
      _queue = next;
      _index = 0;
      _round += 1;
      _judged = false;
      _pageOk = null;
      _advancing = false;
      _setupFieldsForPage();
    });
    _refocusFirst();
    if (mounted) {
      AppToast.show(context, '本轮错 ${_queue.length} 句，开始巩固');
    }
  }

  void _goNext() {
    final last = _index >= _queue.length - 1;
    if (last) {
      if (_missedThisRound.isNotEmpty) {
        _startRetryRound();
        return;
      }
      _completeLesson();
      return;
    }
    for (final f in _foci) {
      f.unfocus();
    }
    setState(() {
      _index += 1;
      _judged = false;
      _pageOk = null;
      _advancing = false;
      _setupFieldsForPage();
    });
    _refocusFirst();
  }

  Future<void> _onCta() async {
    if (_submitting || _advancing || _queue.isEmpty) return;

    // 已判定：对 / 错都直接进下一题（错题不要求当场改对）
    if (_judged) {
      _goNext();
      return;
    }

    // 同句多空：填完当前词先跳下一空，全部填完再校验
    if (_focusNextBlankIfNeeded()) return;

    final ok = _allMatch();
    if (ok) {
      _advancing = true;
      for (final f in _foci) {
        f.unfocus();
      }
      setState(() {
        _judged = true;
        _pageOk = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _goNext();
      return;
    }

    // 错：展示答案，记入本轮错题，点继续再往后
    if (!_missedThisRound.contains(_current)) {
      _missedThisRound.add(_current);
    }
    setState(() {
      _judged = true;
      _pageOk = false;
      _wrongTotal += 1;
    });
    for (var i = 0; i < _current.blanks.length; i++) {
      if (!_blankMatches(i)) {
        await _markWrongVocab(_current.blanks[i].answer);
      }
    }
  }

  String get _ctaLabel {
    if (_submitting) return '提交中…';
    final last = _index >= _queue.length - 1;
    final hasRetry = _missedThisRound.isNotEmpty;
    if (!_judged) {
      if (last && !hasRetry) return '判定并打卡';
      if (last && hasRetry) return '判定后刷错题';
      return '继续';
    }
    if (_pageOk == true) {
      if (last && !hasRetry) return '打卡';
      if (last && hasRetry) return '去刷错题';
      return '继续';
    }
    // 错了已展示答案
    if (last && hasRetry) return '去刷错题';
    if (last && !hasRetry) return '打卡';
    return '继续';
  }

  String _sentenceWithHints(SentenceClozePageData page) {
    var s = page.sentenceBlanked;
    for (var i = 0; i < page.blanks.length; i++) {
      s = s.replaceFirst('________', '⟦B$i⟧');
    }
    for (var i = 0; i < page.blanks.length; i++) {
      final hint = page.blanks[i].hintZh.trim();
      final shown = hint.isEmpty ? '________' : '________（$hint）';
      s = s.replaceFirst('⟦B$i⟧', shown);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (_bank.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('暂无回填题，返回'),
            ),
          ),
        ),
      );
    }

    final page = _current;
    final result = _pageOk;
    final showAnswer = _judged && result == false;
    final total = _queue.length;
    final multi = page.blanks.length > 1;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final progressLine = _isRetryRound
        ? (multi
            ? '巩固 ${_index + 1} / $total · 本句 ${page.blanks.length} 个空'
            : '巩固 ${_index + 1} / $total · 根据例句再拼一遍')
        : (multi
            ? '第 ${_index + 1} / $total 句 · 本句有 ${page.blanks.length} 个目标词，一起填'
            : '第 ${_index + 1} / $total 句 · 根据例句拼出目标词');

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, keyboardOpen ? 4 : 10, 14, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Row(
                      children: [
                        Text(
                          '‹',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7AC70C),
                          ),
                        ),
                        SizedBox(width: 2),
                        Text(
                          '返回',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7AC70C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    keyboardOpen
                        ? '${_isRetryRound ? '巩固' : '回填'} ${_index + 1}/$total'
                        : 'Day ${widget.lesson.dayIndex}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (!keyboardOpen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isRetryRound ? '错题巩固' : '例句回填',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    progressLine,
                    style: const TextStyle(fontSize: 13, color: _muted),
                  ),
                ),
              ),
            ],
            if (!keyboardOpen && (_wrongTotal > 0 || showAnswer))
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _warnSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    showAnswer
                        ? '这句不对，正确答案已标出 · 点继续；本轮结束后再刷错题'
                        : (_isRetryRound
                            ? '错题巩固中 · 累计错过 $_wrongTotal 句'
                            : '已累计 $_wrongTotal 句错过 · 本轮结束后再刷错题'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _warnText,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: result == null
                            ? _border
                            : (result ? _ok : _bad),
                        width: result == null ? 1 : 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                multi
                                    ? '同句合填'
                                    : (_isRetryRound
                                        ? '巩固 ${_index + 1}'
                                        : '第 ${_index + 1} 句'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                            ),
                            if (result == true)
                              const Text(
                                '正确',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _ok,
                                ),
                              ),
                            if (result == false)
                              const Text(
                                '不正确',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _bad,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: _questionKey,
                          child: Text(
                            _sentenceWithHints(page),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _text,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < page.blanks.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          if (multi)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '空格 ${i + 1} · ${page.blanks[i].hintZh}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                            ),
                          TextField(
                            key: ValueKey('cloze-$_round-$_index-$i'),
                            controller: _controllers[i],
                            focusNode: _foci[i],
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            readOnly: _submitting || _advancing || _judged,
                            keyboardType: TextInputType.visiblePassword,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: i < page.blanks.length - 1
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onTap: _ensureQuestionVisible,
                            onSubmitted: (_) {
                              if (_judged) {
                                _onCta();
                                return;
                              }
                              // 多空：键盘继续 / next → 下一空；最后一空才校验
                              if (i < page.blanks.length - 1) {
                                _foci[i + 1].requestFocus();
                                _ensureQuestionVisible();
                                return;
                              }
                              _onCta();
                            },
                            decoration: InputDecoration(
                              hintText: multi ? '拼写第 ${i + 1} 个词' : '拼写英文',
                              filled: true,
                              fillColor: result == true
                                  ? _okSoft
                                  : result == false && !_blankMatches(i)
                                      ? _badSoft
                                      : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: result == null
                                      ? _border
                                      : (result ? _ok : _bad),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: result == null
                                      ? _border
                                      : (result ? _ok : _bad),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: result == false ? _bad : _blue,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                        if (showAnswer) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            decoration: BoxDecoration(
                              color: _badSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < page.blanks.length; i++)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: _bad,
                                              height: 1.35,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: multi
                                                    ? '空格 ${i + 1}：'
                                                    : '正确答案：',
                                              ),
                                              TextSpan(
                                                text: page.blanks[i].surface,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '朗读',
                                        onPressed: () => _tts
                                            .speakWord(page.blanks[i].surface),
                                        icon: const Icon(
                                          Icons.volume_up_rounded,
                                          color: _bad,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 留白：键盘升起后仍能把例句滚到输入框上方
                  SizedBox(height: keyboardOpen ? 160 : 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: (_submitting || _advancing) ? null : _onCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _ctaLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
