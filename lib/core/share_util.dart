import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';

class ShareUtil {
  static const MethodChannel _ch = MethodChannel('jmoe/share');

  static Future<bool> shareComic({
    required String sourceId,
    required String serial,
    required String name,
    String author = '',
    String? cover,
  }) async {
    final tag = sourceId == 'jm' ? 'JM$serial' : serial;
    final buf = StringBuffer()
      ..writeln(L.t('shareTitle'))
      ..writeln('《$name》${author.isNotEmpty ? ' - $author' : ''}')
      ..writeln(tag)
      ..write(L.t('shareHint'));
    final text = buf.toString();
    await markHandled(text);
    return shareText(text, subject: name);
  }

  /// 把自己分享出去的文案标记为已处理，
  /// 免得用户复制后打开本应用又弹出一次。
  static Future<void> markHandled(String text) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList('handledShareLinks') ?? <String>[];
      if (!list.contains(text)) {
        list.add(text);
        while (list.length > 80) {
          list.removeAt(0);
        }
        await p.setStringList('handledShareLinks', list);
      }
    } catch (_) {}
  }

  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      final r = await _ch.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': ?subject,
      });
      if (r == true) return true;
    } catch (_) {}
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return false;
    }
  }
}
