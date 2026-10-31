import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_cloze_page.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/lesson/widgets/lesson_listen_bar.dart';
import 'package:app_starter/features/lesson/widgets/token_text.dart';
import 'package:app_starter/features/lesson/widgets/word_sheet.dart';
import 'package:app_starter/features/lesson/widgets/zh_marked_text.dart';

/// 日课对话：对齐 Figma Phone/日课对话。
class LessonDialogPage extends StatefulWidget {
  const LessonDialogPage({
    super.key,
    required this.lesson,
    required this.knownLemmas,
    required this.tempHighlightLemmas,
    required this.onKnownChanged,
    required this.onTempChanged,
    this.focusLemma,
  });

  final Lesson lesson;
  final Set<String> knownLemmas;
  final Set<String> tempHighlightLemmas;
  final ValueChanged<Set<String>> onKnownChanged;
  final ValueChanged<Set<String>> onTempChanged;
  /// 生词本跳转：在对话里用特殊样式标出该词。
  final String? focusLemma;

  @override
  State<LessonDialogPage> createState() => _LessonDialogPageState();
}

class _LessonDialogPageState extends State<LessonDialogPage> {
  final _tts = LessonTts();
  final _words = WordRepository();
  late Set<String> _known;
  late Set<String> _tempHl;
  late final Set<String> _focus = {
    if (widget.focusLemma != null && widget.focusLemma!.trim().isNotEmpty)
      widget.focusLemma!.trim().toLowerCase(),
  };
  static const _bg = Color(0xFFF5F6F8);
  static const _blue = Color(0xFF1A56DB);
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF8A94A6);
  static const _cardBorder = Color(0xFFE3E7EE);
  static const _dialogBg = Color(0xFFF2F7FF);
  static const _dialogBorder = Color(0xFFBFDBFE);

  @override
  void initState() {
    super.initState();
    _known = {...widget.knownLemmas};
    _tempHl = {...widget.tempHighlightLemmas};
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _syncKnown() => widget.onKnownChanged({..._known});
  void _syncTemp() => widget.onTempChanged({..._tempHl});

  void _onToken(LessonToken token) {
    final lesson = widget.lesson;
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
        _syncKnown();
        _syncTemp();
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
        setState(() => _tempHl.add(lemma));
        _syncTemp();
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

  String get _listenPlain {
    final dialog = widget.lesson.content.dialog;
    return dialog.enPlain.isNotEmpty
        ? dialog.enPlain
        : dialog.turns.map((t) => '${t.who}: ${t.en}').join(' ');
  }

  void _goCloze() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonClozePage(lesson: widget.lesson),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final dialog = lesson.content.dialog;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                          'Day ${lesson.dayIndex}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            height: 20 / 14,
                          ),
                        ),
                      ],
                    ),
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
                          '对话：${dialog.titleDisplay()}',
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
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _dialogBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _dialogBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < dialog.turns.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          TokenText(
                            tokens: dialog.turns[i].enTokens,
                            onTap: _onToken,
                            knownLemmas: _known,
                            tempHighlightLemmas: _tempHl,
                            focusLemmas: _focus,
                            leading: Text(
                              '${dialog.turns[i].who}:',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _text,
                                height: 24 / 16,
                              ),
                            ),
                          ),
                          // 仅展示该轮英文的对应译文；不用 zhLead 冒充翻译
                          if (dialog.turns[i].zh.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: ZhMarkedText(
                                text: dialog.turns[i].zh,
                                fontSize: 14,
                                extraHighlights: glossHighlightPhrases(
                                  lesson.content.targetLemmas.map(
                                    (l) =>
                                        lesson.content.defFor(l)?.gloss ?? '',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ListenableBuilder(
                listenable: _tts,
                builder: (context, _) {
                  final listening = _tts.isSessionFor(_listenPlain);
                  final next = SizedBox(
                    height: 43,
                    width: listening ? double.infinity : null,
                    child: OutlinedButton(
                      onPressed: _goCloze,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _text,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '去闭眼回填',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                  final listen = LessonListenBar(
                    tts: _tts,
                    text: _listenPlain,
                    idleLabel: '听一遍对话',
                    accent: _blue,
                  );
                  if (listening) {
                    return Column(
                      children: [
                        listen,
                        const SizedBox(height: 8),
                        next,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: listen),
                      const SizedBox(width: 8),
                      Expanded(child: next),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
