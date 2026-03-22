import 'package:flutter/material.dart';

import '../data/laws_repository.dart';
import '../models/paragraph_detail.dart';
import '../models/summaries.dart';
import '../widgets/content_card.dart';
import '../widgets/list_states.dart';
import '../widgets/section_app_bar.dart';

class ParagraphDetailPage extends StatefulWidget {
  const ParagraphDetailPage({
    required this.lawCode,
    required this.paragraphs,
    required this.initialIndex,
    super.key,
  });

  final String lawCode;
  final List<ParagraphSummary> paragraphs;
  final int initialIndex;

  @override
  State<ParagraphDetailPage> createState() => _ParagraphDetailPageState();
}

class _ParagraphDetailPageState extends State<ParagraphDetailPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paragraph = widget.paragraphs[_currentIndex];

    return Scaffold(
      appBar: SectionAppBar(title: '§ ${paragraph.number} | ${paragraph.title}'),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.paragraphs.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return _ParagraphPage(
            lawCode: widget.lawCode,
            paragraph: widget.paragraphs[index],
          );
        },
      ),
    );
  }
}

class _ParagraphPage extends StatefulWidget {
  const _ParagraphPage({required this.lawCode, required this.paragraph});

  final String lawCode;
  final ParagraphSummary paragraph;

  @override
  State<_ParagraphPage> createState() => _ParagraphPageState();
}

class _ParagraphPageState extends State<_ParagraphPage> {
  final LawsRepository _lawsRepository = LawsRepository();
  ParagraphDetail? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final cached = await _lawsRepository.getCachedParagraphDetail(
      widget.lawCode,
      widget.paragraph.number,
    );
    if (!mounted) return;
    if (cached != null) setState(() => _detail = cached);

    final fresh = await _lawsRepository.silentRefreshParagraphDetail(
      widget.lawCode,
      widget.paragraph.number,
    );
    if (!mounted) return;
    if (fresh != null) {
      setState(() {
        _detail = fresh;
        _error = null;
      });
    } else if (cached == null) {
      setState(() {
        _error = Exception('Der Paragraph konnte gerade nicht geladen werden.');
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final detail = await _lawsRepository.getParagraphDetail(
        widget.lawCode,
        widget.paragraph.number,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_detail == null) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aktualisierung fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_detail == null && _error == null) {
      return LoadingListView(onRefresh: _refresh);
    }

    if (_error != null) {
      return ErrorListView(
        onRefresh: _refresh,
        icon: Icons.cloud_off_rounded,
        title: 'Der Paragraph konnte gerade nicht geladen werden.',
        detail: '$_error',
      );
    }

    final contentNodes = _detail!.contentNodes;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: contentNodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          return ContentCard(node: contentNodes[index]);
        },
      ),
    );
  }
}
