import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/app_toast.dart';
import '../core/favorite_models.dart';
import '../core/jm_service.dart';
import '../core/l10n.dart';
import '../core/jm_source.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/subscription_store.dart';
import '../widgets/common_widgets.dart';
import 'unified_detail_page.dart';

class TrackedListPage extends StatefulWidget {
  const TrackedListPage({super.key});

  @override
  State<TrackedListPage> createState() => _TrackedListPageState();
}

class _TrackedListPageState extends State<TrackedListPage> {
  final _items = <TrackedComic>[];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    // 本地订阅是唯一数据源（订阅按钮同时写本地 + 云端）。
    setState(() {
      _loading = true;
      _error = null;
    });
    final subs = SubscriptionStore.instance.items;
    final out = <TrackedComic>[];
    for (final s in subs) {
      out.add(
        TrackedComic(
          id: s.comicId,
          name: s.name,
          cover: s.cover.isEmpty ? null : s.cover,
          lastChapter: null,
          updateAt: null,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(out);
      _hasMore = false;
      _loading = false;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('trackedWorks')),
        actions: [
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '$_total',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        edgeOffset: MediaQuery.of(context).padding.top,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(message: _error!, icon: Icons.error_outline),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(
            message: L.t('noTracked'),
            icon: Icons.notifications_none_rounded,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        AppStyle.pagePadding,
        AppStyle.pagePadding,
        AppStyle.pagePadding,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == _items.length) return _footer(theme);
        final c = _items[i];
        return _card(theme, c);
      },
    );
  }

  Widget _card(ThemeData theme, TrackedComic c) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UnifiedDetailPage(
              comic: Comic(
                id: c.id,
                name: c.name,
                author: c.author,
                image: c.cover,
              ),
              source: JmSource.instance,
            ),
          ),
        );
        if (mounted) await _load(reset: true);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 78,
                child: CoverImage(url: c.cover, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      c.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (c.lastChapter != null &&
                      c.lastChapter!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      c.lastChapter!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: L.t('untrack'),
              icon: const Icon(Icons.notifications_off_outlined, size: 19),
              onPressed: () async {
                await SubscriptionStore.instance.unsubscribe(c.id);
                if (c.id.isNotEmpty && AppState.instance.loggedIn) {
                  unawaited(JmService.instance.toggleTracking(c.id));
                }
                if (!mounted) return;
                setState(() => _items.remove(c));
                AppToast.show(context, L.t('folderDeleted'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_hasMore) {
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          L.t('noMore'),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
