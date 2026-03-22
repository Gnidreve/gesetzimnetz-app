import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'theme.dart';

const String kAppSansFont = 'Segoe UI';
const List<String> kAppSansFallback = <String>['Helvetica', 'Arial'];
const String kAppSerifFont = 'Georgia';
const List<String> kAppSerifFallback = <String>['Times New Roman'];

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D7A)),
        fontFamily: kAppSansFont,
        fontFamilyFallback: kAppSansFallback,
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: kAppSansFont,
          fontFamilyFallback: kAppSansFallback,
        ),
        primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
          fontFamily: kAppSansFont,
          fontFamilyFallback: kAppSansFallback,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kAppBackgroundColor,
      ),
      home: const RootListPage(),
    );
  }
}

class RootListPage extends StatefulWidget {
  const RootListPage({super.key});

  @override
  State<RootListPage> createState() => _RootListPageState();
}

class _RootListPageState extends State<RootListPage> {
  final LawsRepository _lawsRepository = LawsRepository();
  List<LawSummary>? _laws;
  Object? _error;
  CacheWarmupProgress? _cacheWarmupProgress;
  bool _isWarmingUpCache = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    final cached = await _lawsRepository.getCachedLaws();
    if (!mounted) return;
    if (cached != null) setState(() => _laws = cached);

    final fresh = await _lawsRepository.silentRefreshLaws();
    if (!mounted) return;
    if (fresh != null) {
      setState(() { _laws = fresh; _error = null; });
    } else if (cached == null) {
      setState(() => _error = Exception(
        'Offline und keine zwischengespeicherten Gesetze vorhanden.',
      ));
    }
  }

  Future<void> _refresh() async {
    try {
      final laws = await _lawsRepository.getLaws();
      if (!mounted) return;
      setState(() { _laws = laws; _error = null; });
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
    if (_isWarmingUpCache) {
      return;
    }

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
          if (!mounted) {
            return;
          }

          setState(() {
            _cacheWarmupProgress = progress;
          });
        },
      );

      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache wurde vollstaendig aktualisiert.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SectionAppBar(
        title: 'Gesetz im Netz',
        showRootBrand: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CacheWarmupButton(
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

          final laws = _laws ?? const <LawSummary>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: laws.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final law = laws[index];
                return AppListTile(
                  title: law.name,
                  subtitle: law.code,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => SectionDetailPage(law: law),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
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
      setState(() { _paragraphs = fresh; _error = null; });
    } else if (cached == null) {
      setState(() => _error = Exception(
        'Offline und keine zwischengespeicherten Paragraphen vorhanden.',
      ));
    }
  }

  Future<void> _refresh() async {
    try {
      final paragraphs = await _lawsRepository.getParagraphs(widget.law.code);
      if (!mounted) return;
      setState(() { _paragraphs = paragraphs; _error = null; });
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

  Future<void> _openSheet(ParagraphSummary paragraph) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          DetailBottomSheet(lawCode: widget.law.code, paragraph: paragraph),
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
                  titleWidget: ParagraphTitle(
                    number: paragraph.number,
                    title: paragraph.title,
                  ),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 18,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _openSheet(paragraph),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class DetailBottomSheet extends StatefulWidget {
  const DetailBottomSheet({
    required this.lawCode,
    required this.paragraph,
    super.key,
  });

  final String lawCode;
  final ParagraphSummary paragraph;

  @override
  State<DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<DetailBottomSheet> {
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
      setState(() => _detail = fresh);
    } else if (cached == null) {
      setState(() => _error = Exception(
        'Der Paragraph konnte gerade nicht geladen werden.',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Builder(
            builder: (context) {
              if (_detail == null && _error == null) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    const SheetGrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: SheetHeader(
                        title: widget.paragraph.displayTitle,
                        showCloseButton: false,
                      ),
                    ),
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              if (_error != null) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    const SheetGrip(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: SheetHeader(
                        title: widget.paragraph.displayTitle,
                        showCloseButton: false,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        children: [
                          const SizedBox(height: 48),
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_error',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final detail = _detail!;
              final contentNodes = detail.contentNodes;

              return Column(
                children: [
                  const SizedBox(height: 10),
                  const SheetGrip(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: SheetHeader(
                      title: detail.displayTitle,
                      showCloseButton: false,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: contentNodes.length,
                      itemBuilder: (context, index) {
                        return ContentCard(node: contentNodes[index]);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({
    required this.title,
    this.showRootBrand = false,
    this.actions,
    super.key,
  });

  final String title;
  final bool showRootBrand;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showRootBrand
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset('favicon.svg', width: 33, height: 33),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      actions: actions,
    );
  }
}

class _CacheWarmupButton extends StatelessWidget {
  const _CacheWarmupButton({
    required this.isLoading,
    required this.progress,
    required this.onPressed,
  });

  final bool isLoading;
  final CacheWarmupProgress? progress;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentageLabel = progress?.percentageLabel;
    final tooltip = isLoading
        ? (progress?.currentTask ?? 'Cache wird aktualisiert')
        : 'Gesamten Cache aktualisieren';

    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          minimumSize: const Size(0, 40),
        ),
        icon: SizedBox(
          width: 18,
          height: 18,
          child: isLoading
              ? CircularProgressIndicator(
                  strokeWidth: 2.2,
                  value: progress?.progressValue,
                  color: colorScheme.primary,
                )
              : Icon(Icons.sync_rounded, size: 18, color: colorScheme.primary),
        ),
        label: Text(
          isLoading ? (percentageLabel ?? '...') : 'Cache',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.onTap,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.trailing = const Icon(Icons.chevron_right_rounded),
    super.key,
  });

  final VoidCallback onTap;
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget ??
                        Text(
                          title ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class ParagraphTitle extends StatelessWidget {
  const ParagraphTitle({required this.number, required this.title, super.key});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w400,
      color: const Color(0xFF526377),
      height: 1.25,
    );
    final numberStyle = style?.copyWith(
      fontWeight: FontWeight.w700,
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

class SheetGrip extends StatelessWidget {
  const SheetGrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({
    required this.title,
    this.showCloseButton = true,
    super.key,
  });

  final String title;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(minHeight: kToolbarHeight),
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            if (showCloseButton)
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContentCard extends StatelessWidget {
  const ContentCard({required this.node, super.key});

  final ParagraphContentNode node;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _ParagraphContentNodeView(node: node),
    );
  }
}

class _ParagraphContentNodeView extends StatelessWidget {
  const _ParagraphContentNodeView({required this.node, this.depth = 0});

  final ParagraphContentNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontFamily: kAppSerifFont,
      fontFamilyFallback: kAppSerifFallback,
      height: 1.5,
    );

    final hasText = node.text.isNotEmpty;
    final indentation = depth * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indentation),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasText) SelectableText(node.text, style: textStyle),
          if (hasText && node.children.isNotEmpty) const SizedBox(height: 12),
          for (var index = 0; index < node.children.length; index++) ...[
            _ParagraphContentNodeView(
              node: node.children[index],
              depth: depth + 1,
            ),
            if (index != node.children.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class LoadingListView extends StatelessWidget {
  const LoadingListView({required this.onRefresh, super.key});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class ErrorListView extends StatelessWidget {
  const ErrorListView({
    required this.onRefresh,
    required this.icon,
    required this.title,
    this.detail,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: onRefresh, child: const Text('Erneut laden')),
        ],
      ),
    );
  }
}

class LawSummary {
  const LawSummary({required this.code, required this.name});

  factory LawSummary.fromJson(Map<String, dynamic> json) {
    return LawSummary(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
    );
  }

  final String code;
  final String name;

  Map<String, Object?> toDbMap(int sortIndex) {
    return <String, Object?>{
      'code': code,
      'name': name,
      'sort_index': sortIndex,
    };
  }

  factory LawSummary.fromDb(Map<String, Object?> map) {
    return LawSummary(
      code: (map['code'] as String? ?? '').trim(),
      name: (map['name'] as String? ?? '').trim(),
    );
  }
}

class ParagraphSummary {
  const ParagraphSummary({required this.number, required this.title});

  factory ParagraphSummary.fromJson(Map<String, dynamic> json) {
    return ParagraphSummary(
      number: (json['paragraph_number'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
    );
  }

  final String number;
  final String title;

  String get displayTitle => '§ $number $title';

  Map<String, Object?> toDbMap(String lawCode, int sortIndex) {
    return <String, Object?>{
      'law_code': lawCode,
      'paragraph_number': number,
      'title': title,
      'sort_index': sortIndex,
    };
  }

  factory ParagraphSummary.fromDb(Map<String, Object?> map) {
    return ParagraphSummary(
      number: (map['paragraph_number'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
    );
  }
}

class ParagraphDetail {
  const ParagraphDetail({
    required this.number,
    required this.title,
    required this.contentNodes,
  });

  factory ParagraphDetail.fromJson(Map<String, dynamic> json) {
    final paragraphJson = Map<String, dynamic>.from(
      json['paragraph'] as Map<dynamic, dynamic>? ?? const <String, dynamic>{},
    );

    return ParagraphDetail(
      number: (paragraphJson['paragraph_number'] as String? ?? '').trim(),
      title: (paragraphJson['title'] as String? ?? '').trim(),
      contentNodes: ParagraphContentNode.listFromDynamic(
        paragraphJson['content'],
      ),
    );
  }

  final String number;
  final String title;
  final List<ParagraphContentNode> contentNodes;

  String get displayTitle => '§ $number $title';

  Map<String, Object?> toDbMap(String lawCode) {
    return <String, Object?>{
      'law_code': lawCode,
      'paragraph_number': number,
      'title': title,
      'content': jsonEncode(
        contentNodes.map((node) => node.toJson()).toList(growable: false),
      ),
    };
  }

  factory ParagraphDetail.fromDb(Map<String, Object?> map) {
    final rawContent = (map['content'] as String? ?? '').trim();

    return ParagraphDetail(
      number: (map['paragraph_number'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      contentNodes: ParagraphContentNode.listFromStoredValue(rawContent),
    );
  }
}

class ParagraphContentNode {
  const ParagraphContentNode({
    required this.text,
    this.children = const <ParagraphContentNode>[],
  });

  factory ParagraphContentNode.fromDynamic(dynamic value) {
    if (value is String) {
      return ParagraphContentNode(text: _normalizeText(value));
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return ParagraphContentNode(
        text: _normalizeText(map['text'] as String? ?? ''),
        children: listFromDynamic(
          map['children'],
          fallbackToPlaceholder: false,
        ),
      );
    }

    return const ParagraphContentNode(text: '');
  }

  final String text;
  final List<ParagraphContentNode> children;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      if (children.isNotEmpty)
        'children': children
            .map((node) => node.toJson())
            .toList(growable: false),
    };
  }

  static List<ParagraphContentNode> listFromDynamic(
    dynamic value, {
    bool fallbackToPlaceholder = true,
  }) {
    if (value is List) {
      final nodes = value
          .map(ParagraphContentNode.fromDynamic)
          .where((node) => node.text.isNotEmpty || node.children.isNotEmpty)
          .toList(growable: false);

      if (nodes.isNotEmpty || !fallbackToPlaceholder) {
        return nodes;
      }

      return const <ParagraphContentNode>[
        ParagraphContentNode(text: 'Kein Inhalt vorhanden.'),
      ];
    }

    if (value is String) {
      final normalized = _normalizeText(value);
      if (normalized.isEmpty) {
        if (!fallbackToPlaceholder) {
          return const <ParagraphContentNode>[];
        }

        return const <ParagraphContentNode>[
          ParagraphContentNode(text: 'Kein Inhalt vorhanden.'),
        ];
      }

      return <ParagraphContentNode>[ParagraphContentNode(text: normalized)];
    }

    if (!fallbackToPlaceholder) {
      return const <ParagraphContentNode>[];
    }

    return const <ParagraphContentNode>[
      ParagraphContentNode(text: 'Kein Inhalt vorhanden.'),
    ];
  }

  static List<ParagraphContentNode> listFromStoredValue(String rawContent) {
    if (rawContent.isEmpty) {
      return const <ParagraphContentNode>[
        ParagraphContentNode(text: 'Kein Inhalt vorhanden.'),
      ];
    }

    try {
      final decoded = jsonDecode(rawContent);
      return listFromDynamic(decoded);
    } on FormatException {
      return listFromDynamic(rawContent);
    }
  }

  static String _normalizeText(String value) {
    return value
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .trim();
  }
}

class LawsApi {
  static final Uri _rootUri = Uri.parse('https://gesetzimnetz.de/api');

  final http.Client _client;

  LawsApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<LawSummary>> fetchLaws() async {
    final decoded = await _getJson(_rootUri);
    final lawsJson = decoded['laws'];

    if (lawsJson is! List) {
      throw const FormatException('Ungueltiges API-Format');
    }

    return lawsJson
        .map((item) => LawSummary.fromJson(Map<String, dynamic>.from(item)))
        .where((law) => law.code.isNotEmpty && law.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ParagraphSummary>> fetchParagraphs(String lawCode) async {
    final decoded = await _getJson(
      Uri.parse('https://gesetzimnetz.de/api/$lawCode'),
    );
    final paragraphsJson = decoded['paragraphs'];

    if (paragraphsJson is! List) {
      throw const FormatException('Ungueltiges API-Format');
    }

    return paragraphsJson
        .map(
          (item) => ParagraphSummary.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((paragraph) => paragraph.number.isNotEmpty)
        .toList(growable: false);
  }

  Future<ParagraphDetail> fetchParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) async {
    final decoded = await _getJson(
      Uri.parse('https://gesetzimnetz.de/api/$lawCode/$paragraphNumber'),
    );

    return ParagraphDetail.fromJson(decoded);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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

  final LawsApi _api;
  final LawsCacheDatabase _cacheDatabase;
  final Connectivity _connectivity;

  DateTime? _lastConnectivityCheck;
  bool? _lastConnectivityResult;
  static const _kConnectivityCacheDuration = Duration(seconds: 3);

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

  // Cache-only reads — sofort, kein Netzwerk
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

  // Stille Netzwerk-Aktualisierungen — null bei Fehler oder Offline
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
    if (total == null || total <= 0) {
      return null;
    }

    return completedSteps / total;
  }

  String? get percentageLabel {
    final progress = progressValue;
    if (progress == null) {
      return null;
    }

    return '${(progress * 100).clamp(0, 100).round()}%';
  }
}

class LawsCacheDatabase {
  LawsCacheDatabase._();

  static final LawsCacheDatabase _instance = LawsCacheDatabase._();

  factory LawsCacheDatabase() => _instance;

  static const String _databaseName = 'gesetz_im_netz_cache.db';
  static const int _databaseVersion = 2;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS paragraph_details');
          await db.execute('''
            CREATE TABLE paragraph_details (
              law_code TEXT NOT NULL,
              paragraph_number TEXT NOT NULL,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              PRIMARY KEY (law_code, paragraph_number)
            )
          ''');
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE laws (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_index INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE paragraphs (
        law_code TEXT NOT NULL,
        paragraph_number TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        PRIMARY KEY (law_code, paragraph_number)
      )
    ''');
    await db.execute('''
      CREATE TABLE paragraph_details (
        law_code TEXT NOT NULL,
        paragraph_number TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        PRIMARY KEY (law_code, paragraph_number)
      )
    ''');
  }

  Future<void> replaceLaws(List<LawSummary> laws) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('laws');
      for (var index = 0; index < laws.length; index++) {
        await txn.insert('laws', laws[index].toDbMap(index));
      }
    });
  }

  Future<List<LawSummary>> readLaws() async {
    final db = await database;
    final rows = await db.query('laws', orderBy: 'sort_index ASC');

    return rows.map(LawSummary.fromDb).toList(growable: false);
  }

  Future<void> replaceParagraphs(
    String lawCode,
    List<ParagraphSummary> paragraphs,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'paragraphs',
        where: 'law_code = ?',
        whereArgs: <Object?>[lawCode],
      );
      for (var index = 0; index < paragraphs.length; index++) {
        await txn.insert(
          'paragraphs',
          paragraphs[index].toDbMap(lawCode, index),
        );
      }
    });
  }

  Future<List<ParagraphSummary>> readParagraphs(String lawCode) async {
    final db = await database;
    final rows = await db.query(
      'paragraphs',
      where: 'law_code = ?',
      whereArgs: <Object?>[lawCode],
      orderBy: 'sort_index ASC',
    );

    return rows.map(ParagraphSummary.fromDb).toList(growable: false);
  }

  Future<void> upsertParagraphDetail(
    String lawCode,
    ParagraphDetail detail,
  ) async {
    final db = await database;
    await db.insert(
      'paragraph_details',
      detail.toDbMap(lawCode),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ParagraphDetail?> readParagraphDetail(
    String lawCode,
    String paragraphNumber,
  ) async {
    final db = await database;
    final rows = await db.query(
      'paragraph_details',
      where: 'law_code = ? AND paragraph_number = ?',
      whereArgs: <Object?>[lawCode, paragraphNumber],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ParagraphDetail.fromDb(rows.first);
  }
}
