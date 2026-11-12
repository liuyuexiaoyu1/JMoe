import 'package:flutter/material.dart';

class ScrollTopFab extends StatelessWidget {
  final double scrollOffset;
  final String? actionLabel;
  final VoidCallback? onAction;

  final String? heroTag;

  const ScrollTopFab({
    super.key,
    required this.scrollOffset,
    this.actionLabel,
    this.onAction,
    this.heroTag,
  });

  static const double _showThreshold = 120;

  bool get _isAction => actionLabel != null;
  bool get _show => _isAction || scrollOffset > _showThreshold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = _isAction ? _buildAction(scheme) : _buildTop(scheme);

    final hasHero = heroTag != null && heroTag!.isNotEmpty;

    // 不可见时不渲染任何东西：没有残留动画，也不占位播放。
    if (!_show) {
      return const SizedBox(width: 56, height: 56);
    }

    final content = SizedBox(width: 56, height: 56, child: button);

    if (!hasHero) return content;

    return Hero(
      tag: heroTag!,
      child: content,
    );
  }

  Widget _buildAction(ColorScheme scheme) {
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                actionLabel ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTop(ColorScheme scheme) {
    return Material(
      color: scheme.primaryContainer,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onAction,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 22,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
