import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/features/lesson/lesson_models.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/lesson/lexicon_service.dart';
import 'package:app_starter/features/lesson/word_repository.dart';
import 'package:app_starter/features/lesson/widgets/lexicon_extras.dart';

/// 按短文出现顺序收集目标词；未入文的目标词补在末尾。
List<LessonToken> orderedTargetTokens(LessonContent content) {
  final targetSet = {
    for (final raw in content.targetLemmas)
      raw.trim().toLowerCase(),
  }..removeWhere((e) => e.isEmpty);

  final seen = <String>{};
  final out = <LessonToken>[];

  for (final t in content.article.enTokens) {
    final lemma = t.lemma.trim().toLowerCase();
    if (lemma.isEmpty || !targetSet.contains(lemma)) continue;
    if (!seen.add(lemma)) continue;
    out.add(
      LessonToken(
        surface: t.surface.replaceAll(RegExp(r"[.,!?;:—]$"), ''),
        lemma: lemma,
        isTarget: true,
        isReview: t.isReview,
      ),
    );
  }

  for (final raw in content.targetLemmas) {
    final lemma = raw.trim().toLowerCase();
    if (lemma.isEmpty || !seen.add(lemma)) continue;
    out.add(LessonToken(surface: raw.trim(), lemma: lemma, isTarget: true));
  }
  return out;
}

/// 日课「过一遍单词」：底部单词卡，从第一个目标词起依次过完。
/// 返回 `true` 表示完整过完；下滑/点遮罩关闭为 `false`。
Future<bool> showLessonWordWalkthrough({
  required BuildContext context,
  required LessonContent content,
  required LessonTts tts,
  required void Function(String lemma, {String? gloss}) onKnow,
  required void Function(String lemma, {String? gloss}) onUnknownHighlight,
  int? lessonId,
  /// 当前过词变化：父页据此滚动短文并高亮。
  ValueChanged<String>? onLemmaFocused,
}) {
  final tokens = orderedTargetTokens(content);
  if (tokens.isEmpty) return Future.value(true);

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4D000000),
    builder: (ctx) {
      return _WalkthroughSheet(
        tokens: tokens,
        content: content,
        tts: tts,
        lessonId: lessonId,
        onKnow: onKnow,
        onUnknownHighlight: onUnknownHighlight,
        onLemmaFocused: onLemmaFocused,
        onFinished: () => Navigator.of(ctx).pop(true),
      );
    },
  ).then((v) => v == true);
}

class _WalkthroughSheet extends StatefulWidget {
  const _WalkthroughSheet({
    required this.tokens,
    required this.content,
    required this.tts,
    required this.onKnow,
    required this.onUnknownHighlight,
    required this.onFinished,
    this.onLemmaFocused,
    this.lessonId,
  });

  final List<LessonToken> tokens;
  final LessonContent content;
  final LessonTts tts;
  final int? lessonId;
  final void Function(String lemma, {String? gloss}) onKnow;
  final void Function(String lemma, {String? gloss}) onUnknownHighlight;
  final ValueChanged<String>? onLemmaFocused;
  final VoidCallback onFinished;

  @override
  State<_WalkthroughSheet> createState() => _WalkthroughSheetState();
}

class _WalkthroughSheetState extends State<_WalkthroughSheet> {
  final _repo = WordRepository();

  static const _text = Color(0xFF0F172A);
  static const _blue = Color(0xFF7AC70C);
  static const _muted = Color(0xFF94A3B8);
  static const _body = Color(0xFF334155);
  static const _panel = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  int _index = 0;
  bool _busy = false;
  /// 当前词是否已点过「认识，不再高亮」
  bool _knownThisCard = false;

  String _gloss = '';
  String _pos = '';
  String _sense = '';
  String _contextLine = '';
  String _root = '';
  String _exampleEn = '';
  String _exampleZh = '';
  bool _loading = true;
  String? _error;
  LexiconEntry? _lexicon;

  LessonToken get _token => widget.tokens[_index];
  int get _total => widget.tokens.length;
  bool get _isLast => _index >= _total - 1;

  bool _isRich(LessonDef? def) {
    if (def == null) return false;
    final g = def.gloss.trim();
    if (g.isEmpty) return false;
    if (g.toLowerCase() == _token.lemma.toLowerCase()) return false;
    if ((def.sense ?? '').trim().isEmpty) return false;
    if ((def.exampleEn ?? '').trim().isEmpty) return false;
    return true;
  }

  bool get _hasRichContent =>
      _gloss.isNotEmpty &&
      _sense.isNotEmpty &&
      _exampleEn.isNotEmpty &&
      _gloss.toLowerCase() != _token.lemma.toLowerCase();

  String? get _resolvedGloss {
    final g = _gloss.trim();
    if (!_hasRichContent ||
        g.isEmpty ||
        g.toLowerCase() == _token.lemma.toLowerCase()) {
      return null;
    }
    return _pos.isNotEmpty ? '$_pos $g' : g;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrent(speak: true);
  }

  void _clearGloss() {
    _gloss = '';
    _pos = '';
    _sense = '';
    _contextLine = '';
    _root = '';
    _exampleEn = '';
    _exampleZh = '';
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

  void _applyEntry(WordLookupEntry entry) {
    _gloss = entry.gloss.trim();
    _pos = (entry.pos ?? '').trim();
    _sense = (entry.sense ?? '').trim();
    _contextLine = (entry.context ?? '').trim();
    _root = (entry.root ?? '').trim();
    _exampleEn = (entry.exampleEn ?? '').trim();
    _exampleZh = (entry.exampleZh ?? '').trim();
  }

  void _notifyFocus(String lemma) {
    // 父页 setState 不能在 bottom sheet build/init 同步触发
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLemmaFocused?.call(lemma);
    });
  }

  Future<void> _loadLexicon(String lemma) async {
    try {
      final entry = await LexiconService.instance.lookup(lemma);
      if (!mounted || _token.lemma != lemma) return;
      setState(() => _lexicon = entry);
    } catch (_) {
      if (!mounted || _token.lemma != lemma) return;
      setState(() => _lexicon = null);
    }
  }

  Future<void> _loadCurrent({required bool speak}) async {
    final token = _token;
    _lexicon = null;
    _notifyFocus(token.lemma);
    _loadLexicon(token.lemma);
    final local = widget.content.defFor(token.lemma);
    final speakText = token.surface.replaceAll(RegExp(r"[^A-Za-z']"), '');
    if (speak && speakText.isNotEmpty) {
      widget.tts.speakWord(speakText);
    }

    // 本地已有完整详解：直接展示
    if (_isRich(local)) {
      if (!mounted || _token.lemma != token.lemma) return;
      setState(() {
        _applyDef(local!);
        _loading = false;
        _error = null;
      });
      return;
    }

    // 有半套释义先亮出来，避免空转圈；后台再补详解
    if (local != null && local.gloss.trim().isNotEmpty) {
      if (!mounted || _token.lemma != token.lemma) return;
      setState(() {
        _applyDef(local);
        _loading = false;
        _error = null;
      });
    } else {
      if (!mounted || _token.lemma != token.lemma) return;
      setState(() {
        _clearGloss();
        _loading = true;
        _error = null;
      });
    }

    try {
      final entry = await _repo.lookup(
        surface: token.surface.isEmpty ? token.lemma : token.surface,
        lemma: token.lemma,
        lessonId: widget.lessonId,
      );
      if (!mounted || _token.lemma != token.lemma) return;
      setState(() {
        _applyEntry(entry);
        if (!_hasRichContent) {
          // 保留本地半套；完全没有才报错
          if (local != null && local.gloss.trim().isNotEmpty) {
            _applyDef(local);
            _error = null;
          } else {
            _clearGloss();
            _error = '释义生成中，请稍后再试';
          }
        } else {
          _error = null;
          // 写回内存，后续词卡/点词可直接用
          widget.content.defs[token.lemma] = LessonDef(
            gloss: entry.gloss,
            pos: entry.pos,
            sense: entry.sense,
            context: entry.context,
            root: entry.root,
            exampleEn: entry.exampleEn,
            exampleZh: entry.exampleZh,
          );
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _token.lemma != token.lemma) return;
      setState(() {
        if (local != null && local.gloss.trim().isNotEmpty) {
          _applyDef(local);
          _error = null;
        } else {
          _clearGloss();
          _error = e is ApiException ? e.message : '释义加载失败';
        }
        _loading = false;
      });
    }
  }

  void _markKnowOnly() {
    if (_busy || _loading) return;
    final lemma = _token.lemma;
    final gloss = _resolvedGloss;
    widget.onKnow(lemma, gloss: gloss);
    setState(() => _knownThisCard = true);
  }

  Future<void> _continueNext() async {
    if (_busy) return;
    setState(() => _busy = true);
    final lemma = _token.lemma;
    final gloss = _resolvedGloss;
    if (!_knownThisCard) {
      widget.onUnknownHighlight(lemma, gloss: gloss);
    }
    if (!mounted) return;
    if (_isLast) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index += 1;
      _knownThisCard = false;
      _busy = false;
    });
    await _loadCurrent(speak: true);
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
          LexiconExtras(
            entry: _lexicon,
            rootLine: _root,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 留出上方短文可见区，便于过词时对照定位
    final maxH = MediaQuery.sizeOf(context).height * 0.58;
    final surface =
        _token.surface.isEmpty ? _token.lemma : _token.surface;
    final speakText = surface.replaceAll(RegExp(r"[^A-Za-z']"), '');

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surface,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⭐ 本日目标词 · ${_index + 1} / $_total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: (_loading || _busy) ? null : _markKnowOnly,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _knownThisCard ? '已取消高亮' : '认识，不再高亮',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _knownThisCard ? _blue : _muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (_index + 1) / _total,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
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
                  child: OutlinedButton(
                    onPressed: speakText.isEmpty
                        ? null
                        : () => widget.tts.speakWord(speakText),
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
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: (_loading || _busy) ? null : _continueNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: const Color(0xFFD9F99D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '继续',
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
