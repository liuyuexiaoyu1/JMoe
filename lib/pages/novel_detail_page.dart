import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/jm_service.dart';
import '../core/app_theme.dart';
import '../core/image_cache.dart';
import '../core/l10n.dart';
import '../core/reader_store.dart';
import 'novel_read_page.dart';
import '../widgets/app_toast.dart';
import '../widgets/common_widgets.dart';

class NovelDetailPage extends StatefulWidget {
  final String nid;
  final String title;
  final String? cover;

  final String? fabTag;

  const NovelDetailPage({
    super.key,
    required this.nid,
    required this.title,
    this.cover,
    this.fabTag,
  });

  @override
  State<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends State<NovelDetailPage> {
  final _service = JmService.instance;
  final _store = ReaderStore.instance;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _chapters = [];

  String _views = '';
  int _resumeIndex = 0;
  bool _resumeLoaded = false;

  bool _novelFav = false;

  @override
  void initState() {
    super.initState();
    _novelFav = AppState.instance.isLocalFavorite(widget.nid);
    _load();
  }

  Future<void> _toggleNovelFav() async {
    final target = !_novelFav;
    setState(() => _novelFav = target);
    await AppState.instance.setLocalFavorite(
      {
        'id': widget.nid,
        'name': _displayTitle,
        'author': '${_detail?['author'] ?? ''}',
        'cover': _coverUrl ?? '',
        'source': 'jm',
        'type': 'novel',
      },
      target,
    );
    if (!mounted) return;
    AppToast.show(
      context,
      target ? L.t('favorited') : L.t('unfavorited'),
      icon: target ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      accent: target ? const Color(0xFFFF6B81) : null,
    );
  }

  Future<void> _load() async {
    final d = await _service.fetchNovelDetail(widget.nid);
    final chapters = JmService.chaptersFromDetail(d);
    await _store.loadBook(widget.nid);
    final p = _store.progress(widget.nid);
    var resume = 0;
    if (p != null && p.chapterIndex >= 0 && p.chapterIndex < chapters.length) {
      resume = p.chapterIndex;
    }
    if (!mounted) return;
    setState(() {
      _detail = d;
      // 列表已有 cover 就不动，避免加载后换图导致闪烁。
      if ((widget.cover ?? '').isEmpty) {
        final img = '${d?['images'] ?? ''}';
        if (img.isNotEmpty) {
          _pinnedCover = img.startsWith('http')
              ? img
              : '${_service.imgHost ?? 'https://cdn-msp.jmapiproxy3.cc'}$img';
        }
      }
      _chapters = chapters;
      _views = '${d?['total_views'] ?? ''}';
      _resumeIndex = resume;
      _resumeLoaded = p != null;
    });
  }

  (String, String) _splitTitle(String raw) {
    final parts = raw.split('|');
    if (parts.length >= 2) {
      return (parts[0].trim(), parts.sublist(1).join('|').trim());
    }
    return (raw.trim(), '');
  }

  String get _displayTitle =>
      _splitTitle('${_detail?['name'] ?? widget.title}').$1;

  /// 详情加载后 pin 下来的封面。
  ///
  /// 与漫画详情页同一做法：优先用列表传入的 cover（已缓存、秒显），
  /// 只有详情里带了更准确的图才替换 —— 不来回切换，避免图片重下。
  String? _pinnedCover;

  String? get _coverUrl {
    final pinned = _pinnedCover;
    if (pinned != null && pinned.isNotEmpty) return pinned;
    final fromList = widget.cover;
    if (fromList != null && fromList.isNotEmpty) return fromList;
    final img = '${_detail?['images'] ?? ''}';
    if (img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    final host = _service.imgHost ?? 'https://cdn-msp.jmapiproxy3.cc';
    return '$host$img';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = (_detail?['tags'] as List?)
            ?.whereType<Object>()
            .map((e) => '$e')
            .toList() ??
        const <String>[];
    final author = '${_detail?['author'] ?? ''}';
    final views = '${_detail?['total_views'] ?? ''}';

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverHeader(theme, author, views),
              SliverToBoxAdapter(child: _buildActions(theme)),
              if (tags.isNotEmpty)
                SliverToBoxAdapter(child: _buildTags(theme, tags)),
              if (_chapters.isNotEmpty)
                SliverToBoxAdapter(child: _buildChapters(theme)),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
          // 与漫画详情页一致的开始阅读 FAB
          Positioned(
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: Hero(
              tag: widget.fabTag ?? 'novel_fab_${widget.nid}',
              child: _buildReadFab(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme, String author, String views) {
    return SliverAppBar(
      expandedHeight: 300,
      collapsedHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
      toolbarHeight: kToolbarHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      forceMaterialTransparency: true,
      leading: _RoundIcon(
        icon: Icons.arrow_back,
        onTap: () => Navigator.of(context).pop(),
      ),
      actions: [
        _RoundIcon(
          icon: _novelFav ? Icons.favorite : Icons.favorite_border,
          color: _novelFav ? theme.colorScheme.error : null,
          onTap: _toggleNovelFav,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverUrl != null)
                CachedCover(url: _coverUrl)
              else
                ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.black26),
              ),
              // 卡片下方白色渐变
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      theme.colorScheme.surface,
                    ],
                    stops: const [0.42, 0.85, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 122,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'novel_${widget.nid}',
                          flightShuttleBuilder: (ctx, anim, dir, from, to) {
                            final t = Curves.easeInOutCubic.transform(
                              anim.value,
                            );
                            final a = dir == HeroFlightDirection.push
                                ? t
                                : 1 - t;
                            final r = AppStyle.cardRadius +
                                (10 - AppStyle.cardRadius) * a;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(r),
                              child: _coverUrl == null
                                  ? const SizedBox.shrink()
                                  : CoverImage(url: _coverUrl),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _coverUrl == null
                                ? ColoredBox(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.menu_book_rounded,
                                      size: 28,
                                    ),
                                  )
                                : CoverImage(url: _coverUrl),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          if (author.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                          if (_chapters.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                L.tp('episodesN', {'n': _chapters.length}),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          if (_views.isNotEmpty)
            Expanded(
              child: _StatChip(
                icon: Icons.visibility_outlined,
                label: _views,
                scheme: scheme,
              ),
            ),
          if (_chapters.isNotEmpty) ...[
            if (_views.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.menu_book_outlined,
                label: L.tp('episodesN', {'n': _chapters.length}),
                scheme: scheme,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTags(ThemeData theme, List<String> tags) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#$t',
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapters(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Row(
            children: [
              Text(
                L.t('chapters'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_chapters.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _chapters.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Material(
              color: i == _resumeIndex && _resumeLoaded
                  ? scheme.primary.withValues(alpha: 0.12)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _open(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_chapters[i]['name'] ?? L.tp('episodeN', {'n': i + 1})}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReadFab(ThemeData theme) {
    final scheme = theme.colorScheme;
    final ready = _chapters.isNotEmpty;
    return Material(
      color: ready ? scheme.primaryContainer : scheme.primaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      shadowColor: Colors.black45,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: ready ? () => _open(_resumeIndex) : null,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!ready)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimaryContainer,
                    ),
                  )
                else
                  Icon(
                    Icons.play_arrow,
                    size: 20,
                    color: scheme.onPrimaryContainer,
                  ),
                const SizedBox(width: 6),
                Text(
                  _resumeLoaded && _resumeIndex > 0
                      ? L.t('continueReading')
                      : L.t('startReading'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer.withValues(
                      alpha: ready ? 1 : 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(int index) {
    final p = ReaderStore.instance.progress(widget.nid);
    final ratio = (p != null && p.chapterIndex == index) ? p.ratio : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelReadPage(
          nid: widget.nid,
          chapters: _chapters,
          index: index,
          initialRatio: ratio,
          novelTitle: _displayTitle,
          cover: _coverUrl,
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.color, required this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: color ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

