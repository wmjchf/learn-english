import 'package:flutter/material.dart';
import 'package:app_starter/features/lesson/lesson_tts.dart';

/// 听短文 / 听对话：播放暂停 + 可拖动进度条。
class LessonListenBar extends StatefulWidget {
  const LessonListenBar({
    super.key,
    required this.tts,
    required this.text,
    this.idleLabel = '听一遍短文',
    this.accent = const Color(0xFF1A56DB),
  });

  final LessonTts tts;
  final String text;
  final String idleLabel;
  final Color accent;

  @override
  State<LessonListenBar> createState() => _LessonListenBarState();
}

class _LessonListenBarState extends State<LessonListenBar> {
  static const _text = Color(0xFF17202E);
  static const _muted = Color(0xFF8A94A6);
  static const _border = Color(0xFFE3E7EE);
  static const _track = Color(0xFFE8EDF5);

  bool _dragging = false;
  double _dragValue = 0;

  Future<void> _onPrimary() async {
    final tts = widget.tts;
    if (tts.isLoading) return;
    if (tts.isPlaying || tts.isPaused) {
      await tts.togglePause();
      return;
    }
    final plain = widget.text.trim();
    if (plain.isEmpty) return;
    await tts.speak(plain);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tts,
      builder: (context, _) {
        final tts = widget.tts;
        // 点词朗读不抢占本条控制条
        final active = tts.isSessionFor(widget.text);
        final value = _dragging ? _dragValue : tts.progress.clamp(0.0, 1.0);
        final pct = (value * 100).round();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(10, active ? 10 : 0, 10, active ? 10 : 0),
          decoration: active
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Row(
                  children: [
                    if (tts.isLoading)
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: widget.accent,
                          ),
                        ),
                      )
                    else
                      _RoundIconButton(
                        icon: tts.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        onTap: _onPrimary,
                        fill: widget.accent,
                        iconColor: Colors.white,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: widget.accent,
                              inactiveTrackColor: _track,
                              thumbColor: widget.accent,
                              overlayColor:
                                  widget.accent.withValues(alpha: 0.12),
                            ),
                            child: Slider(
                              value: value,
                              onChanged: tts.isLoading
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _dragging = true;
                                        _dragValue = v;
                                      });
                                    },
                              onChangeEnd: tts.isLoading
                                  ? null
                                  : (v) async {
                                      setState(() {
                                        _dragging = false;
                                        _dragValue = v;
                                      });
                                      await tts.seek(v);
                                    },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Text(
                                  tts.isLoading
                                      ? '合成语音中…'
                                      : (tts.isPaused ? '已暂停' : '朗读中'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                    height: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                if (tts.error != null)
                                  Flexible(
                                    child: Text(
                                      tts.error!,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '$pct%',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _text,
                                      height: 1.2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _RoundIconButton(
                      icon: Icons.stop_rounded,
                      onTap: () => tts.stop(),
                      fill: const Color(0xFFF1F5F9),
                      iconColor: _text,
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 41,
                  child: FilledButton(
                    onPressed: _onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      widget.idleLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (tts.error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    tts.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.fill,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color fill;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
