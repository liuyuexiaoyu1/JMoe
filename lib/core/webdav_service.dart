import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'config_backup.dart';

/// 极简 WebDAV 客户端。
///
/// 只做两件事：PUT 上传备份文件、GET 拉回备份文件。
/// 不依赖第三方包，直接走 HTTP Basic Auth。
class WebDavService {
  WebDavService._();
  static final WebDavService instance = WebDavService._();

  static const _kUrl = 'webdav_url';
  static const _kUser = 'webdav_user';
  static const _kPass = 'webdav_pass';

  static const fileName = 'jmoe-backup.json';

  SharedPreferences? _prefs;

  String url = '';
  String user = '';
  String pass = '';

  bool get configured =>
      url.trim().isNotEmpty && Uri.tryParse(url.trim()) != null;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    url = _prefs?.getString(_kUrl) ?? '';
    user = _prefs?.getString(_kUser) ?? '';
    pass = _prefs?.getString(_kPass) ?? '';
  }

  Future<void> save({
    required String url,
    required String user,
    required String pass,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    this.url = url.trim();
    this.user = user;
    this.pass = pass;
    await _prefs?.setString(_kUrl, this.url);
    await _prefs?.setString(_kUser, user);
    await _prefs?.setString(_kPass, pass);
  }

  String get _targetUrl {
    var base = url.trim();
    if (!base.endsWith('/')) base = '$base/';
    return '$base$fileName';
  }

  String get _authHeader {
    final raw = '$user:$pass';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }

  Future<({bool ok, String? error})> upload() async {
    if (!configured) return (ok: false, error: 'not configured');
    HttpClient? client;
    try {
      final body = await ConfigBackup.instance.export();
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final uri = Uri.parse(_targetUrl);
      final req = await client.openUrl('PUT', uri);
      req.headers.set('Authorization', _authHeader);
      req.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (ok: true, error: null);
      }
      if (res.statusCode == 409) {
        await _ensureCollection(uri);
        return await upload();
      }
      return (ok: false, error: 'HTTP ${res.statusCode}');
    } catch (e) {
      return (ok: false, error: '$e');
    } finally {
      client?.close(force: true);
    }
  }

  Future<({bool ok, int count, String? error})> downloadAndImport() async {
    if (!configured) return (ok: false, count: 0, error: 'not configured');
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final uri = Uri.parse(_targetUrl);
      final req = await client.getUrl(uri);
      req.headers.set('Authorization', _authHeader);
      final res = await req.close();
      if (res.statusCode != 200) {
        return (ok: false, count: 0, error: 'HTTP ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      if (body.trim().isEmpty) {
        return (ok: false, count: 0, error: 'empty');
      }
      final r = await ConfigBackup.instance.import(body);
      return (ok: r.ok, count: r.count, error: r.error);
    } catch (e) {
      return (ok: false, count: 0, error: '$e');
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _ensureCollection(Uri fileUri) async {
    HttpClient? client;
    try {
      client = HttpClient();
      final base = fileUri.toString();
      final idx = base.lastIndexOf('/');
      if (idx <= 0) return;
      final dir = base.substring(0, idx + 1);
      final req = await client.openUrl('MKCOL', Uri.parse(dir));
      req.headers.set('Authorization', _authHeader);
      final res = await req.close();
      await res.drain<void>();
    } catch (_) {
    } finally {
      client?.close(force: true);
    }
  }
}
