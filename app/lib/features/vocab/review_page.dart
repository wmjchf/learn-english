import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';
import 'package:app_starter/features/vocab/vocab_models.dart';
import 'package:app_starter/features/vocab/vocab_repository.dart';

/// 闪卡复习：从今日 / 生词本进入。
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
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF2563EB);
  static const _border = Color(0xFFE2E8F0);

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
        _tts.speak(items.first.lemma);
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

  Future<void> _answer(bool know) async {
    final item = _current;
    if (item == null || _busy) return;
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
        _tts.speak(next.lemma);
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _blue, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _items.isEmpty || _current == null
              ? '复习'
              : '复习 ${_index + 1} / ${_items.length}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _current == null
                  ? _DoneView(
                      known: _known,
                      forgot: _forgot,
                      onClose: () => Navigator.of(context).pop(),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _revealed = true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: _border),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _current!.lemma,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: _text,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_revealed) ...[
                                      Text(
                                        _current!.gloss?.isNotEmpty == true
                                            ? _current!.gloss!
                                            : (_current!.sourceTitle != null
                                                ? '出自《${_current!.sourceTitle}》'
                                                : '点「认识」继续'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: _muted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ] else
                                      const Text(
                                        '点按卡片看释义',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _metaColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy ? null : () => _answer(false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: _border),
                                    minimumSize: const Size.fromHeight(52),
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
                                  onPressed: _busy ? null : () => _answer(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _blue,
                                    minimumSize: const Size.fromHeight(52),
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
                        ],
                      ),
                    ),
    );
  }
}

const _metaColor = Color(0xFF94A3B8);

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.known,
    required this.forgot,
    required this.onClose,
  });

  final int known;
  final int forgot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '本组复习完成',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '认识 $known · 不认识 $forgot',
            style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
