import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/favorite_models.dart';
import '../core/jm_service.dart';
import '../core/jm_source.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../widgets/common_widgets.dart';
import 'unified_detail_page.dart';

class CreatorWorksPage extends StatefulWidget {
  const CreatorWorksPage({super.key, required this.author});

  final String author;

  @override
  State<CreatorWorksPage> createState() => _CreatorWorksPageState();
}

class _CreatorWorksPageState extends State<CreatorWorksPage> {
  final _items = <CreatorWork>[];
  int _page = 1;
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
      final (list, total) = await JmService.instance.fetchCreatorWork(
        author: widget.author,
        page: _page,
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
        title: Text(
          widget.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            message: L.t('noCreatorWorks'),
            icon: Icons.person_search_outlined,
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          _load();
        }
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
          final w = _items[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UnifiedDetailPage(
                  comic: Comic(
                    id: w.id,
                    name: w.name,
                    author: w.author,
                    image: w.cover,
                  ),
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
                    url: JmService.instance.coverUrl(
                      Comic(
                        id: w.id,
                        name: w.name,
                        author: w.author,
                        image: w.cover,
                      ),
                    ),
                    fit: BoxFit.cover,
                  ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  w.name,
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
