import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/app_theme.dart';
import '../widgets/app_toast.dart';
import '../core/custom_tag_store.dart';
import '../core/jm_service.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/jm_source.dart';
import '../widgets/common_widgets.dart';
import 'unified_detail_page.dart';

/// 自定义标签分类：用户自建标签，把收藏的作品归类。
class TagsFavoritePage extends StatefulWidget {
  const TagsFavoritePage({super.key});

  @override
  State<TagsFavoritePage> createState() => _TagsFavoritePageState();
}

class _TagsFavoritePageState extends State<TagsFavoritePage> {
  String? _activeTag;

  @override
  void initState() {
    super.initState();
    CustomTagStore.instance.load();
    CustomTagStore.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    CustomTagStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<Comic> get _allFavorites {
    final out = <Comic>[];
    for (final f in AppState.instance.localFavorites) {
      out.add(
        Comic(
          id: '${f['id'] ?? ''}',
          name: '${f['name'] ?? ''}',
          author: '${f['author'] ?? ''}',
          image: f['cover']?.toString(),
        ),
      );
    }
    return out;
  }

  List<Comic> get _filtered {
    final all = _allFavorites;
    final tag = _activeTag;
    if (tag == null) return all;
    return all
        .where((c) => CustomTagStore.instance.hasTag(c.id, tag))
        .toList();
  }

  Future<void> _addTag() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(L.t('addTag')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: L.t('tagInputHint'),
            counterText: '',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(L.t('confirm')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    final ok = await CustomTagStore.instance.addTag(name);
    if (!mounted) return;
    if (ok) {
      AppToast.show(context, L.t('tagAdded'));
    } else {
      AppToast.show(context, L.t('tagExists'));
    }
  }

  Future<void> _manageTag(String tag) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(L.t('rename')),
              onTap: () => Navigator.pop(c, 'rename'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(c).colorScheme.error,
              ),
              title: Text(
                L.t('delete'),
                style: TextStyle(color: Theme.of(c).colorScheme.error),
              ),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (act == null) return;

    if (act == 'delete') {
      await CustomTagStore.instance.removeTag(tag);
      if (!mounted) return;
      if (_activeTag == tag) setState(() => _activeTag = null);
      return;
    }

    final ctrl = TextEditingController(text: tag);
    final next = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(L.t('rename')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(L.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(L.t('confirm')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (next == null || next.isEmpty) return;
    await CustomTagStore.instance.renameTag(tag, next);
    if (!mounted) return;
    if (_activeTag == tag) setState(() => _activeTag = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('tagsFavorite')),
        actions: [
          IconButton(
            tooltip: L.t('addTag'),
            icon: const Icon(Icons.add_rounded),
            onPressed: _addTag,
          ),
        ],
      ),
      body: Column(
        children: [
          _tagBar(theme),
          const Divider(height: 1),
          Expanded(child: _grid(theme)),
        ],
      ),
    );
  }

  Widget _tagBar(ThemeData theme) {
    final scheme = theme.colorScheme;
    final tags = CustomTagStore.instance.tags;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip(
            scheme,
            label: L.t('all'),
            selected: _activeTag == null,
            onTap: () => setState(() => _activeTag = null),
          ),
          for (final t in tags)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onLongPress: () => _manageTag(t),
                child: _chip(
                  scheme,
                  label: '$t (${CustomTagStore.instance.countOf(t)})',
                  selected: _activeTag == t,
                  onTap: () => setState(
                    () => _activeTag = _activeTag == t ? null : t,
                  ),
                ),
              ),
            ),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Center(
                child: Text(
                  L.t('noTagsHint'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    ColorScheme scheme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _grid(ThemeData theme) {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyView(
            message: _activeTag == null
                ? L.t('noFavoritesToTag')
                : L.t('noItemsInTag'),
            icon: Icons.sell_outlined,
          ),
        ],
      );
    }
    return GridView.builder(
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
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UnifiedDetailPage(
                comic: c,
                source: JmSource.instance,
              ),
            ),
          ),
          onLongPress: () => _editTags(c),
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
    );
  }

  Future<void> _editTags(Comic c) async {
    final all = CustomTagStore.instance.tags;
    if (all.isEmpty) {
      AppToast.show(context, L.t('createTagFirst'));
      return;
    }
    final picked = <String>{...CustomTagStore.instance.tagsOf(c.id)};
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in all)
                FilterChip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  selected: picked.contains(t),
                  onSelected: (v) {
                    setS(() {
                      if (v) {
                        picked.add(t);
                      } else {
                        picked.remove(t);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.t('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await CustomTagStore.instance.setTagsOf(c.id, picked);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(L.t('confirm')),
            ),
          ],
        ),
      ),
    );
  }
}
