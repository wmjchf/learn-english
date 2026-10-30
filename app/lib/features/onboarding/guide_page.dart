import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:app_starter/core/config/app_brand.dart';
import 'package:app_starter/features/auth/login_page.dart';

/// ① 引导页：可不登录浏览；点「开始」→ 登录。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static const _bg = Color(0xFFF8FAFC);
  static const _text = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _blueDeep = Color(0xFF1E40AF);
  static const _muted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppBrand.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppBrand.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _blueDeep,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      AppBrand.pitch,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppBrand.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _muted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _MotionStage(),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '开始',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '登录后继续完成画像',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 局部矢量动效区（非全屏背景）；后续可换成 Lottie/Rive。
class _MotionStage extends StatefulWidget {
  const _MotionStage();

  @override
  State<_MotionStage> createState() => _MotionStageState();
}

class _MotionStageState extends State<_MotionStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _chips = [
    _ChipSpec('shipment', 0.08, 0.12),
    _ChipSpec('报价', 0.62, 0.18),
    _ChipSpec('email', 0.12, 0.62),
    _ChipSpec('negotiate', 0.52, 0.58),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: const Color(0xFFEFF6FF),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: _BlobPainter(t: _ctrl.value),
                    child: Stack(
                      children: [
                        for (var i = 0; i < _chips.length; i++)
                          _FloatingChip(
                            label: _chips[i].label,
                            left: _chips[i].x * constraints.maxWidth,
                            top: _chips[i].y * constraints.maxHeight,
                            phase: i * 0.9,
                            t: _ctrl.value,
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChipSpec {
  const _ChipSpec(this.label, this.x, this.y);
  final String label;
  final double x;
  final double y;
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.label,
    required this.left,
    required this.top,
    required this.phase,
    required this.t,
  });

  final String label;
  final double left;
  final double top;
  final double phase;
  final double t;

  @override
  Widget build(BuildContext context) {
    final dy = math.sin((t * math.pi * 2) + phase) * 6;
    return Positioned(
      left: left,
      top: top + dy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    void blob(Offset c, double r, Color color) {
      paint.color = color;
      canvas.drawCircle(c, r, paint);
    }

    final wobble = math.sin(t * math.pi * 2) * 8;
    blob(Offset(40 + wobble, 30), 70, const Color(0x66BFDBFE));
    blob(Offset(size.width - 40 - wobble, size.height - 40), 60, const Color(0x5593C5FD));
    blob(Offset(size.width * 0.45, 20), 45, const Color(0x4460A5FA));
    blob(Offset(size.width * 0.3, size.height * 0.55), 35, const Color(0x332563EB));

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x552563EB);
    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.42),
      42 + wobble * 0.3,
      ring,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.t != t;
}
