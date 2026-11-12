import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/image_cache.dart';
import '../core/jm_protocol.dart';
import '../core/reading_stats.dart';
import '../core/jm_service.dart';
import '../core/image_scrambler.dart';
import '../core/image_worker.dart';
import '../core/source.dart';
import '../core/temp_store.dart';
import '../core/l10n.dart';

class ReaderPageView extends StatefulWidget {
  final PageRef ref;
  final String? scrambleId;
  final String scrambleAid;
  final String albumId;
  final ComicSource source;
  final String cacheKey;
  final BoxFit fit;

  final bool enableZoom;

  /// 缩放状态变化时回调，供外层禁用列表滚动
  final ValueChanged<bool>? onZoomChanged;

  final double fallbackRatio;

  final String? tempDir;

  final String chapterId;

  final ValueChanged<double>? onLoaded;

  final int? decodeWidth;

  const ReaderPageView({
    super.key,
    required this.ref,
    required this.scrambleId,
    required this.scrambleAid,
    required this.albumId,
    required this.source,
    required this.cacheKey,
    this.chapterId = '',
    this.tempDir,
    this.fit = BoxFit.fitWidth,
    this.enableZoom = true,
    this.onZoomChanged,
    this.fallbackRatio = 0.72,
    this.decodeWidth,
    this.onLoaded,
  });

  @override
  State<ReaderPageView> createState() => _ReaderPageViewState();
}

class _ReaderPageViewState extends State<ReaderPageView> {
  ui.Image? _image;
  bool _failed = false;
  bool _started = false;

  bool get _zoomEnabled =>
      widget.enableZoom && !AppState.instance.disableZoom;

  @override
  void initState() {
    super.initState();
    _syncHit();
  }

  void _syncHit() {
    final key = widget.cacheKey;
    if (key.startsWith('http') && widget.ref.directUrl != null) {
      final cached = ImageCacheManager.instance.getUiSync(key);
      if (cached != null) {
        _image = cached;
        unawaited(
          ReadingStats.instance.recordCache(hit: true, savedBytes: 0),
        );
        return;
      }
    }
    unawaited(ReadingStats.instance.recordCache(hit: false));
    _start();
  }

  @override
  void didUpdateWidget(covariant ReaderPageView old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey) {
      _image = null;
      _failed = false;
      _started = false;
      _syncHit();
    }
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    final tempDir = widget.tempDir;
    if (tempDir != null && tempDir.isNotEmpty) {
      final bytes = await TempStore.instance.get(
        tempDir,
        widget.ref.index,
        sourceId: widget.source.id,
        chapterId: widget.chapterId,
      );
      if (bytes != null && bytes.isNotEmpty) {
        Uint8List tdata = bytes;
        final tsid = widget.scrambleId;
        final turi = widget.ref.directUrl ?? widget.ref.resolveUrl ?? '';
        if (tsid != null &&
            turi.isNotEmpty &&
            ImageScrambler.needScramble(widget.scrambleAid, tsid, turi)) {
          final pk = ImageScrambler.pageKeyFromUrl(turi, widget.ref.index);
          final seg = ImageScrambler.segments(widget.scrambleAid, pk);
          final jpg = await ImageWorker.instance.unscrambleToJpeg(
            bytes: bytes,
            segments: seg,
            maxWidth: widget.decodeWidth,
            quality: 88,
          );
          if (jpg != null) tdata = jpg;
        }
        final img = await ImageCacheManager.decodeScaled(
          tdata,
          targetWidth: widget.decodeWidth,
        );
        if (!mounted) return;
        setState(() {
          _image = img;
          _failed = img == null;
        });
        if (img == null) _started = false;
        return;
      }
    }

    var url = widget.ref.directUrl;
    if (url == null && widget.ref.resolveUrl != null) {
      url = await widget.source.resolvePageUrl(widget.ref.resolveUrl!);
    }
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      _started = false;
      return;
    }

    final cached = ImageCacheManager.instance.getUiSync(url);
    if (cached != null) {
      if (mounted) setState(() => _image = cached);
      return;
    }

    final local = await ImageCacheManager.instance.readDiskTagged(url);
    if (local != null && local.bytes.isNotEmpty) {
      Uint8List data = local.bytes;
      if (!local.ready) {
        final sid0 = widget.scrambleId;
        if (sid0 != null &&
            ImageScrambler.needScramble(widget.scrambleAid, sid0, url)) {
          final pk = ImageScrambler.pageKeyFromUrl(url, widget.ref.index);
          final seg = ImageScrambler.segments(widget.scrambleAid, pk);
          final jpg = await ImageWorker.instance.unscrambleToJpeg(
            bytes: local.bytes,
            segments: seg,
            maxWidth: widget.decodeWidth,
            quality: 88,
          );
          if (jpg != null) {
            data = jpg;
            unawaited(
              ImageCacheManager.instance.persistBytes(
                url,
                jpg,
                overwrite: true,
                ready: true,
              ),
            );
          }
        }
      }
      final img = await ImageCacheManager.decodeScaled(
        data,
        targetWidth: widget.decodeWidth,
      );
      if (img != null) {
        ImageCacheManager.instance.putUi(url, img);
        if (!mounted) return;
        setState(() {
          _image = img;
          _failed = false;
        });
        return;
      }
    }

    final bytes = await ImageCacheManager.instance.load(
      url,
      persist: true,
      fetcher: (u) async {
        final b = await JmApi.instance.fetchBytes(
          u,
          referer: widget.source.id == 'ehentai' ? widget.ref.resolveUrl : null,
        );
        if (b != null) return b;
        for (final alt in JmService.instance.imageUrlCandidates(u)) {
          final r = await JmApi.instance.fetchBytes(
            alt,
            referer:
                widget.source.id == 'ehentai' ? widget.ref.resolveUrl : null,
          );
          if (r != null) return r;
        }
        return null;
      },
    );
    if (bytes == null) {
      if (mounted) setState(() => _failed = true);
      _started = false;
      return;
    }

    var data = bytes;
    final sid = widget.scrambleId;
    if (sid != null &&
        ImageScrambler.needScramble(widget.scrambleAid, sid, url)) {
      final pk = ImageScrambler.pageKeyFromUrl(url, widget.ref.index);
      final seg = ImageScrambler.segments(widget.scrambleAid, pk);
      final jpg = await ImageWorker.instance.unscrambleToJpeg(
        bytes: bytes,
        segments: seg,
        maxWidth: widget.decodeWidth,
        quality: 92,
      );
      final img = await ImageCacheManager.decodeScaled(
        jpg ?? bytes,
        targetWidth: widget.decodeWidth,
      );
      if (img != null) ImageCacheManager.instance.putUi(url, img);
      if (!mounted) return;
      setState(() {
        _image = img;
        _failed = img == null;
      });
      if (img == null) _started = false;
      return;
    }

    final img = await ImageCacheManager.decodeScaled(
      data,
      targetWidth: widget.decodeWidth,
    );
    if (img != null) ImageCacheManager.instance.putUi(url, img);
    if (!mounted) return;
    setState(() {
      _image = img;
      _failed = img == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _failed = false;
            _started = false;
          });
          _start();
        },
        child: Container(
          height: 200,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                L.tp('pageNFailed', {'n': widget.ref.index}),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    final img = _image;
    if (img == null) {
      return AspectRatio(
        aspectRatio: widget.fallbackRatio <= 0 ? 0.72 : widget.fallbackRatio,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.tp('pageN', {'n': widget.ref.index}),
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    final ratio = img.width / img.height <= 0 ? 0.72 : img.width / img.height;
    widget.onLoaded?.call(ratio);

    final pic = RawImage(
      image: img,
      fit: widget.fit,
      filterQuality: FilterQuality.low,
    );

    if (!_zoomEnabled) {
      return AspectRatio(aspectRatio: ratio, child: pic);
    }

    // 纯双指缩放：Listener 自己跟踪多指，不参与手势竞技，
    // 因此不会和列表滚动/点击互相抢夺。
    return AspectRatio(
      aspectRatio: ratio,
      child: Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: Transform(
          transform: _matrix,
          alignment: Alignment.center,
          child: pic,
        ),
      ),
    );
  }

  // ---- 双指缩放实现 ----
  final _ptrs = <int, Offset>{};
  var _matrix = Matrix4.identity();
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  double _dx = 0;
  double _dy = 0;
  bool _zoomNotified = false;

  void _onDown(PointerDownEvent e) {
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length == 2) {
      final pts = _ptrs.values.toList();
      _startFocal = (pts[0] + pts[1]) / 2;
      _startScale = 1;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length < 2) return;

    final pts = _ptrs.values.toList();
    final p0 = pts[0];
    final p1 = pts[1];
    final dist = (p1 - p0).distance;
    final focal = (p0 + p1) / 2;

    // 用初始距离作为基准
    final span = _spanFor();
    final scale = (dist / span).clamp(1.0, 5.0);
    final pan = focal - _startFocal;

    _dx = pan.dx;
    _dy = pan.dy;
    _startScale = scale;

    _matrix = Matrix4.identity()
      ..translate(_dx, _dy)
      ..scale(scale);

    if (!_zoomNotified) {
      _zoomNotified = true;
      widget.onZoomChanged?.call(true);
    }
    setState(() {});
  }

  double _spanFor() {
    // 记录首次两指按下时的间距
    if (_initialSpan <= 0) {
      final pts = _ptrs.values.toList();
      if (pts.length >= 2) {
        _initialSpan = (pts[1] - pts[0]).distance;
      }
    }
    return _initialSpan <= 0 ? 1 : _initialSpan;
  }

  double _initialSpan = 0;

  void _onUp(PointerEvent e) {
    _ptrs.remove(e.pointer);
    if (_ptrs.length < 2) {
      _initialSpan = 0;
    }
    if (_ptrs.isEmpty) {
      // 回弹：缩放小于 1.02 时归位
      if (_startScale <= 1.02) {
        _matrix = Matrix4.identity();
        _startScale = 1;
        _dx = 0;
        _dy = 0;
        if (_zoomNotified) {
          _zoomNotified = false;
          widget.onZoomChanged?.call(false);
        }
        setState(() {});
      }
    }
  }

}
