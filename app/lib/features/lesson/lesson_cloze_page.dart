import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/sentence_cloze.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 例句闭眼回填：一页一句；同句多词合填；输完继续；全对打卡。
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

  late final List<SentenceClozePageData> _pages;
  late final List<bool?> _results;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _foci;

  int _index = 0;
  bool _judged = false;
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

  SentenceClozePageData get _current => _pages[_index];

  @override
  void initState() {
    super.initState();
    _pages = buildSentenceClozePages(widget.lesson.content);
    _results = List<bool?>.filled(_pages.length, null);
    _controllers = [];
    _foci = [];
    _setupFieldsForPage(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foci.isNotEmpty) _foci.first.requestFocus();
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

  void _setupFieldsForPage(int pageIndex) {
    _disposeFields();
    if (_pages.isEmpty || pageIndex < 0 || pageIndex >= _pages.length) return;
    final n = _pages[pageIndex].blanks.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _foci = List.generate(n, (_) => FocusNode());
  }

  @override
  void dispose() {
    _disposeFields();
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
      });
    });
  }

  void _goNext() {
    if (_index >= _pages.length - 1) {
      _completeLesson();
      return;
    }
    for (final f in _foci) {
      f.unfocus();
    }
    setState(() {
      _index += 1;
      _judged = false;
      _advancing = false;
      _setupFieldsForPage(_index);
    });
    _refocusFirst();
  }

  Future<void> _onCta() async {
    if (_submitting || _advancing || _pages.isEmpty) return;

    if (_judged && _results[_index] == true) {
      _goNext();
      return;
    }

    if (_judged && _results[_index] == false) {
      if (!_allMatch()) {
        AppToast.show(context, '请先全部改对再继续');
        return;
      }
      setState(() => _results[_index] = true);
      _goNext();
      return;
    }

    final ok = _allMatch();
    if (ok) {
      _advancing = true;
      for (final f in _foci) {
        f.unfocus();
      }
      setState(() {
        _judged = true;
        _results[_index] = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      _goNext();
      return;
    }

    setState(() {
      _judged = true;
      _results[_index] = false;
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
    final last = _index >= _pages.length - 1;
    if (!_judged) return last ? '判定并打卡' : '继续';
    if (_results[_index] == true) return last ? '打卡' : '继续';
    return last ? '改对后打卡' : '改对后继续';
  }

  String _sentenceWithHints(SentenceClozePageData page) {
    // 先换成唯一占位，避免「________（提示）」里的 ________ 被下一次 replaceFirst 再次命中
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
    if (_pages.isEmpty) {
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
    final result = _results[_index];
    final showAnswer = _judged && result == false;
    final total = _pages.length;
    final multi = page.blanks.length > 1;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
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
                    'Day ${widget.lesson.dayIndex}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '例句回填',
                  style: TextStyle(
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
                  multi
                      ? '第 ${_index + 1} / $total 句 · 本句有 ${page.blanks.length} 个目标词，一起填'
                      : '第 ${_index + 1} / $total 句 · 根据例句拼出目标词',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ),
            if (_wrongTotal > 0)
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
                        ? '这句不对，正确答案已标出 · 已进待巩固\n改对后再继续'
                        : '已累计 $_wrongTotal 句错过 · 错词已进待巩固',
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
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
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
                                multi ? '同句合填' : '第 ${_index + 1} 句',
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
                        Text(
                          _sentenceWithHints(page),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _text,
                            height: 1.5,
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
                            key: ValueKey('cloze-$_index-$i'),
                            controller: _controllers[i],
                            focusNode: _foci[i],
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            readOnly:
                                _submitting || _advancing || result == true,
                            keyboardType: TextInputType.visiblePassword,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: i < page.blanks.length - 1
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onSubmitted: (_) {
                              if (i < page.blanks.length - 1) {
                                _foci[i + 1].requestFocus();
                              } else {
                                _onCta();
                              }
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
                                      TextButton(
                                        onPressed: () {
                                          _controllers[i].text =
                                              page.blanks[i].surface;
                                          _controllers[i].selection =
                                              TextSelection.collapsed(
                                            offset:
                                                page.blanks[i].surface.length,
                                          );
                                          _foci[i].requestFocus();
                                        },
                                        child: const Text(
                                          '填入',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: _bad,
                                          ),
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
