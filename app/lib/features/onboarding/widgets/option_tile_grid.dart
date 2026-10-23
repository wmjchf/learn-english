import 'package:flutter/material.dart';
import 'package:app_starter/features/onboarding/catalog_models.dart';

/// 双列半宽可选块；奇数最后一项仍半宽留白。
class OptionTileGrid extends StatelessWidget {
  const OptionTileGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  final List<CatalogItem> items;
  final Set<String> selected;
  final void Function(CatalogItem item) onToggle;

  static const _blue = Color(0xFF2563EB);
  static const _blueSoft = Color(0xFFEFF6FF);
  static const _border = Color(0xFFE2E8F0);
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final tileW = (constraints.maxWidth - gap) / 2;
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += 2) {
          final left = items[i];
          final right = i + 1 < items.length ? items[i + 1] : null;
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < items.length ? gap : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: tileW,
                    child: _Tile(
                      item: left,
                      selected: selected.contains(left.code),
                      onTap: () => onToggle(left),
                    ),
                  ),
                  SizedBox(width: gap),
                  if (right != null)
                    SizedBox(
                      width: tileW,
                      child: _Tile(
                        item: right,
                        selected: selected.contains(right.code),
                        onTap: () => onToggle(right),
                      ),
                    )
                  else
                    SizedBox(width: tileW),
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final CatalogItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? OptionTileGrid._blueSoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? OptionTileGrid._blue : OptionTileGrid._border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? OptionTileGrid._blue
                      : OptionTileGrid._text,
                ),
              ),
              if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OptionTileGrid._muted,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
