import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 自定义标签分类。
///
/// 用户自建标签，把收藏的作品归类。纯本地存储（可随备份导出），
/// 不依赖官方 tags_favorite 接口（该接口实际返回预设标签表，本 App 用不上）。
class CustomTagStore extends ChangeNotifier {
  CustomTagStore._();
  static final CustomTagStore instance = CustomTagStore._();

  static const _kTags = 'customTags';
  static const _kMap = 'customTagMap';

  SharedPreferences? _prefs;

  /// 标签名列表
  final _tags = <String>[];

  /// 作品 id -> 标签列表
  final _map = <String, List<String>>{};

  List<String> get tags => List.unmodifiable(_tags);

  bool get isEmpty => _tags.isEmpty;

  List<String> tagsOf(String comicId) =>
      List.unmodifiable(_map[comicId] ?? const <String>[]);

  bool hasTag(String comicId, String tag) =>
      (_map[comicId] ?? const <String>[]).contains(tag);

  int countOf(String tag) {
    var n = 0;
    for (final list in _map.values) {
      if (list.contains(tag)) n++;
    }
    return n;
  }

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final rawTags = _prefs?.getString(_kTags);
    if (rawTags != null && rawTags.isNotEmpty) {
      try {
        final list = jsonDecode(rawTags);
        if (list is List) {
          _tags
            ..clear()
            ..addAll(list.map((e) => '$e').where((e) => e.isNotEmpty));
        }
      } catch (_) {}
    }
    final rawMap = _prefs?.getString(_kMap);
    if (rawMap != null && rawMap.isNotEmpty) {
      try {
        final m = jsonDecode(rawMap);
        if (m is Map) {
          _map.clear();
          m.forEach((k, v) {
            if (v is List) {
              _map['$k'] = v.map((e) => '$e').toList();
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<bool> addTag(String tag) async {
    final t = tag.trim();
    if (t.isEmpty || _tags.contains(t)) return false;
    _tags.add(t);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> removeTag(String tag) async {
    if (!_tags.remove(tag)) return;
    for (final id in _map.keys.toList()) {
      _map[id]?.remove(tag);
      if (_map[id]?.isEmpty ?? false) _map.remove(id);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> renameTag(String from, String to) async {
    final t = to.trim();
    if (t.isEmpty || from == t) return;
    final i = _tags.indexOf(from);
    if (i < 0) return;
    if (_tags.contains(t)) {
      await removeTag(from);
      return;
    }
    _tags[i] = t;
    for (final id in _map.keys.toList()) {
      final list = _map[id];
      if (list == null) continue;
      final j = list.indexOf(from);
      if (j >= 0) list[j] = t;
    }
    notifyListeners();
    await _persist();
  }

  /// 给作品设置标签集合（覆盖式）。
  Future<void> setTagsOf(String comicId, Iterable<String> tags) async {
    if (comicId.isEmpty) return;
    final clean = tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (clean.isEmpty) {
      _map.remove(comicId);
    } else {
      _map[comicId] = clean.toList();
    }
    notifyListeners();
    await _persist();
  }

  Future<void> toggleTagOf(String comicId, String tag) async {
    final cur = List<String>.from(_map[comicId] ?? const <String>[]);
    if (cur.contains(tag)) {
      cur.remove(tag);
    } else {
      cur.add(tag);
    }
    await setTagsOf(comicId, cur);
  }

  /// 清理已被取消收藏的作品的标签。
  Future<void> pruneTo(Set<String> aliveIds) async {
    final before = _map.length;
    _map.removeWhere((k, _) => !aliveIds.contains(k));
    if (_map.length != before) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(_kTags, jsonEncode(_tags));
    await _prefs?.setString(_kMap, jsonEncode(_map));
  }
}
