import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/laws_repository.dart';
import '../theme.dart';
import '../models/summaries.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/list_states.dart';
import '../widgets/section_app_bar.dart';
import 'paragraph_detail_page.dart';

class _ParagraphTitle extends StatelessWidget {
  const _ParagraphTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: kWeightNormal,
      color: const Color(0xFF526377),
      height: 1.25,
    );
    final numberStyle = style?.copyWith(
      fontWeight: kWeightBold,
      color: const Color(0xFF102A43),
    );

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '§ $number', style: numberStyle),
          const WidgetSpan(child: SizedBox(width: 14)),
          TextSpan(text: title),
        ],
      ),
    );
  }
}

class SectionDetailPage extends StatefulWidget {
  const SectionDetailPage({required this.law, super.key});

  final LawSummary law;

  @override
  State<SectionDetailPage> createState() => _SectionDetailPageState();
}

class _SectionDetailPageState extends State<SectionDetailPage> {
  final LawsRepository _lawsRepository = LawsRepository();
  final TextEditingController _searchController = TextEditingController();

  List<ParagraphSummary>? _paragraphs;
  Object? _error;
  String _query = '';

  List<ParagraphSummary> get _filteredParagraphs {
    final paragraphs = _paragraphs ?? const <ParagraphSummary>[];
    if (_query.isEmpty) return paragraphs;
    final q = _query.toLowerCase();
    return paragraphs
        .where((p) =>
            p.number.toLowerCase().contains(q) ||
            p.title.toLowerCase().contains(q))
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
    final cached = await _lawsRepository.getCachedParagraphs(widget.law.code);
    if (!mounted) return;
    if (cached != null) setState(() => _paragraphs = cached);

    final fresh = await _lawsRepository.silentRefreshParagraphs(widget.law.code);
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _paragraphs = fresh;
        _error = null;
      });
    } else if (cached == null) {
      setState(() {
        _error = Exception(
          'Offline und keine zwischengespeicherten Paragraphen vorhanden.',
        );
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final paragraphs = await _lawsRepository.getParagraphs(widget.law.code);
      if (!mounted) return;
      setState(() {
        _paragraphs = paragraphs;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_paragraphs == null) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _openParagraphDetail(int indexInFullList) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ParagraphDetailPage(
          lawCode: widget.law.code,
          paragraphs: _paragraphs!,
          initialIndex: indexInFullList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SectionAppBar(title: widget.law.name),
      body: Builder(
        builder: (context) {
          if (_paragraphs == null && _error == null) {
            return LoadingListView(onRefresh: _refresh);
          }

          if (_error != null) {
            return ErrorListView(
              onRefresh: _refresh,
              icon: Icons.cloud_off_rounded,
              title: 'Die Paragraphen konnten gerade nicht geladen werden.',
              detail: '$_error',
            );
          }

          if (_paragraphs!.isEmpty) {
            return ErrorListView(
              onRefresh: _refresh,
              icon: Icons.menu_book_rounded,
              title: 'Fuer dieses Gesetz wurden noch keine Paragraphen gefunden.',
            );
          }

          final paragraphs = _filteredParagraphs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF102A43),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paragraph suchen…',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF526377),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF526377),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 0,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFF526377),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: false,
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0x4D526377),
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFF102A43),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: paragraphs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 60),
                            const Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: Color(0xFF526377),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Kein Paragraph gefunden für „$_query".',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF526377),
                              ),
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
                          itemCount: paragraphs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final paragraph = paragraphs[index];
                            final realIndex = _paragraphs!.indexOf(paragraph);
                            return AppListTile(
                              titleWidget: _ParagraphTitle(
                                number: paragraph.number,
                                title: paragraph.title,
                              ),
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 18,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                              onTap: () => _openParagraphDetail(realIndex),
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
