import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../core/tag_block_store.dart';
import '../widgets/app_toast.dart';
import '../widgets/common_widgets.dart';

class TagBlockPage extends StatefulWidget {
  const TagBlockPage({super.key});

  @override
  State<TagBlockPage> createState() => _TagBlockPageState();
}

class _TagBlockPageState extends State<TagBlockPage> {
  final _ctrl = TextEditingController();
  List<String> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await TagBlockStore.instance.load();
    if (!mounted) return;
    setState(() {
      _tags = List<String>.from(TagBlockStore.instance.tags);
      _loading = false;
    });
  }

  Future<void> _add() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    if (_tags.contains(t)) {
      _ctrl.clear();
      return;
    }
    final ok = await TagBlockStore.instance.add(t);
    if (!mounted) return;
    if (ok) {
      _ctrl.clear();
      setState(() => _tags = List<String>.from(TagBlockStore.instance.tags));
      AppToast.show(context, L.t('folderCreated'));
    }
  }

  Future<void> _remove(String t) async {
    await TagBlockStore.instance.remove(t);
    if (!mounted) return;
    setState(() => _tags = List<String>.from(TagBlockStore.instance.tags));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L.t('tagBlock'))),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppStyle.pagePadding,
              AppStyle.pagePadding,
              AppStyle.pagePadding,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: L.t('tagBlockHint'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _add,
                  child: Text(L.t('add')),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tags.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyView(
                            message: L.t('noBlockedTags'),
                            icon: Icons.block_outlined,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppStyle.pagePadding,
                          8,
                          AppStyle.pagePadding,
                          MediaQuery.of(context).padding.bottom + 24,
                        ),
                        itemCount: _tags.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final t = _tags[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.block_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                t,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => _remove(t),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
