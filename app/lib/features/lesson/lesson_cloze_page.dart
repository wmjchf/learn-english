import 'package:flutter/material.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_repository.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/shell/main_shell.dart';

/// 闭眼回填（MVP：键盘拼写，提交后回今日）。
class LessonClozePage extends StatefulWidget {
  const LessonClozePage({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonClozePage> createState() => _LessonClozePageState();
}

class _LessonClozePageState extends State<LessonClozePage> {
  final _repo = LessonRepository();
  final _words = WordRepository();
  late final List<TextEditingController> _controllers;
  late final List<bool?> _results;
  bool _submitting = false;

  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF1A56DB);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE3E7EE);
  static const _ok = Color(0xFF16A34A);
  static const _bad = Color(0xFFDC2626);

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
    super.dispose();
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  Future<void> _submit() async {
    if (_submitting) return;
    final items = widget.lesson.content.cloze;
    var allOk = true;
    final wrongLemmas = <String>[];
    for (var i = 0; i < items.length; i++) {
      final ok = _norm(_controllers[i].text) == _norm(items[i].answer);
      _results[i] = ok;
      if (!ok) {
        allOk = false;
        final a = items[i].answer.trim().toLowerCase();
        if (a.isNotEmpty) wrongLemmas.add(a);
      }
    }
    setState(() {});

    if (!allOk) {
      // 错词入生词本，改对后再完课打卡
      for (final lemma in wrongLemmas) {
        try {
          await _words.markVocab(lemma, lessonId: widget.lesson.id);
        } catch (_) {}
      }
      if (!mounted) return;
      AppToast.show(context, '还有拼写不对，错词已进生词本');
      return;
    }

    setState(() => _submitting = true);
    var toast = '打卡成功';
    try {
      final result = await _repo.complete(
        widget.lesson.id,
        wrongLemmas: wrongLemmas,
      );
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
                    onTap: () => Navigator.of(context).pop(),
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
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final result = _results[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: result == null
                            ? _border
                            : (result ? _ok : _bad),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          textCapitalization: TextCapitalization.none,
                          decoration: InputDecoration(
                            hintText: '拼写英文',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
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
                  onPressed: items.isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '提交回填',
                    style: TextStyle(
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
