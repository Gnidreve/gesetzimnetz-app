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
  List<ParagraphSummary>? _paragraphs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialLoad();
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

  Future<void> _openParagraphDetail(int index) {
    return Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ParagraphDetailPage(
          lawCode: widget.law.code,
          paragraphs: _paragraphs!,
          initialIndex: index,
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

          final paragraphs = _paragraphs ?? const <ParagraphSummary>[];

          if (paragraphs.isEmpty) {
            return ErrorListView(
              onRefresh: _refresh,
              icon: Icons.menu_book_rounded,
              title:
                  'Fuer dieses Gesetz wurden noch keine Paragraphen gefunden.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: paragraphs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final paragraph = paragraphs[index];
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
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _openParagraphDetail(index),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
