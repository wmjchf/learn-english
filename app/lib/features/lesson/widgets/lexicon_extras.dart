import 'package:flutter/material.dart';
import 'package:app_starter/features/lesson/lexicon_service.dart';

const _text = Color(0xFF0F172A);
const _blue = Color(0xFF7AC70C);
const _muted = Color(0xFF94A3B8);
const _body = Color(0xFF334155);
const _panel = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);

/// 词卡内：词根行尾「更多」+ 下方同义/易混一行。
class LexiconExtras extends StatelessWidget {
  const LexiconExtras({
    super.key,
    required this.entry,
    this.rootLine = '',
  });

  final LexiconEntry? entry;
  /// 成文/点词已有的 root 摘要（无库时仍可显示）
  final String rootLine;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final showRootBtn = e?.hasRootDetail == true;
    final summary = e?.relationSummary ?? '';
    final showRelation = e?.hasRelationRow == true && summary.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rootLine.isNotEmpty || showRootBtn) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      rootLine.isNotEmpty
                          ? rootLine
                          : (e?.breakdown.isNotEmpty == true
                              ? e!.breakdown
                              : (e?.root != null
                                  ? '${e!.root!.key}（${e.root!.meaning}）'
                                  : '')),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _body,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (showRootBtn)
                GestureDetector(
                  onTap: () => showLexiconRootSheet(context, e!),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8, top: 14),
                    child: Text(
                      '更多词根词缀 ›',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (showRelation) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showLexiconRelationSheet(context, e!),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _text,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const Text(
                    '查看 ›',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showLexiconRootSheet(
  BuildContext context,
  LexiconEntry entry,
) {
  final root = entry.root;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _SheetScaffold(
        title: '词根词缀',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.lemma,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            if (entry.breakdown.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.breakdown,
                style: const TextStyle(fontSize: 14, color: _body, height: 1.4),
              ),
            ],
            if (root != null) ...[
              const SizedBox(height: 12),
              Text(
                '${root.key} —— ${root.meaning}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              if (root.etym.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  root.etym,
                  style: const TextStyle(fontSize: 12, color: _muted, height: 1.4),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                '同族词',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              for (final m in root.family)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.word,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        if (m.breakdown.isNotEmpty)
                          Text(
                            m.breakdown,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              height: 1.35,
                            ),
                          ),
                        if (m.gloss.isNotEmpty)
                          Text(
                            m.gloss,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _body,
                              height: 1.35,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

Future<void> showLexiconRelationSheet(
  BuildContext context,
  LexiconEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _SheetScaffold(
        title: '同义 / 易混',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.lemma,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            if (entry.senses.length > 1) ...[
              const SizedBox(height: 14),
              const _SectionLabel('多义'),
              for (var i = 0; i < entry.senses.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${i + 1}. ${entry.senses[i]}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _body,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
            if (entry.synonyms.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SectionLabel('近义词'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in entry.synonyms)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        s.zh.isEmpty ? s.word : '${s.word}（${s.zh}）',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (entry.confusables.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SectionLabel('易混区分'),
              for (final c in entry.confusables)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [entry.lemma, ...c.words].join(' / '),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.note,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _body,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _muted,
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
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
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  '关闭',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }
}
