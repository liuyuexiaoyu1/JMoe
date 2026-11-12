import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jm_service.dart';

class TagBlockStore extends ChangeNotifier {
  TagBlockStore._();
  static final TagBlockStore instance = TagBlockStore._();

  static const _key = 'blockedTags';

  final _tags = <String>[];
  SharedPreferences? _prefs;

  List<String> get tags => List.unmodifiable(_tags);

  bool get isEmpty => _tags.isEmpty;

  Future<void> load() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        _tags
          ..clear()
          ..addAll(list.map((e) => '$e').where((e) => e.isNotEmpty));
      }
    } catch (_) {}
  }

  bool isBlocked(String tag) {
    if (_tags.isEmpty) return false;
    final t = tag.trim().toLowerCase();
    for (final b in _tags) {
      if (b.toLowerCase() == t) return true;
    }
    return false;
  }

  bool blockedAny(Iterable<String> tags) {
    if (_tags.isEmpty) return false;
    for (final t in tags) {
      if (isBlocked(t)) return true;
    }
    return false;
  }

  Future<bool> add(String tag) async {
    final t = tag.trim();
    if (t.isEmpty) return false;
    if (_tags.contains(t)) return false;
    _tags.add(t);
    notifyListeners();
    await _persist();
    unawaited(JmService.instance.setTagBlock(t, true));
    return true;
  }

  Future<void> remove(String tag) async {
    final t = tag.trim();
    if (!_tags.remove(t)) return;
    notifyListeners();
    await _persist();
    unawaited(JmService.instance.setTagBlock(t, false));
  }

  Future<void> _persist() async {
    await _prefs?.setString(_key, jsonEncode(_tags));
  }
}
