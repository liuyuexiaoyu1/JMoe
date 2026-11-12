import 'package:flutter/material.dart';

/// 排行榜名次徽章：金 / 银 / 铜。
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 30});

  final int rank;
  final double size;

  static Color? medalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFD4A017);
      case 2:
        return const Color(0xFF9AA4AD);
      case 3:
        return const Color(0xFFB87333);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = medalColor(rank);
    if (medal == null) {
      return SizedBox(
        width: size,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 20, color: medal),
          Text(
            '$rank',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: medal,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
