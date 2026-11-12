import 'dart:async';
import 'dart:isolate';

import 'package:pointycastle/export.dart';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

class ImageWorker {
  ImageWorker._();
  static final ImageWorker instance = ImageWorker._();

  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;

  int _seq = 0;
  final Map<int, Completer<Uint8List?>> _pending = {};
  Timer? _idleTimer;

  bool get isRunning => _isolate != null;

  Future<SendPort> _ensureStarted() async {
    final existing = _toWorker;
    if (existing != null) return existing;

    final ready = Completer<SendPort>();
    final rp = ReceivePort();
    _fromWorker = rp;

    rp.listen((dynamic msg) {
      if (msg is SendPort) {
        _toWorker = msg;
        if (!ready.isCompleted) ready.complete(msg);
        return;
      }
      if (msg is Map) {
        final id = msg['id'] as int?;
        if (id == null) return;
        final c = _pending.remove(id);
        if (c == null) return;
        final data = msg['data'];
        c.complete(data is Uint8List ? data : null);
      }
    });

    _isolate = await Isolate.spawn(_workerMain, rp.sendPort);
    _scheduleIdleStop();
    return ready.future;
  }

  void _scheduleIdleStop() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 20), () {
      if (_pending.isNotEmpty) {
        _scheduleIdleStop();
        return;
      }
      _stop();
    });
  }

  void _stop() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _fromWorker?.close();
    _fromWorker = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
  }

  Future<Uint8List?> unscrambleToJpeg({
    required Uint8List bytes,
    required int segments,
    int? maxWidth,
    int quality = 92,
  }) async {
    try {
      final port = await _ensureStarted();
      final id = ++_seq;
      final c = Completer<Uint8List?>();
      _pending[id] = c;
      port.send({
        'id': id,
        'bytes': bytes,
        'segments': segments,
        'maxWidth': maxWidth,
        'quality': quality,
      });
      _scheduleIdleStop();
      return await c.future;
    } catch (_) {
      return null;
    }
  }

  /// 在后台 isolate 做 AES-CBC 加解密。
  ///
  /// 每页图片几百 KB，纯 Dart 逐块运算放在主 isolate 会直接掉帧；
  /// 这里挪到 worker，主线程只负责收结果。
  Future<Uint8List?> crypt({
    required Uint8List bytes,
    required List<int> key,
    required List<int> iv,
    required bool encrypt,
    required bool ready,
  }) async {
    try {
      final port = await _ensureStarted();
      final id = ++_seq;
      final c = Completer<Uint8List?>();
      _pending[id] = c;
      port.send({
        'id': id,
        'op': 'crypt',
        'bytes': bytes,
        'key': key,
        'iv': iv,
        'encrypt': encrypt,
        'ready': ready,
      });
      _scheduleIdleStop();
      return await c.future;
    } catch (_) {
      return null;
    }
  }

  static void _workerMain(SendPort reply) {
    final rp = ReceivePort();
    reply.send(rp.sendPort);
    rp.listen((dynamic msg) {
      if (msg is! Map) return;
      final id = msg['id'] as int;
      try {
        if (msg['op'] == 'crypt') {
          final out = _crypt(
            msg['bytes'] as Uint8List,
            msg['key'] as List<int>,
            msg['iv'] as List<int>,
            msg['encrypt'] as bool,
            msg['ready'] as bool,
          );
          reply.send({'id': id, 'data': out});
          return;
        }
        final out = _process(
          msg['bytes'] as Uint8List,
          msg['segments'] as int,
          msg['maxWidth'] as int?,
          msg['quality'] as int? ?? 92,
        );
        reply.send({'id': id, 'data': out});
      } catch (_) {
        reply.send({'id': id, 'data': null});
      }
    });
  }

  static const _magic = [0x4A, 0x4D, 0x43, 0x01];
  static const _magicReady = [0x4A, 0x4D, 0x43, 0x02];

  static Uint8List? _crypt(
    Uint8List input,
    List<int> key,
    List<int> iv,
    bool encrypt,
    bool ready,
  ) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        encrypt,
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(key)),
          Uint8List.fromList(iv),
        ),
      );

    if (encrypt) {
      final padLen = 16 - (input.length % 16);
      final padded = Uint8List(input.length + padLen)
        ..setRange(0, input.length, input)
        ..fillRange(input.length, input.length + padLen, padLen);
      final out = Uint8List(padded.length);
      for (var off = 0; off < padded.length; off += 16) {
        cipher.processBlock(padded, off, out, off);
      }
      return Uint8List.fromList([
        ...(ready ? _magicReady : _magic),
        ...iv,
        ...out,
      ]);
    }

    if (input.length < 4 + 16 + 16) return null;
    final body = Uint8List.sublistView(input, 20);
    final out = Uint8List(body.length);
    for (var off = 0; off < body.length; off += 16) {
      cipher.processBlock(body, off, out, off);
    }
    final pad = out[out.length - 1];
    if (pad <= 0 || pad > 16) return null;
    return Uint8List.sublistView(out, 0, out.length - pad);
  }

  static Uint8List? _process(
    Uint8List bytes,
    int segments,
    int? maxWidth,
    int quality,
  ) {
    var img = im.decodeImage(bytes);
    if (img == null) return null;

    final srcW = img.width;
    var srcH = img.height;

    if (segments > 1 && srcH >= segments) {
      final dst = im.Image(width: srcW, height: srcH, numChannels: 3);
      final rem = srcH % segments;
      final baseH = srcH ~/ segments;
      for (var i = 0; i < segments; i++) {
        var ch = baseH;
        var py = baseH * i;
        final y = srcH - baseH * (i + 1) - rem;
        if (i == 0) {
          ch += rem;
        } else {
          py += rem;
        }
        if (ch <= 0) continue;
        final strip = im.copyCrop(img, x: 0, y: y, width: srcW, height: ch);
        im.compositeImage(dst, strip, dstX: 0, dstY: py);
      }
      img = dst;
    }

    if (maxWidth != null && maxWidth > 0 && img.width > maxWidth) {
      img = im.copyResize(img, width: maxWidth);
    }

    return Uint8List.fromList(im.encodeJpg(img, quality: quality));
  }
}
