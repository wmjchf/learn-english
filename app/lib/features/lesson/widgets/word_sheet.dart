import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';

/// 点词半屏：本地 defs 先展示，再走 lookup 补全。
Future<void> showWordSheet({
  required BuildContext context,
  required LessonToken token,
  required LessonContent content,
  required LessonTts tts,
  required void Function(String lemma, {String? gloss}) onKnow,
  required void Function(String lemma, {String? gloss}) onUnknownHighlight,
  int? lessonId,
}) {
  final lemma = token.lemma.isEmpty
      ? token.surface.replaceAll(RegExp(r"[^A-Za-z']"), '').toLowerCase()
      : token.lemma;
  final surface = token.surface.replaceAll(RegExp(r"[.,!?;:—]$"), '');
  final speakText = token.surface.replaceAll(RegExp(r"[^A-Za-z']"), '');
  final isTargetLocal =
      content.targetLemmas.contains(lemma) || token.isTarget;
  final localDef = content.defFor(lemma);

  tts.speak(speakText);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return _WordSheetBody(
        surface: surface.isEmpty ? lemma : surface,
        lemma: lemma,
        isTarget: isTargetLocal,
        initialDef: localDef,
        lessonId: lessonId,
        ttsSpeak: () => tts.speak(speakText),
        onKnow: (gloss) {
          onKnow(lemma, gloss: gloss);
          Navigator.of(ctx).pop();
        },
        onUnknown: (gloss) {
          onUnknownHighlight(lemma, gloss: gloss);
          Navigator.of(ctx).pop();
        },
      );
    },
  );
}

class _WordSheetBody extends StatefulWidget {
  const _WordSheetBody({
    required this.surface,
    required this.lemma,
    required this.isTarget,
    required this.initialDef,
    required this.ttsSpeak,
    required this.onKnow,
    required this.onUnknown,
    this.lessonId,
  });

  final String surface;
  final String lemma;
  final bool isTarget;
  final LessonDef? initialDef;
  final int? lessonId;
  final VoidCallback ttsSpeak;
  final void Function(String? gloss) onKnow;
  final void Function(String? gloss) onUnknown;

  @override
  State<_WordSheetBody> createState() => _WordSheetBodyState();
}

class _WordSheetBodyState extends State<_WordSheetBody> {
  final _repo = WordRepository();

  static const _text = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF94A3B8);
  static const _body = Color(0xFF334155);
  static const _panel = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  late String _gloss;
  late String _contextLine;
  late String _root;
  late bool _isTarget;
  bool _loading = false;

  bool _isWeak(LessonDef? def) {
    if (def == null) return true;
    final g = def.gloss.trim();
    if (g.isEmpty) return true;
    if (g.toLowerCase() == widget.lemma.toLowerCase()) return true;
    final c = (def.context ?? '').trim();
    if (c.isEmpty || c == '本课中的 ${widget.lemma}') return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    final def = widget.initialDef;
    _gloss = def?.gloss.trim().isNotEmpty == true ? def!.gloss : '加载释义中…';
    _contextLine = def?.context ?? '';
    _root = def?.root ?? widget.lemma;
    _isTarget = widget.isTarget;
    if (_isWeak(def)) {
      _loading = true;
      _fetchLookup();
    }
  }

  Future<void> _fetchLookup() async {
    try {
      final entry = await _repo.lookup(
        surface: widget.surface,
        lemma: widget.lemma,
        lessonId: widget.lessonId,
      );
      if (!mounted) return;
      setState(() {
        _gloss = entry.gloss.isNotEmpty ? entry.gloss : widget.lemma;
        _contextLine = entry.context ?? '';
        _root = entry.root ?? widget.lemma;
        _isTarget = entry.isTarget || widget.isTarget;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_gloss == '加载释义中…') {
          _gloss = e is ApiException ? e.message : '（暂无释义）';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.surface,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isTarget ? '⭐ 本日 List · 已自动朗读' : '已自动朗读',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _blue,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '直译',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ),
                    if (_loading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _gloss,
                  style: const TextStyle(fontSize: 14, color: _text),
                ),
                if (_contextLine.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '语境',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLine,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _body,
                      height: 18 / 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  '原型 · 词根',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _root,
                  style: const TextStyle(fontSize: 13, color: _body),
                ),
                const SizedBox(height: 8),
                const Text(
                  '上划看更多 ›',
                  style: TextStyle(fontSize: 12, color: _blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      final g = _gloss.trim();
                      final gloss = (g.isEmpty ||
                              g == '加载释义中…' ||
                              g == '（暂无释义）' ||
                              g.toLowerCase() == widget.lemma.toLowerCase())
                          ? null
                          : g;
                      if (_isTarget) {
                        widget.onKnow(gloss);
                      } else {
                        widget.onUnknown(gloss);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isTarget ? '认识，不再高亮' : '不认识，高亮',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: widget.ttsSpeak,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _text,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '朗读',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
