import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'cache_manager.dart';
import 'downloader.dart';
import 'image_cache.dart';
import 'novel_cache.dart';
import 'video_cache.dart';

class StorageSlice {
  final String key;
  final int bytes;

  final bool clearable;
  const StorageSlice({
    required this.key,
    required this.bytes,
    this.clearable = true,
  });
}

class StorageManager {
  StorageManager._();
  static final StorageManager instance = StorageManager._();

  Future<List<StorageSlice>> collect() async {
    // 注意：CacheManager 与 ImageCacheManager 用的是**同一个目录**
    // （cache/imgcache），章节图片就是普通缓存文件。
    // 所以「图片缓存」和「漫画章节」不能分开统计，否则数字重复、
    // 清任意一项都会把全部缓存删光。这里合并为单一「网页缓存」项。
    final img = await ImageCacheManager.instance.diskUsage();
    final novel = await NovelCacheManager.instance.usedBytes();
    final video = await VideoCacheManager.instance.usedBytes();
    final downloads = ChapterDownloader.totalDownloadBytes();
    final base = await getApplicationSupportDirectory();
    final config = await _dirBytes(Directory('${base.path}/config'));

    return [
      StorageSlice(key: 'storageCache', bytes: img),
      StorageSlice(key: 'storageDownloads', bytes: downloads),
      StorageSlice(key: 'storageNovels', bytes: novel),
      StorageSlice(key: 'storageVideos', bytes: video),
      StorageSlice(
        key: 'storageConfig',
        bytes: config,
        clearable: false,
      ),
    ];
  }

  Future<int> totalBytes() async {
    final list = await collect();
    return list.fold<int>(0, (a, b) => a + b.bytes);
  }


  Future<int> _dirBytes(Directory d) async {
    try {
      if (!await d.exists()) return 0;
      var sum = 0;
      await for (final e in d.list(recursive: true)) {
        if (e is File) sum += await e.length();
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear(String key) async {
    switch (key) {
      case 'storageCache':
        // 图片缓存与章节缓存是同一批文件，必须一起清。
        await ImageCacheManager.instance.clearDisk();
        await CacheManager.instance.clearAll();
        break;
      case 'storageDownloads':
        for (final t in ChapterDownloader.allTasks.toList()) {
          await ChapterDownloader.deleteBy(t.sourceId, t.chapterId);
        }
        break;
      case 'storageNovels':
        await NovelCacheManager.instance.clearAll();
        break;
      case 'storageVideos':
        await VideoCacheManager.instance.clearAll();
        break;
    }
  }

  Future<void> clearAll() async {
    await clear('storageImages');
    await clear('storageChapters');
    await clear('storageDownloads');
    await clear('storageNovels');
    await clear('storageVideos');
  }
}
