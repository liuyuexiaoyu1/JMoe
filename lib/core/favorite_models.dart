class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.name,
    this.count = 0,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final int count;
  final bool isDefault;

  factory FavoriteFolder.fromJm(Map<String, dynamic> j) {
    return FavoriteFolder(
      id: '${j['FID'] ?? j['fid'] ?? j['id'] ?? '0'}',
      name: '${j['name'] ?? j['title'] ?? ''}',
      count: int.tryParse('${j['count'] ?? j['total'] ?? 0}') ?? 0,
      isDefault: j['is_default'] == true || '${j['FID'] ?? ''}' == '0',
    );
  }

  static const all = FavoriteFolder(id: '0', name: '', isDefault: true);
}

class FavoritePage {
  const FavoritePage({
    required this.comics,
    required this.total,
    required this.count,
    required this.folders,
  });

  final List<dynamic> comics;
  final int total;
  final int count;
  final List<FavoriteFolder> folders;

  static const empty = FavoritePage(
    comics: [],
    total: 0,
    count: 0,
    folders: [],
  );
}

class TagsFavoriteItem {
  const TagsFavoriteItem({
    required this.tag,
    required this.count,
    this.category,
  });

  final String tag;
  final int count;
  final String? category;

  factory TagsFavoriteItem.fromJm(Map<String, dynamic> j) {
    return TagsFavoriteItem(
      tag: '${j['tag'] ?? j['name'] ?? j['TAG'] ?? ''}',
      count: int.tryParse('${j['count'] ?? j['total'] ?? 0}') ?? 0,
      category: j['category']?.toString(),
    );
  }
}

class TrackedComic {
  const TrackedComic({
    required this.id,
    required this.name,
    this.author = '',
    this.cover,
    this.lastChapter,
    this.updateAt,
  });

  final String id;
  final String name;
  final String author;
  final String? cover;
  final String? lastChapter;
  final int? updateAt;

  factory TrackedComic.fromJm(Map<String, dynamic> j) {
    return TrackedComic(
      id: '${j['id'] ?? j['aid'] ?? ''}',
      name: '${j['name'] ?? ''}',
      author: '${j['author'] ?? ''}',
      cover: j['image'] as String?,
      lastChapter: j['last_chapter']?.toString(),
      updateAt: int.tryParse('${j['update_at'] ?? 0}'),
    );
  }
}

class DailyFilterOption {
  const DailyFilterOption({
    required this.key,
    required this.label,
    this.values = const [],
  });

  final String key;
  final String label;
  final List<String> values;

  factory DailyFilterOption.fromJm(Map<String, dynamic> j) {
    final raw = j['list'] ?? j['values'] ?? j['options'];
    final vals = <String>[];
    if (raw is List) {
      for (final v in raw) {
        if (v is Map) {
          vals.add('${v['title'] ?? v['name'] ?? v['value'] ?? ''}');
        } else {
          vals.add('$v');
        }
      }
    }
    return DailyFilterOption(
      key: '${j['key'] ?? j['name'] ?? j['type'] ?? ''}',
      label: '${j['label'] ?? j['title'] ?? ''}',
      values: vals.where((e) => e.isNotEmpty).toList(),
    );
  }
}

class CreatorWork {
  const CreatorWork({
    required this.id,
    required this.name,
    this.author = '',
    this.cover,
    this.category,
    this.updateAt,
  });

  final String id;
  final String name;
  final String author;
  final String? cover;
  final String? category;
  final int? updateAt;

  factory CreatorWork.fromJm(Map<String, dynamic> j) {
    return CreatorWork(
      id: '${j['id'] ?? j['aid'] ?? ''}',
      name: '${j['name'] ?? ''}',
      author: '${j['author'] ?? ''}',
      cover: j['image'] as String?,
      category: j['category']?.toString(),
      updateAt: int.tryParse('${j['update_at'] ?? 0}'),
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.type,
    this.desc = '',
    this.reward = 0,
    this.status = '',
    this.done = false,
  });

  final String id;
  final String title;
  final String type;
  final String desc;
  final int reward;
  final String status;
  final bool done;

  factory TaskItem.fromJm(Map<String, dynamic> j, String type) {
    final st = '${j['status'] ?? ''}';
    return TaskItem(
      id: '${j['id'] ?? j['task_id'] ?? ''}',
      title: '${j['title'] ?? j['name'] ?? ''}',
      type: type,
      desc: '${j['desc'] ?? j['description'] ?? ''}',
      reward: int.tryParse('${j['reward'] ?? j['coin'] ?? 0}') ?? 0,
      status: st,
      done: st == 'ok' || st == 'done' || j['done'] == true,
    );
  }
}
