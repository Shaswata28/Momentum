import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

enum TagType { fixed, floating, adhoc, buffer, dnd, missed }

class TagChip extends StatelessWidget {
  final TagType type;
  final String label;

  const TagChip({super.key, required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textCol;
    Color borderCol;

    switch (type) {
      case TagType.fixed:
        bg = const Color(0xFF0D1D35);
        textCol = const Color(0xFF1A6FE8);
        borderCol = const Color(0xFF1A3050);
        break;
      case TagType.floating:
        bg = const Color(0xFF0D1520);
        textCol = const Color(0xFF4A7AAA);
        borderCol = const Color(0xFF162030);
        break;
      case TagType.adhoc:
        bg = const Color(0xFF201808);
        textCol = const Color(0xFFF5A623);
        borderCol = const Color(0xFF302010);
        break;
      case TagType.buffer:
        bg = const Color(0xFF111114);
        textCol = const Color(0xFF444450);
        borderCol = const Color(0xFF1A1A24);
        break;
      case TagType.dnd:
        bg = const Color(0xFF0D2010);
        textCol = const Color(0xFF1D9E75);
        borderCol = const Color(0xFF0F3018);
        break;
      case TagType.missed:
        bg = const Color(0xFF2A0D0D);
        textCol = const Color(0xFFE24B4A);
        borderCol = const Color(0xFF4A1A1A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.tagChip.copyWith(color: textCol),
      ),
    );
  }
}
