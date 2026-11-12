import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/favorite_models.dart';
import '../core/jm_service.dart';
import '../core/jm_source.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../widgets/common_widgets.dart';
import 'unified_detail_page.dart';

class DailyUpdatesPage extends StatefulWidget {
  const DailyUpdatesPage({super.key});

  @override
  State<DailyUpdatesPage> createState() => _DailyUpdatesPageState();
}

class _DailyUpdatesPageState extends State<DailyUpdatesPage> {
  final _items = <Comic>[];
  final _filters = <DailyFilterOption>[];
  final _picked = <String, String>{};
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadFilters();
    await _load(reset: true);
  }

  Future<void> _loadFilters() async {
    try {
      final list = await JmService.instance.fetchDailyOptions();
      if (!mounted) return;
      setState(() {
        _filters
          ..clear()
          ..addAll(list);
      });
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _items.clear();
        _page = 1;
        _loading = true;
        _error = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final (list, total) = await JmService.instance.fetchDailyList(
        page: _page,
        filters: _picked,
      );
      if (!mounted) return;
      setState(() {
        var added = 0;
        for (final c in list) {
          if (c.id.isEmpty) continue;
          if (_items.any((e) => e.id == c.id)) continue;
          _items.add(c);
          added++;
        }
        if (added == 0) {
          _hasMore = false;
        } else {
          _page++;
          if (total > 0 && _items.length >= total) _hasMore = false;
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('dailyUpdates')),
        actions: [
          if (_filters.isNotEmpty)
            IconButton(
              tooltip: L.t('filter'),
              icon: Badge(
                isLabelVisible: _picked.isNotEmpty,
                child: const Icon(Icons.tune_rounded, size: 21),
              ),
              onPressed: _openFilter,
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

  Future<void> _openFilter() async {
    final picked = Map<String, String>.from(_picked);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (c, ctrl) => ListView(
              controller: ctrl,
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(c).padding.bottom + 20,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        L.t('filter'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setS(picked.clear),
                      child: Text(L.t('clearFilter')),
                    ),
                  ],
                ),
                for (final f in _filters) ...[
                  const SizedBox(height: 14),
                  Text(
                    f.label.isEmpty ? f.key : f.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in f.values)
                        ChoiceChip(
                          label: Text(
                            v,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: picked[f.key] == v,
                          onSelected: (sel) {
                            setS(() {
                              if (sel) {
                                picked[f.key] = v;
                              } else {
                                picked.remove(f.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(L.t('confirm')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    setState(() {
      _picked
        ..clear()
        ..addAll(picked);
    });
    await _load(reset: true);
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
            message: L.t('empty'),
            icon: Icons.event_note_outlined,
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
        return false;
      },
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          AppStyle.pagePadding,
          AppStyle.pagePadding,
          AppStyle.pagePadding,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.52,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final c = _items[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UnifiedDetailPage(
                  comic: c,
                  source: JmSource.instance,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: CoverImage(
                      url: JmService.instance.coverUrl(c),
                      fit: BoxFit.cover,
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, height: 1.25),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
