import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 闭眼回填：一题一判；全对打卡回今日；错题揭晓并进待巩固，改对后再进下一题。
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
  final _focus = FocusNode();
  late final TextEditingController _controller;
  late final List<bool?> _results;

  int _index = 0;
  /// 当前题是否已判定过（错题会揭晓答案）
  bool _judged = false;
  int _wrongTotal = 0;
  bool _submitting = false;
  /// 答对后自动切题中，防止连点
  bool _advancing = false;

  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF1A56DB);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE3E7EE);
  static const _ok = Color(0xFF16A34A);
  static const _okSoft = Color(0xFFDCFCE7);
  static const _bad = Color(0xFFDC2626);
  static const _badSoft = Color(0xFFFEE2E2);
  static const _warnSoft = Color(0xFFFEF3C7);
  static const _warnText = Color(0xFFB45309);

  List<ClozeItem> get _items => widget.lesson.content.cloze;

  ClozeItem get _current => _items[_index];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _results = List.filled(_items.length, null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _tts.dispose();
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

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
    } catch (_) {
      // 本地已通过拼写，完课失败不挡回今日
    }
    if (!mounted) return;
    AppToast.show(context, toast);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _refocusInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 再等一拍：部分 iOS / 模拟器在禁用过输入框后，需要重建连接才能打字
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        if (!_focus.hasFocus) _focus.requestFocus();
      });
    });
  }

  void _goNext() {
    if (_index >= _items.length - 1) {
      _completeLesson();
      return;
    }
    // 先断掉旧 IME 连接，避免下一题「键盘在动、框不进字」
    _focus.unfocus();
    setState(() {
      _index += 1;
      _judged = false;
      _advancing = false;
      _controller.value = TextEditingValue.empty;
    });
    _refocusInput();
  }

  Future<void> _onCta() async {
    if (_submitting || _advancing || _items.isEmpty) return;

    // 已判对：进下一题 / 打卡
    if (_judged && _results[_index] == true) {
      _goNext();
      return;
    }

    // 已判错：必须改对才能继续
    if (_judged && _results[_index] == false) {
      final ok = _norm(_controller.text) == _norm(_current.answer);
      if (!ok) {
        AppToast.show(context, '请先改对再继续');
        return;
      }
      setState(() {
        _results[_index] = true;
      });
      _goNext();
      return;
    }

    // 首次判定当前题
    final ok = _norm(_controller.text) == _norm(_current.answer);
    if (ok) {
      // 先失焦再标「正确」，避免 enabled/readOnly 切换打断 iOS 输入连接
      _advancing = true;
      _focus.unfocus();
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
    await _markWrongVocab(_current.answer);
  }

  String get _ctaLabel {
    if (_submitting) return '提交中…';
    if (!_judged) {
      return _index >= _items.length - 1 ? '判定并打卡' : '判定';
    }
    if (_results[_index] == true) {
      return _index >= _items.length - 1 ? '打卡' : '下一题';
    }
    return _index >= _items.length - 1 ? '改对后打卡' : '改对后继续';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
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

    final item = _current;
    final result = _results[_index];
    final showAnswer = _judged && result == false;
    final total = _items.length;

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
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 2),
                        Text(
                          '返回',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
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
                  '闭眼回填',
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
                  '第 ${_index + 1} / $total 题 · 遮住上文，根据语境拼出目标词。',
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
                        ? '这题不对，正确答案已标出 · 已进待巩固\n改对后再继续'
                        : '已累计 $_wrongTotal 题错过 · 错词已进待巩固',
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
                                '第 ${_index + 1} 题',
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
                        if (item.before.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.before,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          item.sentence.replaceAll(
                            '________',
                            '________（${item.hintZh}）',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _text,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          // 每题重建，避免上一题禁用输入后 IME 粘连
                          key: ValueKey('cloze-field-$_index'),
                          controller: _controller,
                          focusNode: _focus,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          // 勿用 enabled:false：iOS 上易导致键盘还在、文字进不了框
                          readOnly: _submitting || _advancing || result == true,
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.none,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _onCta(),
                          decoration: InputDecoration(
                            hintText: '拼写英文',
                            filled: true,
                            fillColor: result == true
                                ? _okSoft
                                : result == false
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
                        if (showAnswer) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            decoration: BoxDecoration(
                              color: _badSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
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
                                        const TextSpan(text: '正确答案：'),
                                        TextSpan(
                                          text: item.answer,
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
                                  onPressed: () => _tts.speakWord(item.answer),
                                  icon: const Icon(
                                    Icons.volume_up_rounded,
                                    color: _bad,
                                    size: 22,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _controller.text = item.answer;
                                    _controller.selection =
                                        TextSelection.collapsed(
                                      offset: item.answer.length,
                                    );
                                    _focus.requestFocus();
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
                          ),
                        ],
                        if (item.after.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.after,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              height: 1.4,
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
