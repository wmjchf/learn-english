import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app_starter/features/library/library_page.dart';
import 'package:app_starter/features/shell/me_page.dart';
import 'package:app_starter/features/today/today_page.dart';
import 'package:app_starter/features/vocab/vocab_page.dart';

/// 主壳：底部 4 Tab（今日 / 文章库 / 生词本 / 我的）。
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  static const _active = Color(0xFF2563EB);
  static const _inactive = Color(0xFF8A94A6);
  static const _barBorder = Color(0xFFE3E7EE);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayPage(),
          LibraryPage(),
          VocabPage(),
          MePage(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _barBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                _TabItem(
                  asset: 'assets/icons/tab_today.svg',
                  label: '今日',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _TabItem(
                  asset: 'assets/icons/tab_library.svg',
                  label: '文章库',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _TabItem(
                  asset: 'assets/icons/tab_vocab.svg',
                  label: '生词本',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _TabItem(
                  asset: 'assets/icons/tab_me.svg',
                  label: '我的',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _MainShellState._active
        : _MainShellState._inactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                asset,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 17 / 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
