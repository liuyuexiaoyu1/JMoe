import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/source.dart';

/// 跨章节的“页”条目。
///
/// [chapterIdx] 是相对当前基准章的偏移：
///  0 = 当前章，1 = 下一章，-1 = 上一章。
class SeamEntry {
  const SeamEntry({
    required this.chapterIdx,
    required this.chapter,
    required this.bundle,
    required this.pageIndex,
    required this.totalPages,
  });

  final int chapterIdx;
  final Chapter chapter;
  final ReadBundle bundle;
  final int pageIndex;
  final int totalPages;

  bool get isChapterStart => pageIndex == 0;

  bool get isChapterEnd => pageIndex == totalPages - 1;

  String get key => '${chapter.id}:$pageIndex';
}

/// 半无缝连读控制器。
///
/// 维护「上一章尾 + 当前章 + 下一章头」的拼接窗口。
/// 只保留一个章节在内存里完整展开，邻章按需加载。
class SeamlessReaderController extends ChangeNotifier {
  SeamlessReaderController({
    required this.chapters,
    required this.baseIndex,
    required this.source,
    required this.comic,
  });

  final List<Chapter> chapters;
  final ComicSource source;
  final Comic comic;

  int baseIndex;

  ReadBundle? baseBundle;
  ReadBundle? nextBundle;
  ReadBundle? prevBundle;

  bool loadingNext = false;
  bool loadingPrev = false;

  /// 是否把下一章头部拼到当前章末尾
  bool includeNext = false;

  /// 是否把上一章尾部拼到当前章开头
  bool includePrev = false;

  static const int seamTailPages = 2;

  bool get hasNext => baseIndex < chapters.length - 1;

  bool get hasPrev => baseIndex > 0;

  Chapter get currentChapter => chapters[baseIndex];

  int get totalPages => baseBundle?.length ?? 0;

  void setBase(int index, ReadBundle? bundle) {
    baseIndex = index;
    baseBundle = bundle;
    nextBundle = null;
    prevBundle = null;
    includeNext = false;
    includePrev = false;
    notifyListeners();
  }

  Future<void> ensureNext() async {
    if (!hasNext || loadingNext) return;
    if (nextBundle != null) {
      if (!includeNext) {
        includeNext = true;
        notifyListeners();
      }
      return;
    }
    loadingNext = true;
    notifyListeners();
    try {
      final ch = chapters[baseIndex + 1];
      final b = await source.read(comic, ch);
      nextBundle = b;
      includeNext = true;
    } catch (_) {
      nextBundle = null;
    } finally {
      loadingNext = false;
      notifyListeners();
    }
  }

  Future<void> ensurePrev() async {
    if (!hasPrev || loadingPrev) return;
    if (prevBundle != null) {
      if (!includePrev) {
        includePrev = true;
        notifyListeners();
      }
      return;
    }
    loadingPrev = true;
    notifyListeners();
    try {
      final ch = chapters[baseIndex - 1];
      final b = await source.read(comic, ch);
      prevBundle = b;
      includePrev = true;
    } catch (_) {
      prevBundle = null;
    } finally {
      loadingPrev = false;
      notifyListeners();
    }
  }

  /// 构建拼接后的页列表。
  List<SeamEntry> buildEntries() {
    final out = <SeamEntry>[];
    final base = baseBundle;
    final cur = currentChapter;
    final baseTotal = base?.length ?? 0;

    if (includePrev && prevBundle != null && hasPrev) {
      final prev = prevBundle!;
      final prevCh = chapters[baseIndex - 1];
      final start = (prev.length - seamTailPages).clamp(0, prev.length);
      for (var i = start; i < prev.length; i++) {
        out.add(SeamEntry(
          chapterIdx: -1,
          chapter: prevCh,
          bundle: prev,
          pageIndex: i,
          totalPages: prev.length,
        ));
      }
    }

    if (base != null) {
      for (var i = 0; i < baseTotal; i++) {
        out.add(SeamEntry(
          chapterIdx: 0,
          chapter: cur,
          bundle: base,
          pageIndex: i,
          totalPages: baseTotal,
        ));
      }
    }

    if (includeNext && nextBundle != null && hasNext) {
      final next = nextBundle!;
      final nextCh = chapters[baseIndex + 1];
      final end = seamTailPages.clamp(0, next.length);
      for (var i = 0; i < end; i++) {
        out.add(SeamEntry(
          chapterIdx: 1,
          chapter: nextCh,
          bundle: next,
          pageIndex: i,
          totalPages: next.length,
        ));
      }
    }

    return out;
  }

  /// 当前章内部的页偏移（拼接后的列表里当前章从哪开始）
  int get baseOffset {
    if (includePrev && prevBundle != null && hasPrev) {
      return (prevBundle!.length - seamTailPages).clamp(0, prevBundle!.length);
    }
    return 0;
  }
}
