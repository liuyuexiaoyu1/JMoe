import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_toast.dart';
import '../core/app_theme.dart';
import '../core/favorite_models.dart';
import '../core/folder_store.dart';
import '../core/jm_service.dart';
import '../core/l10n.dart';
import '../widgets/common_widgets.dart';

class FavoriteFolderPage extends StatefulWidget {
  const FavoriteFolderPage({super.key});

  @override
  State<FavoriteFolderPage> createState() => _FavoriteFolderPageState();
}

class _FavoriteFolderPageState extends State<FavoriteFolderPage> {
  List<FavoriteFolder> _folders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 先用本地缓存立即渲染，云端结果回来后再静默合并。
    final cached = FolderStore.instance.folders;
    setState(() {
      _loading = cached.isEmpty;
      _error = null;
      if (cached.isNotEmpty) _folders = cached;
    });

    // 云端慢也没关系：已经在显示本地数据了。
    unawaited(_refreshFromCloud());
  }

  Future<void> _refreshFromCloud() async {
    try {
      final p = await JmService.instance.fetchFavoritePage(page: 1);
      if (!mounted) return;
      final changed = FolderStore.instance.mergeCloud(p.folders);
      if (changed) await _persist();
      setState(() {
        _folders = FolderStore.instance.folders;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_folders.isEmpty) _error = '$e';
      });
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'localFavoriteFolders',
      FolderStore.instance.encode(),
    );
  }

  Future<void> _create() async {
    final name = await _askName(L.t('newFolderTitle'));
    if (name == null || name.isEmpty) return;
    final r = await JmService.instance.editFavoriteFolder(
      action: 'add',
      name: name,
    );
    if (!mounted) return;
    if (r['code'] == 200) {
      AppToast.show(context, L.t('folderCreated'));
      await _load();
    } else {
      AppToast.show(
        context,
        '${r['errorMsg'] ?? L.t('operationFailed')}',
        accent: Theme.of(context).colorScheme.error,
      );
    }
  }

  Future<void> _rename(FavoriteFolder f) async {
    final name = await _askName(L.t('renameFolder'), initial: f.name);
    if (name == null || name.isEmpty || name == f.name) return;
    final r = await JmService.instance.editFavoriteFolder(
      action: 'edit',
      name: name,
      folderId: f.id,
    );
    if (!mounted) return;
    if (r['code'] == 200) {
      AppToast.show(context, L.t('folderRenamed'));
      await _load();
    }
  }

  Future<void> _delete(FavoriteFolder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(L.t('deleteFolder')),
        content: Text(L.tp('deleteFolderConfirm', {'name': f.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(L.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(L.t('confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await JmService.instance.editFavoriteFolder(
      action: 'del',
      folderId: f.id,
    );
    if (!mounted) return;
    if (r['code'] == 200) {
      AppToast.show(context, L.t('folderDeleted'));
      await _load();
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: L.t('folderNameHint'),
            counterText: '',
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
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('favoriteFolders')),
        actions: [
          IconButton(
            tooltip: L.t('newFolder'),
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _create,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
          EmptyView(
            message: _error!,
            icon: Icons.error_outline,
          ),
        ],
      );
    }
    if (_folders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyView(
            message: L.t('noFolders'),
            icon: Icons.folder_outlined,
          ),
        ],
      );
    }
    final scheme = theme.colorScheme;
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
      itemCount: _folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = _folders[i];
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              f.isDefault
                  ? Icons.folder_special_outlined
                  : Icons.folder_outlined,
              color: scheme.primary,
            ),
            title: Text(
              f.isDefault && f.name.isEmpty ? L.t('defaultFolder') : f.name,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              L.tp('folderItemCount', {'n': f.count}),
              style: TextStyle(
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: f.isDefault
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'rename') _rename(f);
                      if (v == 'delete') _delete(f);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(L.t('rename')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(L.t('delete')),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
