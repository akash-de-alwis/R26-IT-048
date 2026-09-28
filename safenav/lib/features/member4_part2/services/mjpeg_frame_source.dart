import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

enum CameraOpenError { unreachable, tls, notFound, timeout, noVideo, other }

/// Why a wireless camera could not be opened, with a driver-facing message.
class CameraOpenException implements Exception {
  final CameraOpenError reason;
  final String? detail;
  const CameraOpenException(this.reason, [this.detail]);

  String get message => switch (reason) {
        CameraOpenError.unreachable => "Can't reach the camera. Check it is "
            'on the same WiFi and the server is running.',
        CameraOpenError.tls => 'This camera uses http, not https. Change '
            'the address to start with http://',
        CameraOpenError.notFound => 'The camera answered, but not at this '
            'address. Try adding /video or /videofeed.',
        CameraOpenError.timeout => 'The camera took too long to respond.',
        CameraOpenError.noVideo => 'Connected, but no video was received. '
            'This address may not be an MJPEG stream.',
        CameraOpenError.other => 'Could not open this camera.',
      };

  /// Wrong-path style failures, where another path on the same host may work.
  bool get pathMayBeWrong =>
      reason == CameraOpenError.notFound ||
      reason == CameraOpenError.noVideo ||
      reason == CameraOpenError.other;

  static CameraOpenException from(Object e) {
    if (e is CameraOpenException) return e;
    if (e is TlsException) return CameraOpenException(CameraOpenError.tls, '$e');
    if (e is TimeoutException) {
      return CameraOpenException(CameraOpenError.timeout, '$e');
    }
    if (e is SocketException) {
      // HttpClient.connectionTimeout surfaces as a SocketException
      return CameraOpenException(
          e.message.toLowerCase().contains('timed out')
              ? CameraOpenError.timeout
              : CameraOpenError.unreachable,
          '$e');
    }
    return CameraOpenException(CameraOpenError.other, '$e');
  }

  @override
  String toString() => 'CameraOpenException($reason, $detail)';
}

/// Reads a multipart MJPEG (or any continuous JPEG) HTTP stream and keeps
/// only the LATEST complete frame, so a slow phone never builds a backlog.
class MjpegFrameSource {
  static const _maxBuffer = 2 * 1024 * 1024; // safety cap for a partial frame

  final String url;
  MjpegFrameSource(this.url);

  HttpClient? _client;
  StreamSubscription<List<int>>? _sub;
  Uint8List? latestFrame;
  DateTime? latestAt;
  bool get isActive => _sub != null;

  // Growable receive buffer; avoids re-copying the whole backlog per chunk
  Uint8List _buf = Uint8List(256 * 1024);
  int _len = 0;
  int _scanFrom = 0;
  int _frameStart = -1;
  bool _stopped = false;
  bool _ended = false; // server closed the response

  /// Connects to the stream. Throws [CameraOpenException] with the reason.
  Future<void> start({required void Function() onError}) async {
    _stopped = false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    _client = client;
    try {
      final req = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        throw const CameraOpenException(CameraOpenError.notFound, 'HTTP 404');
      }
      if (res.statusCode != 200) {
        throw CameraOpenException(
            CameraOpenError.other, 'HTTP ${res.statusCode}');
      }
      _ended = false;
      _sub = res.listen(
        _onChunk,
        onError: (_) {
          _ended = true;
          if (!_stopped) onError();
        },
        onDone: () {
          _ended = true;
          if (!_stopped) onError();
        },
        cancelOnError: true,
      );
    } catch (e) {
      await stop();
      throw CameraOpenException.from(e);
    }
  }

  /// Waits for the first complete JPEG. Throws [CameraOpenException] with
  /// [CameraOpenError.noVideo] if none arrives within [within].
  Future<void> waitForFirstFrame(
      {Duration within = const Duration(seconds: 4)}) async {
    final deadline = DateTime.now().add(within);
    while (latestFrame == null) {
      // _ended: e.g. the address served a web page and closed
      if (_stopped || _ended || DateTime.now().isAfter(deadline)) {
        throw const CameraOpenException(CameraOpenError.noVideo);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onChunk(List<int> chunk) {
    _append(chunk);
    // Extract every complete JPEG: starts FF D8, ends FF D9
    while (true) {
      if (_frameStart < 0) {
        final s = _find(0xD8, _scanFrom);
        if (s < 0) {
          // Keep the last byte in case it is the 0xFF of a split marker
          _dropBefore(_len > 0 ? _len - 1 : 0);
          return;
        }
        _frameStart = s;
        _scanFrom = s + 2;
      }
      final e = _find(0xD9, _scanFrom);
      if (e < 0) {
        // Wait for more data
        _scanFrom = _len - 1 > _frameStart + 2 ? _len - 1 : _frameStart + 2;
        if (_len > _maxBuffer) _resetBuffer();
        return;
      }
      latestFrame = _buf.sublist(_frameStart, e + 2);
      latestAt = DateTime.now();
      _dropBefore(e + 2);
    }
  }

  void _append(List<int> chunk) {
    final needed = _len + chunk.length;
    if (needed > _buf.length) {
      final grown = Uint8List(needed > _buf.length * 2 ? needed : _buf.length * 2);
      grown.setRange(0, _len, _buf);
      _buf = grown;
    }
    _buf.setRange(_len, needed, chunk);
    _len = needed;
  }

  int _find(int marker, int from) {
    for (var i = from < 0 ? 0 : from; i < _len - 1; i++) {
      if (_buf[i] == 0xFF && _buf[i + 1] == marker) return i;
    }
    return -1;
  }

  void _dropBefore(int n) {
    if (n > 0) {
      _buf.setRange(0, _len - n, _buf, n);
      _len -= n;
    }
    _frameStart = -1;
    _scanFrom = 0;
  }

  void _resetBuffer() {
    _len = 0;
    _frameStart = -1;
    _scanFrom = 0;
  }

  Future<void> stop() async {
    _stopped = true;
    await _sub?.cancel();
    _sub = null;
    _client?.close(force: true);
    _client = null;
    latestFrame = null;
    latestAt = null;
    _resetBuffer();
  }
}
