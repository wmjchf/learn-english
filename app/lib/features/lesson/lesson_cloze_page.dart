import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 闭眼回填：全对打卡回今日；有错则留页、揭晓答案、错词进待巩固。
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
  late final List<TextEditingController> _controllers;
  late final List<bool?> _results;
  /// 是否已至少提交过一次（用于展示正确答案）
  bool _revealed = false;
  int _wrongCount = 0;
  bool _submitting = false;

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

  @override
  void initState() {
    super.initState();
    final n = widget.lesson.content.cloze.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _results = List.filled(n, null);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _tts.dispose();
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  Future<void> _submit() async {
    if (_submitting) return;
    final items = widget.lesson.content.cloze;
    var allOk = true;
    var wrong = 0;
    final wrongLemmas = <String>[];
    for (var i = 0; i < items.length; i++) {
      final ok = _norm(_controllers[i].text) == _norm(items[i].answer);
      _results[i] = ok;
      if (!ok) {
        allOk = false;
        wrong += 1;
        final a = items[i].answer.trim().toLowerCase();
        if (a.isNotEmpty) wrongLemmas.add(a);
      }
    }
    setState(() {
      _revealed = true;
      _wrongCount = wrong;
    });

    if (!allOk) {
      for (final lemma in wrongLemmas) {
        try {
          final gloss = widget.lesson.content.defFor(lemma)?.gloss;
          await _words.markVocab(
            lemma,
            lessonId: widget.lesson.id,
            gloss: gloss,
          );
        } catch (_) {}
      }
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final items = widget.lesson.content.cloze;
    final ctaLabel = _submitting
        ? '提交中…'
        : (_revealed && _wrongCount > 0 ? '改完再提交' : '提交回填');

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
                    onTap: _submitting ? null : () => Navigator.of(context).pop(),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '遮住上文，根据语境拼出目标词。',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            ),
            if (_revealed && _wrongCount > 0)
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
                    '$_wrongCount 题不对，正确答案已标出 · 错词已进待巩固\n改对后再提交即可打卡',
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
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final result = _results[i];
                  final showAnswer = _revealed && result == false;
                  return Container(
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
                                '第 ${i + 1} 题',
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
                        const SizedBox(height: 8),
                        Text(
                          item.before,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
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
                          controller: _controllers[i],
                          autocorrect: false,
                          enableSuggestions: false,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.none,
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
                                    _controllers[i].text = item.answer;
                                    _controllers[i].selection =
                                        TextSelection.collapsed(
                                      offset: item.answer.length,
                                    );
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
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: items.isEmpty || _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    ctaLabel,
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
