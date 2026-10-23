import 'package:flutter/material.dart';

/// 文章库 Tab 占位（下一切片）。
class LibraryPlaceholderPage extends StatelessWidget {
  const LibraryPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '文章库',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 34 / 28,
                ),
              ),
              SizedBox(height: 12),
              Text(
                '历史文章与手动再生成即将接入。',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
