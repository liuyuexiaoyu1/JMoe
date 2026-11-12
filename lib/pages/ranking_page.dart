import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/jm_service.dart';
import '../core/jm_source.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/rank_badge.dart';
import 'unified_detail_page.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  List<PromoteSection> _sections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await JmService.instance.fetchPromote();
      if (!mounted) return;
      setState(() {
        _sections = list.where((s) => s.content.isNotEmpty).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: _sections.isEmpty ? 1 : _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(L.t('ranking')),
          bottom: _sections.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final s in _sections)
                      Tab(
                        text: s.title.isEmpty ? s.id : s.title,
                      ),
                  ],
                ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          edgeOffset: MediaQuery.of(context).padding.top,
          child: _buildBody(theme),
        ),
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
    if (_sections.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(
            message: L.t('empty'),
            icon: Icons.emoji_events_outlined,
          ),
        ],
      );
    }
    return TabBarView(
      children: [
        for (final s in _sections) _rankList(theme, s.content),
      ],
    );
  }

  Widget _rankList(ThemeData theme, List<Comic> items) {
    final scheme = theme.colorScheme;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        AppStyle.pagePadding,
        AppStyle.pagePadding,
        AppStyle.pagePadding,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        final rank = i + 1;
        final medal = RankBadge.medalColor(rank);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UnifiedDetailPage(
                  comic: c,
                  source: JmSource.instance,
                  coverTag: 'rank_\_',
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: medal == null
                    ? null
                    : Border.all(
                        color: medal.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
              ),
              child: Row(
                children: [
                  RankBadge(rank: rank),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 62,
                      height: 82,
                      child: CoverImage(
                        url: JmService.instance.coverUrl(c),
                        fit: BoxFit.cover,
                      ),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: medal ?? scheme.onSurface,
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
                              color: medal?.withValues(alpha: 0.75) ??
                                  scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (c.category != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (medal ?? scheme.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              c.category!,
                              style: TextStyle(
                                fontSize: 10,
                                color: medal ?? scheme.primary,
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
          ),
        );
      },
    );
  }
}