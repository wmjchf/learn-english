import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/word_repository.dart';

/// 点词半屏：有完整释义才展示；否则整块 loading。
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

  tts.speakWord(speakText);

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
        ttsSpeak: () => tts.speakWord(speakText),
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

  String _gloss = '';
  String _pos = '';
  String _sense = '';
  String _contextLine = '';
  String _root = '';
  String _exampleEn = '';
  String _exampleZh = '';
  late bool _isTarget;
  bool _loading = false;
  String? _error;

  /// 仅当有完整 LLM 详解（释义 + 详解 + 例句）才算可展示。
  bool _isRich(LessonDef? def) {
    if (def == null) return false;
    final g = def.gloss.trim();
    if (g.isEmpty) return false;
    if (g.toLowerCase() == widget.lemma.toLowerCase()) return false;
    if ((def.sense ?? '').trim().isEmpty) return false;
    if ((def.exampleEn ?? '').trim().isEmpty) return false;
    return true;
  }

  bool get _hasRichContent =>
      _gloss.isNotEmpty &&
      _sense.isNotEmpty &&
      _exampleEn.isNotEmpty &&
      _gloss.toLowerCase() != widget.lemma.toLowerCase();

  void _clearGloss() {
    _gloss = '';
    _pos = '';
    _sense = '';
    _contextLine = '';
    _root = '';
    _exampleEn = '';
    _exampleZh = '';
  }

  void _applyEntry(WordLookupEntry entry) {
    _gloss = entry.gloss.trim();
    _pos = (entry.pos ?? '').trim();
    _sense = (entry.sense ?? '').trim();
    _contextLine = (entry.context ?? '').trim();
    _root = (entry.root ?? '').trim();
    _exampleEn = (entry.exampleEn ?? '').trim();
    _exampleZh = (entry.exampleZh ?? '').trim();
    _isTarget = entry.isTarget || widget.isTarget;
  }

  void _applyDef(LessonDef def) {
    _gloss = def.gloss.trim();
    _pos = (def.pos ?? '').trim();
    _sense = (def.sense ?? '').trim();
    _contextLine = (def.context ?? '').trim();
    _root = (def.root ?? '').trim();
    _exampleEn = (def.exampleEn ?? '').trim();
    _exampleZh = (def.exampleZh ?? '').trim();
  }

  @override
  void initState() {
    super.initState();
    _isTarget = widget.isTarget;
    if (_isRich(widget.initialDef)) {
      _applyDef(widget.initialDef!);
    } else {
      _clearGloss();
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
        _applyEntry(entry);
        // 仍不完整则继续只显示 loading，不露出半截释义
        if (!_hasRichContent) {
          _clearGloss();
          _error = '释义生成中，请稍后再点';
        } else {
          _error = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _clearGloss();
        _loading = false;
        _error = e is ApiException ? e.message : '释义加载失败';
      });
    }
  }

  Widget _section(String label, String body, {bool emphasize = false}) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: emphasize ? 14 : 13,
              color: emphasize ? _text : _body,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glossPanel() {
    if (_loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 10),
            Text(
              '正在生成释义…',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      );
    }

    if (!_hasRichContent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _error ?? '暂无释义',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '释义',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _pos.isNotEmpty ? '$_pos $_gloss' : _gloss,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _text,
              height: 1.4,
            ),
          ),
          _section('用法详解', _sense, emphasize: true),
          _section(
            '例句',
            [
              if (_exampleEn.isNotEmpty) _exampleEn,
              if (_exampleZh.isNotEmpty) _exampleZh,
            ].join('\n'),
          ),
          _section(
            '语境',
            _contextLine.isNotEmpty && _contextLine != _sense
                ? _contextLine
                : '',
          ),
          _section('原型 · 词根', _root),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
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
          Flexible(
            child: SingleChildScrollView(child: _glossPanel()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : () {
                            final g = _gloss.trim();
                            final gloss = (!_hasRichContent ||
                                    g.isEmpty ||
                                    g.toLowerCase() ==
                                        widget.lemma.toLowerCase())
                                ? null
                                : (_pos.isNotEmpty ? '$_pos $g' : g);
                            if (_isTarget) {
                              widget.onKnow(gloss);
                            } else {
                              widget.onUnknown(gloss);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: const Color(0xFFBFDBFE),
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
