import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'favorite_models.dart';

/// 收藏夹本地缓存。
///
/// 与书架收藏一致的双端机制：先读本地立即可用，
/// 再与云端合并，云端为准但本地保留上次结果。
class FolderStore {
  FolderStore._();
  static final FolderStore instance = FolderStore._();

  static const _key = 'localFavoriteFolders';

  final _folders = <FavoriteFolder>[];
  String _sig = '';

  List<FavoriteFolder> get folders => List.unmodifiable(_folders);

  bool get isEmpty => _folders.isEmpty;

  String get signature => _sig;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is List) {
        _folders
          ..clear()
          ..addAll(
            list.whereType<Map>().map(
                  (e) => FavoriteFolder.fromJm(
                    Map<String, dynamic>.from(e),
                  ),
                ),
          );
        _sig = _signatureOf(_folders);
      }
    } catch (_) {}
  }

  String encode() {
    return jsonEncode([
      for (final f in _folders)
        {
          'id': f.id,
          'name': f.name,
          'count': f.count,
          'is_default': f.isDefault,
        },
    ]);
  }

  static String _signatureOf(List<FavoriteFolder> list) =>
      list.map((e) => '${e.id}:${e.name}:${e.count}').join('|');

  /// 云端返回后合并，返回是否发生了变化。
  bool mergeCloud(List<FavoriteFolder> cloud) {
    if (cloud.isEmpty) return false;
    final next = <FavoriteFolder>[];
    final seen = <String>{};
    for (final f in cloud) {
      if (f.id.isEmpty || !seen.add(f.id)) continue;
      next.add(f);
    }
    final sig = _signatureOf(next);
    if (sig == _sig) return false;
    _sig = sig;
    _folders
      ..clear()
      ..addAll(next);
    return true;
  }

  void upsert(FavoriteFolder f) {
    final i = _folders.indexWhere((e) => e.id == f.id);
    if (i >= 0) {
      _folders[i] = f;
    } else {
      _folders.add(f);
    }
    _sig = _signatureOf(_folders);
  }

  void remove(String id) {
    _folders.removeWhere((e) => e.id == id);
    _sig = _signatureOf(_folders);
  }
}
