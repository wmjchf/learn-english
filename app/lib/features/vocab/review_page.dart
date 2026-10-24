import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/vocab/vocab_models.dart';
import 'package:app_starter/features/vocab/vocab_repository.dart';

/// 闪卡复习：从今日 / 生词本进入（到期词）。
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _repo = VocabRepository();
  final _tts = LessonTts();

  List<VocabItem> _items = const [];
  int _index = 0;
  bool _loading = true;
  bool _busy = false;
  bool _revealed = false;
  String? _error;
  int _known = 0;
  int _forgot = 0;

  static const _bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.dueReviews();
      if (!mounted) return;
      setState(() {
        _items = items;
        _index = 0;
        _revealed = false;
        _loading = false;
      });
      if (items.isNotEmpty) {
        _tts.speakWord(items.first.lemma);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '加载失败';
      });
    }
  }

  VocabItem? get _current =>
      _index < _items.length ? _items[_index] : null;

  void _toggleReveal() {
    if (_current == null || _busy) return;
    setState(() => _revealed = !_revealed);
  }

  Future<void> _speakCurrent() async {
    final item = _current;
    if (item == null) return;
    await _tts.speakWord(item.lemma);
  }

  Future<void> _answer(bool know) async {
    final item = _current;
    if (item == null || _busy || !_revealed) return;
    setState(() => _busy = true);
    try {
      await _repo.answerReview(lemma: item.lemma, know: know);
      if (!mounted) return;
      setState(() {
        if (know) {
          _known += 1;
        } else {
          _forgot += 1;
        }
        _index += 1;
        _revealed = false;
        _busy = false;
      });
      final next = _current;
      if (next != null) {
        _tts.speakWord(next.lemma);
      } else {
        await _finishSession();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.show(context, e is ApiException ? e.message : '提交失败');
    }
  }

  Future<void> _finishSession() async {
    try {
      final r = await _repo.completeReview();
      if (!mounted) return;
      if (r.already) {
        AppToast.show(context, '今日已打卡');
      } else if (r.streakDelta > 0) {
        final n = r.currentStreak;
        AppToast.show(
          context,
          n != null ? '复习打卡 · 连胜 $n 天' : '复习打卡成功',
        );
      }
    } catch (_) {
      /* 打卡失败不挡结束页 */
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final showing = _current != null;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : Column(
                    children: [
                      _TopBar(
                        title: '复习',
                        counter: total > 0
                            ? (showing
                                ? '${_index + 1} / $total'
                                : '$total / $total')
                            : null,
                        progress: total == 0
                            ? 0
                            : showing
                                ? (_index + 1) / total
                                : 1,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: showing
                            ? _CardSession(
                                item: _current!,
                                revealed: _revealed,
                                busy: _busy,
                                onToggle: _toggleReveal,
                                onSpeak: _speakCurrent,
                                onForgot: () => _answer(false),
                                onKnow: () => _answer(true),
                              )
                            : total == 0 && _known == 0 && _forgot == 0
                                ? _EmptyDeck(
                                    message: '今天没有可刷的到期词\n（需已有详细释义）。',
                                    onClose: () =>
                                        Navigator.of(context).pop(),
                                  )
                                : _DoneView(
                                    known: _known,
                                    forgot: _forgot,
                                    onClose: () =>
                                        Navigator.of(context).pop(),
                                  ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.progress,
    required this.onBack,
    this.counter,
  });

  final String title;
  final String? counter;
  final double progress;
  final VoidCallback onBack;

  static const _text = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _track = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: _blue, size: 32),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
              ),
              if (counter != null)
                Text(
                  counter!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _blue,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 4,
              backgroundColor: _track,
              color: _blue,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardSession extends StatelessWidget {
  const _CardSession({
    required this.item,
    required this.revealed,
    required this.busy,
    required this.onToggle,
    required this.onSpeak,
    required this.onForgot,
    required this.onKnow,
  });

  final VocabItem item;
  final bool revealed;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onSpeak;
  final VoidCallback onForgot;
  final VoidCallback onKnow;

  static const _blue = Color(0xFF2563EB);
  static const _border = Color(0xFFE2E8F0);
  static const _red = Color(0xFFDC2626);
  static const _meta = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final canAnswer = revealed && !busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: GestureDetector(
              onTap: busy ? null : onToggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: busy ? null : onSpeak,
                        icon: const Icon(Icons.volume_up_rounded),
                        color: _blue,
                        tooltip: '朗读',
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: revealed
                            ? _BackFace(
                                key: const ValueKey('back'),
                                item: item,
                              )
                            : _FrontFace(
                                key: const ValueKey('front'),
                                lemma: item.lemma,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Opacity(
            opacity: canAnswer ? 1 : 0.4,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canAnswer ? onForgot : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      disabledForegroundColor: _red.withValues(alpha: 0.5),
                      side: BorderSide(
                        color: canAnswer ? _red.withValues(alpha: 0.35) : _border,
                      ),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '不认识',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canAnswer ? onKnow : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      disabledBackgroundColor: _blue.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '认识',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!revealed) ...[
            const SizedBox(height: 10),
            const Text(
              '先翻开卡片再作答',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _meta),
            ),
          ],
        ],
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  const _FrontFace({super.key, required this.lemma});

  final String lemma;

  static const _text = Color(0xFF0F172A);
  static const _meta = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          lemma,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: _text,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '轻点卡片看释义',
          style: TextStyle(fontSize: 14, color: _meta),
        ),
      ],
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({super.key, required this.item});

  final VocabItem item;

  static const _text = Color(0xFF0F172A);
  static const _body = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _meta = Color(0xFF94A3B8);
  static const _blueSoft = Color(0xFFEFF6FF);

  Widget _block(String label, String body, {bool strong = false}) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
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
              color: _meta,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              color: strong ? _text : _body,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gloss = (item.gloss ?? '').trim();
    final sense = (item.sense ?? '').trim();
    final example = [
      if ((item.exampleEn ?? '').trim().isNotEmpty) item.exampleEn!.trim(),
      if ((item.exampleZh ?? '').trim().isNotEmpty) item.exampleZh!.trim(),
    ].join('\n');
    final contextLine = (item.context ?? '').trim();
    final root = (item.root ?? '').trim();
    final sourceTitle = item.sourceTitle;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.lemma,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (gloss.isNotEmpty)
                  Text(
                    gloss,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _text,
                      height: 1.4,
                    ),
                  ),
                _block('用法详解', sense, strong: true),
                _block('例句', example),
                _block(
                  '语境',
                  contextLine.isNotEmpty && contextLine != sense
                      ? contextLine
                      : '',
                ),
                _block('词根', root.isNotEmpty && root != item.lemma ? root : ''),
              ],
            ),
          ),
          if (sourceTitle != null && sourceTitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '出自《$sourceTitle》',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _meta),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            '再点可收回',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.known,
    required this.forgot,
    required this.onClose,
  });

  final int known;
  final int forgot;
  final VoidCallback onClose;

  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _redSoft = Color(0xFFFEF2F2);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        children: [
          const Spacer(),
          const Text(
            '本组复习完成',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '到期词已记一圈，明天还会再见。',
            style: TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: '认识',
                  value: '$known',
                  bg: _blueSoft,
                  valueColor: _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: '不认识',
                  value: '$forgot',
                  bg: _redSoft,
                  valueColor: _red,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.bg,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color bg;
  final Color valueColor;

  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}
