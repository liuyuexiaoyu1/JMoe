import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/favorite_models.dart';
import '../core/jm_service.dart';
import '../core/l10n.dart';
import '../widgets/common_widgets.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _map = <String, List<TaskItem>>{};
  bool _loading = true;
  String? _error;

  static const _types = ['all', 'coin', 'exp'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _types.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      for (final t in _types) {
        final list = await JmService.instance.fetchTasks(t);
        _map[t] = list;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _label(String t) {
    switch (t) {
      case 'coin':
        return L.t('taskCoin');
      case 'exp':
        return L.t('taskExp');
      default:
        return L.t('taskAll');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('tasks')),
        bottom: TabBar(
          controller: _tab,
          tabs: [for (final t in _types) Tab(text: _label(t))],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 100),
                    EmptyView(message: _error!, icon: Icons.error_outline),
                  ],
                )
              : TabBarView(
                  controller: _tab,
                  children: [
                    for (final t in _types) _list(theme, _map[t] ?? const []),
                  ],
                ),
    );
  }

  Widget _list(ThemeData theme, List<TaskItem> items) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyView(
            message: L.t('noTasks'),
            icon: Icons.task_alt_rounded,
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
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = items[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                t.done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: t.done ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (t.desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        t.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (t.reward > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${t.reward}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
              if (t.done) ...[
                const SizedBox(width: 6),
                Text(
                  L.t('taskDone'),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
