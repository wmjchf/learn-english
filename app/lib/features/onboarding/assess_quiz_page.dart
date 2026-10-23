import 'package:flutter/material.dart';
import 'package:app_starter/core/network/api_client.dart';
import 'package:app_starter/core/ui/app_toast.dart';
import 'package:app_starter/features/onboarding/assess_models.dart';
import 'package:app_starter/features/onboarding/assess_repository.dart';
import 'package:app_starter/features/onboarding/assess_result_page.dart';
import 'package:app_starter/features/onboarding/onboarding_nav.dart';
import 'package:app_starter/features/onboarding/self_assess_page.dart';

/// AI 测评答题：对齐 Figma Phone/测评（抬头 + 进度条 + 题目卡 + 全宽选项）。
class AssessQuizPage extends StatefulWidget {
  const AssessQuizPage({
    super.key,
    required this.startLevel,
    this.reassess = false,
  });

  final String startLevel;
  final bool reassess;

  @override
  State<AssessQuizPage> createState() => _AssessQuizPageState();
}

class _AssessQuizPageState extends State<AssessQuizPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _slate = Color(0xFF334155);
  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _blueDeep = Color(0xFF1D4ED8);
  static const _track = Color(0xFFE2E8F0);
  static const _progressMuted = Color(0xFF94A3B8);

  final _repo = AssessRepository();

  int? _sessionId;
  AssessQuestion? _question;
  AssessProgress _progress = const AssessProgress(current: 1, total: 12);
  String? _selectedOptionId;
  bool _loading = true;
  bool _answering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedOptionId = null;
    });
    try {
      final turn = await _repo.start(startLevel: widget.startLevel);
      if (!mounted) return;
      if (turn.finished && turn.result != null) {
        _goResult(turn.result!);
        return;
      }
      setState(() {
        _sessionId = turn.sessionId;
        _question = turn.question;
        _progress = turn.progress ?? _progress;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '测评启动失败，请检查网络';
        _loading = false;
      });
    }
  }

  void _goResult(AssessResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AssessResultPage(
          result: result,
          reassess: widget.reassess,
        ),
      ),
    );
  }

  Future<void> _onPick(AssessOption option) async {
    final sessionId = _sessionId;
    if (sessionId == null || _answering) return;
    setState(() {
      _selectedOptionId = option.id;
      _answering = true;
    });
    try {
      final turn = await _repo.answer(
        sessionId: sessionId,
        optionId: option.id,
      );
      if (!mounted) return;
      if (turn.finished && turn.result != null) {
        _goResult(turn.result!);
        return;
      }
      setState(() {
        _question = turn.question;
        _progress = turn.progress ?? _progress;
        _selectedOptionId = null;
        _answering = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _answering = false;
          _selectedOptionId = null;
        });
        AppToast.show(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _answering = false;
          _selectedOptionId = null;
        });
        AppToast.show(context, '提交失败，请稍后重试');
      }
    }
  }

  Future<void> _onBack() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        final turn = await _repo.finish(sessionId: sessionId);
        if (!mounted) return;
        if (turn.result != null) {
          _goResult(turn.result!);
          return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await onboardingBack(context, fallback: const SelfAssessPage());
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
          onPressed: _answering ? null : _onBack,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!, style: const TextStyle(color: _muted)),
          const SizedBox(height: 12),
          TextButton(onPressed: _start, child: const Text('重试')),
        ],
      );
    }
    final q = _question;
    if (q == null) {
      return const Text('暂无题目', style: TextStyle(color: _muted));
    }

    final ratio = _progress.total <= 0
        ? 0.0
        : (_progress.current / _progress.total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '为了更好的贴近您的词汇量，避免重复学习，我们准备了一套测试。',
          style: TextStyle(
            fontSize: 14,
            color: _muted,
            height: 22 / 14,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: _track,
                color: _blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_progress.current} / ${_progress.total}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _progressMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.word,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  height: 34 / 28,
                ),
              ),
              if (q.phonetic != null && q.phonetic!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  q.phonetic!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _muted,
                    height: 20 / 14,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                q.prompt,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _slate,
                  height: 22 / 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: q.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final opt = q.options[index];
              final selected = _selectedOptionId == opt.id;
              return _FullOptionTile(
                label: opt.label,
                selected: selected,
                enabled: !_answering,
                onTap: () => _onPick(opt),
                blue: _blue,
                blueSoft: _blueSoft,
                blueDeep: _blueDeep,
                border: _track,
                text: _text,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FullOptionTile extends StatelessWidget {
  const _FullOptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.blue,
    required this.blueSoft,
    required this.blueDeep,
    required this.border,
    required this.text,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Color blue;
  final Color blueSoft;
  final Color blueDeep;
  final Color border;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? blue : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? blueDeep : text,
              height: 22 / 16,
            ),
          ),
        ),
      ),
    );
  }
}
