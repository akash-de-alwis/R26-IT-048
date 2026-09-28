import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enhanced_route_model.dart';

enum RouteErrorType { none, offline, timeout, server, unknown }

class _RouteRequest {
  final double originLat, originLng, destLat, destLng;
  const _RouteRequest(this.originLat, this.originLng, this.destLat, this.destLng);

  /// Same ~100 m grid as the backend cache (3 decimals).
  String get cacheKey {
    String r(double v) => v.toStringAsFixed(3);
    return '${r(originLat)},${r(originLng)}|${r(destLat)},${r(destLng)}|car';
  }
}

/// Thrown internally when the sheet closed while a request was in flight.
class _RequestCancelled implements Exception {}

class EnhancedRouteService extends ChangeNotifier {
  static const maxAttempts = 3;
  static const _slowAfter = Duration(seconds: 6);
  static const _savedMaxAge = Duration(hours: 6);
  static const _savedMaxEntries = 10;
  static const _prefsKey = 'm2p2_saved_routes_v1';

  List<EnhancedRouteModel> routes = [];
  EnhancedRouteModel? selectedRoute;
  bool isLoading = false;
  String? errorMessage;

  // ── Resilience state (read by the route sheet) ────────────────────────────
  int attemptCount = 0;
  RouteErrorType errorType = RouteErrorType.none;
  String? errorDetail;          // technical detail, e.g. exception type
  bool isSlow = false;          // loading has taken longer than [_slowAfter]
  bool usingSavedRoutes = false;
  DateTime? savedAt;
  bool degraded = false;        // backend served its own saved copy
  String? notice;               // backend notice text when degraded

  /// Map can subscribe to react immediately when the selection changes.
  void Function(EnhancedRouteModel)? onRouteChanged;

  _RouteRequest? _lastRequest;
  int _generation = 0;          // bumps invalidate in-flight results
  bool _sheetOpen = false;
  Timer? _slowTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  /// True when routes shown are not live (local saved copy or backend fallback).
  bool get showingSavedRoutes => usingSavedRoutes || degraded;

  Future<void> fetchRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    // No duplicate simultaneous calls
    if (isLoading) return;

    final req = _RouteRequest(originLat, originLng, destLat, destLng);
    final gen = ++_generation;
    _lastRequest = req;
    _sheetOpen = true;
    _stopWatchingConnectivity();

    routes = [];
    selectedRoute = null;
    isLoading = true;
    errorMessage = null;
    errorType = RouteErrorType.none;
    errorDetail = null;
    attemptCount = 0;
    isSlow = false;
    usingSavedRoutes = false;
    savedAt = null;
    degraded = false;
    notice = null;
    notifyListeners();

    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (gen == _generation && isLoading) {
        isSlow = true;
        notifyListeners();
      }
    });

    try {
      if (await _isOffline()) {
        _setError(RouteErrorType.offline, 'No internet connection',
            'Connectivity: none');
      } else {
        final response = await _postWithRetry(
          Uri.parse('$_baseUrl/v2/route/safety'),
          jsonEncode({
            'origin': {'latitude': originLat, 'longitude': originLng},
            'destination': {'latitude': destLat, 'longitude': destLng},
          }),
          gen,
        );
        if (gen != _generation) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _applyResponse(data);
          // Don't re-save the backend's stale copy as if it were fresh
          if (!degraded) await _saveRoutes(req.cacheKey, response.body);
        } else {
          _setError(
            response.statusCode >= 500
                ? RouteErrorType.server
                : RouteErrorType.unknown,
            'Server error: ${response.statusCode}',
            'HTTP ${response.statusCode}',
          );
        }
      }
    } on _RequestCancelled {
      return;
    } catch (e) {
      debugPrint('[EnhancedRouteService] $e');
      if (gen != _generation) return;
      await _classifyError(e);
    } finally {
      if (gen == _generation) {
        if (errorType != RouteErrorType.none) {
          await _fallBackToSaved(req.cacheKey, gen);
        }
        if (gen == _generation) {
          _slowTimer?.cancel();
          isLoading = false;
          notifyListeners();
        }
      }
    }
  }

  /// Re-run the last request (Try Again / Refresh / auto-retry).
  Future<void> retry() async {
    final req = _lastRequest;
    if (req == null) return;
    await fetchRoutes(
      originLat: req.originLat,
      originLng: req.originLng,
      destLat: req.destLat,
      destLng: req.destLng,
    );
  }

  /// Called by the route sheet when it is dismissed. Any pending result
  /// is ignored so it cannot redraw routes afterwards.
  void onSheetClosed() {
    _sheetOpen = false;
    _generation++;
    _stopWatchingConnectivity();
    _slowTimer?.cancel();
    if (isLoading) {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectRoute(EnhancedRouteModel route) {
    selectedRoute = route;
    notifyListeners();
    onRouteChanged?.call(route);
  }

  void clearRoutes() {
    routes = [];
    selectedRoute = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWatchingConnectivity();
    _slowTimer?.cancel();
    super.dispose();
  }

  // ── Networking ────────────────────────────────────────────────────────────

  Future<http.Response> _postWithRetry(Uri uri, String body, int gen) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (gen != _generation) throw _RequestCancelled();
      attemptCount = attempt;
      notifyListeners();
      try {
        final res = await http
            .post(uri,
                headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 25));
        // Retry only transient server errors; 4xx will not succeed on retry
        if ([502, 503, 504].contains(res.statusCode) &&
            attempt < maxAttempts) {
          throw HttpException('server busy ${res.statusCode}');
        }
        return res;
      } catch (e) {
        lastError = e;
        debugPrint('[EnhancedRouteService] attempt $attempt/$maxAttempts '
            'failed: $e');
      }
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1))); // 1s, 2s
      }
    }
    throw lastError ?? Exception('request failed');
  }

  Future<bool> _isOffline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false; // unknown -> just try the request
    }
  }

  Future<void> _classifyError(Object e) async {
    final detail = e.runtimeType.toString();
    if (e is TimeoutException) {
      _setError(RouteErrorType.timeout, 'Request timed out', detail);
    } else if (e is SocketException || e is http.ClientException) {
      // Socket failure with no network -> offline; with network the
      // backend itself is unreachable -> server
      if (await _isOffline()) {
        _setError(RouteErrorType.offline, 'No internet connection', detail);
      } else {
        _setError(RouteErrorType.server, 'Could not reach route service',
            '$detail: ${_shortMessage(e)}');
      }
    } else if (e is HttpException) {
      _setError(RouteErrorType.server, 'Service is busy', e.message);
    } else {
      _setError(RouteErrorType.unknown, 'Failed to fetch routes', detail);
    }
  }

  String _shortMessage(Object e) {
    final s = e.toString();
    return s.length > 80 ? '${s.substring(0, 80)}...' : s;
  }

  void _setError(RouteErrorType type, String message, String detail) {
    errorType = type;
    errorMessage = message;
    errorDetail = detail;
  }

  void _applyResponse(Map<String, dynamic> data) {
    routes = (data['routes'] as List<dynamic>)
        .map((r) => EnhancedRouteModel.fromJson(r as Map<String, dynamic>))
        .toList();
    degraded = data['degraded'] == true;
    notice = data['notice'] as String?;
    if (routes.isNotEmpty) {
      selectedRoute = routes.first;
      // Notify map immediately so it can draw the initial route
      onRouteChanged?.call(routes.first);
    }
  }

  // ── Offline auto-retry ────────────────────────────────────────────────────

  void _watchConnectivity() {
    _stopWatchingConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) return;
      _stopWatchingConnectivity(); // retry once
      if (_sheetOpen && !isLoading) retry();
    });
  }

  void _stopWatchingConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  // ── Saved routes (SharedPreferences) ──────────────────────────────────────

  Future<void> _fallBackToSaved(String key, int gen) async {
    final saved = await _loadSaved(key);
    if (gen != _generation) return;
    if (saved != null) {
      try {
        _applyResponse(jsonDecode(saved.body) as Map<String, dynamic>);
        usingSavedRoutes = true;
        savedAt = saved.savedAt;
        errorMessage = null;
        return;
      } catch (e) {
        debugPrint('[EnhancedRouteService] saved route unreadable: $e');
      }
    }
    if (errorType == RouteErrorType.offline) _watchConnectivity();
  }

  Future<Map<String, dynamic>> _readStore(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveRoutes(String key, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = await _readStore(prefs);
      store[key] = {'t': DateTime.now().millisecondsSinceEpoch, 'body': body};
      if (store.length > _savedMaxEntries) {
        final keys = store.keys.toList()
          ..sort((a, b) => (store[b]['t'] as int).compareTo(store[a]['t'] as int));
        for (final k in keys.skip(_savedMaxEntries)) {
          store.remove(k);
        }
      }
      await prefs.setString(_prefsKey, jsonEncode(store));
    } catch (e) {
      debugPrint('[EnhancedRouteService] could not save routes: $e');
    }
  }

  Future<({String body, DateTime savedAt})?> _loadSaved(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entry = (await _readStore(prefs))[key];
      if (entry == null) return null;
      final t = DateTime.fromMillisecondsSinceEpoch(entry['t'] as int);
      if (DateTime.now().difference(t) > _savedMaxAge) return null;
      return (body: entry['body'] as String, savedAt: t);
    } catch (e) {
      debugPrint('[EnhancedRouteService] could not read saved routes: $e');
      return null;
    }
  }
}
