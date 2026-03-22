import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/paragraph_detail.dart';
import '../models/summaries.dart';
import 'laws_api.dart';
import 'laws_cache_database.dart';

class CacheWarmupProgress {
  const CacheWarmupProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.currentTask,
  });

  final int completedSteps;
  final int? totalSteps;
  final String currentTask;

  double? get progressValue {
    final total = totalSteps;
    if (total == null || total <= 0) return null;
    return completedSteps / total;
  }

  String? get percentageLabel {
    final progress = progressValue;
    if (progress == null) return null;
    return '${(progress * 100).clamp(0, 100).round()}%';
  }
}

class LawsRepository {
  factory LawsRepository({
    LawsApi? api,
    LawsCacheDatabase? cacheDatabase,
    Connectivity? connectivity,
  }) {
    return _instance ??= LawsRepository._internal(
      api: api ?? LawsApi(),
      cacheDatabase: cacheDatabase ?? LawsCacheDatabase(),
      connectivity: connectivity ?? Connectivity(),
    );
  }

  LawsRepository._internal({
    required LawsApi api,
    required LawsCacheDatabase cacheDatabase,
    required Connectivity connectivity,
  }) : _api = api,
       _cacheDatabase = cacheDatabase,
       _connectivity = connectivity;

  static LawsRepository? _instance;
  static const int _kWarmupConcurrency = 8;
  static const _kConnectivityCacheDuration = Duration(seconds: 3);

  final LawsApi _api;
  final LawsCacheDatabase _cacheDatabase;
  final Connectivity _connectivity;

  DateTime? _lastConnectivityCheck;
  bool? _lastConnectivityResult;

  Future<void> warmUpCache({
    required void Function(CacheWarmupProgress progress) onProgress,
  }) async {
    if (!await _isOnline()) {
      throw Exception(
        'Offline. Fuer die Cache-Aktualisierung ist Internet noetig.',
      );
    }

    onProgress(
      const CacheWarmupProgress(
        completedSteps: 0,
        totalSteps: null,
        currentTask: 'Lade Gesetze...',
      ),
    );

    final laws = await _api.fetchLaws();
    await _cacheDatabase.replaceLaws(laws);

    var completedSteps = 1;
    onProgress(
      CacheWarmupProgress(
        completedSteps: completedSteps,
        totalSteps: null,
        currentTask: 'Lade Paragraphenlisten...',
      ),
    );

    final paragraphsByLaw = <String, List<ParagraphSummary>>{};
    for (final law in laws) {
      final paragraphs = await _api.fetchParagraphs(law.code);
      await _cacheDatabase.replaceParagraphs(law.code, paragraphs);
      paragraphsByLaw[law.code] = paragraphs;
      completedSteps += 1;

      onProgress(
        CacheWarmupProgress(
          completedSteps: completedSteps,
          totalSteps: null,
          currentTask: 'Paragraphenlisten: ${law.code}',
        ),
      );
    }

    final allParagraphs = [
      for (final law in laws)
        for (final paragraph in paragraphsByLaw[law.code] ?? <ParagraphSummary>[])
          (lawCode: law.code, paragraph: paragraph),
    ];
    final totalSteps = 1 + laws.length + allParagraphs.length;

    onProgress(
      CacheWarmupProgress(
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        currentTask: 'Lade Paragraphen...',
      ),
    );

    for (var i = 0; i < allParagraphs.length; i += _kWarmupConcurrency) {
      final batch = allParagraphs.sublist(
        i,
        (i + _kWarmupConcurrency).clamp(0, allParagraphs.length),
      );
      await Future.wait(
        batch.map((task) async {
          final detail = await _api.fetchParagraphDetail(
            task.lawCode,
            task.paragraph.number,
          );
          await _cacheDatabase.upsertParagraphDetail(task.lawCode, detail);
          completedSteps += 1;
          onProgress(
            CacheWarmupProgress(
              completedSteps: completedSteps,
              totalSteps: totalSteps,
              currentTask: '${task.lawCode} § ${task.paragraph.number}',
            ),
          );
        }),
      );
    }
  }

  Future<List<LawSummary>> getLaws() => _fetchWithFallback(
    fetch: () async {
      final laws = await _api.fetchLaws();
      await _cacheDatabase.replaceLaws(laws);
      return laws;
    },
    cache: () async {
      final cached = await _cacheDatabase.readLaws();
      return cached.isEmpty ? null : cached;
    },
    offlineError: 'Offline und keine zwischengespeicherten Gesetze vorhanden.',
  );

  Future<List<ParagraphSummary>> getParagraphs(String lawCode) =>
      _fetchWithFallback(
        fetch: () async {
          final paragraphs = await _api.fetchParagraphs(lawCode);
          await _cacheDatabase.replaceParagraphs(lawCode, paragraphs);
          return paragraphs;
        },
        cache: () async {
          final cached = await _cacheDatabase.readParagraphs(lawCode);
          return cached.isEmpty ? null : cached;
        },
        offlineError:
            'Offline und keine zwischengespeicherten Paragraphen vorhanden.',
      );

  Future<ParagraphDetail> getParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) => _fetchWithFallback(
    fetch: () async {
      final detail = await _api.fetchParagraphDetail(lawCode, paragraphNumber);
      await _cacheDatabase.upsertParagraphDetail(lawCode, detail);
      return detail;
    },
    cache: () => _cacheDatabase.readParagraphDetail(lawCode, paragraphNumber),
    offlineError: 'Offline und kein zwischengespeicherter Paragraph vorhanden.',
  );

  Future<List<LawSummary>?> getCachedLaws() async {
    final cached = await _cacheDatabase.readLaws();
    return cached.isEmpty ? null : cached;
  }

  Future<List<ParagraphSummary>?> getCachedParagraphs(String lawCode) async {
    final cached = await _cacheDatabase.readParagraphs(lawCode);
    return cached.isEmpty ? null : cached;
  }

  Future<ParagraphDetail?> getCachedParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) => _cacheDatabase.readParagraphDetail(lawCode, paragraphNumber);

  Future<List<LawSummary>?> silentRefreshLaws() async {
    if (!await _isOnline()) return null;
    try {
      final laws = await _api.fetchLaws();
      await _cacheDatabase.replaceLaws(laws);
      return laws;
    } catch (_) {
      return null;
    }
  }

  Future<List<ParagraphSummary>?> silentRefreshParagraphs(
    String lawCode,
  ) async {
    if (!await _isOnline()) return null;
    try {
      final paragraphs = await _api.fetchParagraphs(lawCode);
      await _cacheDatabase.replaceParagraphs(lawCode, paragraphs);
      return paragraphs;
    } catch (_) {
      return null;
    }
  }

  Future<ParagraphDetail?> silentRefreshParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) async {
    if (!await _isOnline()) return null;
    try {
      final detail = await _api.fetchParagraphDetail(lawCode, paragraphNumber);
      await _cacheDatabase.upsertParagraphDetail(lawCode, detail);
      return detail;
    } catch (_) {
      return null;
    }
  }

  Future<T> _fetchWithFallback<T>({
    required Future<T> Function() fetch,
    required Future<T?> Function() cache,
    required String offlineError,
  }) async {
    if (await _isOnline()) {
      try {
        return await fetch();
      } catch (_) {
        final cached = await cache();
        if (cached != null) return cached;
        rethrow;
      }
    }

    final cached = await cache();
    if (cached != null) return cached;

    throw Exception(offlineError);
  }

  Future<bool> _isOnline() async {
    final now = DateTime.now();
    final lastCheck = _lastConnectivityCheck;
    final lastResult = _lastConnectivityResult;
    if (lastCheck != null &&
        lastResult != null &&
        now.difference(lastCheck) < _kConnectivityCacheDuration) {
      return lastResult;
    }

    final results = await _connectivity.checkConnectivity();
    _lastConnectivityCheck = now;
    _lastConnectivityResult = !results.contains(ConnectivityResult.none);
    return _lastConnectivityResult!;
  }
}
