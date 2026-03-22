import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/laws_repository.dart';
import '../models/summaries.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/list_states.dart';
import '../widgets/section_app_bar.dart';
import 'section_detail_page.dart';

class RootListPage extends StatefulWidget {
  const RootListPage({super.key});

  @override
  State<RootListPage> createState() => _RootListPageState();
}

class _RootListPageState extends State<RootListPage> {
  final LawsRepository _lawsRepository = LawsRepository();
  final TextEditingController _searchController = TextEditingController();

  List<LawSummary>? _laws;
  Object? _error;
  CacheWarmupProgress? _cacheWarmupProgress;
  bool _isWarmingUpCache = false;
  String _query = '';

  List<LawSummary> get _filteredLaws {
    final laws = _laws ?? const <LawSummary>[];
    if (_query.isEmpty) return laws;
    final q = _query.toLowerCase();
    return laws
        .where((law) =>
            law.name.toLowerCase().contains(q) ||
            law.code.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    final cached = await _lawsRepository.getCachedLaws();
    if (!mounted) return;
    if (cached != null) setState(() => _laws = cached);

    final fresh = await _lawsRepository.silentRefreshLaws();
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _laws = fresh;
        _error = null;
      });
    } else if (cached == null) {
      setState(() {
        _error = Exception(
          'Offline und keine zwischengespeicherten Gesetze vorhanden.',
        );
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final laws = await _lawsRepository.getLaws();
      if (!mounted) return;
      setState(() {
        _laws = laws;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_laws == null) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _warmUpCache() async {
    if (_isWarmingUpCache) return;

    setState(() {
      _isWarmingUpCache = true;
      _cacheWarmupProgress = const CacheWarmupProgress(
        completedSteps: 0,
        totalSteps: null,
        currentTask: 'Verbinde...',
      );
    });

    try {
      await _lawsRepository.warmUpCache(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _cacheWarmupProgress = progress);
        },
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache wurde vollstaendig aktualisiert.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cache-Aktualisierung fehlgeschlagen: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWarmingUpCache = false;
          _cacheWarmupProgress = null;
        });
      }
    }
  }

  void _openSectionDetail(LawSummary law) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SectionDetailPage(law: law),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SectionAppBar(
        title: 'Gesetz im Netz',
        showRootBrand: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CacheWarmupButton(
              isLoading: _isWarmingUpCache,
              progress: _cacheWarmupProgress,
              onPressed: _warmUpCache,
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_laws == null && _error == null) {
            return LoadingListView(onRefresh: _refresh);
          }

          if (_error != null) {
            return ErrorListView(
              onRefresh: _refresh,
              icon: Icons.cloud_off_rounded,
              title: 'Die Gesetzesliste konnte gerade nicht geladen werden.',
              detail: '$_error',
            );
          }

          final laws = _filteredLaws;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Gesetz suchen…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: laws.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 80),
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kein Gesetz gefunden für „$_query".',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            MediaQuery.of(context).padding.bottom + 32,
                          ),
                          itemCount: laws.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final law = laws[index];
                            return AppListTile(
                              title: law.name,
                              subtitle: law.code,
                              onTap: () => _openSectionDetail(law),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
