import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const MainApp());
}

final List<SectionItem> demoSections = List.generate(
  6,
  (sectionIndex) => SectionItem(
    title: 'Abschnitt ${sectionIndex + 1}',
    entries: List.generate(
      8,
      (entryIndex) => DetailItem(
        title: 'Eintrag ${sectionIndex + 1}.${entryIndex + 1}',
        paragraphs: List.generate(
          10,
          (paragraphIndex) =>
              'Lorem ipsum fuer ${sectionIndex + 1}.${entryIndex + 1} - '
              'Absatz ${paragraphIndex + 1}. Hier kann spaeter dein echter '
              'Backend-Content eingebunden werden.',
        ),
      ),
    ),
  ),
);

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D7A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
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
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SectionAppBar(
        title: 'Gesetz im Netz',
        showRootBrand: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: demoSections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final section = demoSections[index];
            return OrderedListTile(
              index: index + 1,
              title: section.title,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => SectionDetailPage(section: section),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class SectionDetailPage extends StatefulWidget {
  const SectionDetailPage({required this.section, super.key});

  final SectionItem section;

  @override
  State<SectionDetailPage> createState() => _SectionDetailPageState();
}

class _SectionDetailPageState extends State<SectionDetailPage> {
  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _openSheet(DetailItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DetailBottomSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SectionAppBar(title: widget.section.title),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: widget.section.entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = widget.section.entries[index];
            return OrderedListTile(
              index: index + 1,
              title: entry.title,
              onTap: () => _openSheet(entry),
            );
          },
        ),
      ),
    );
  }
}

class DetailBottomSheet extends StatelessWidget {
  const DetailBottomSheet({required this.item, super.key});

  final DetailItem item;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      shouldCloseOnMinExtent: true,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SheetHeader(title: item.title),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: item.paragraphs.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item.paragraphs[index],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    );
                  },
                ),
              ),
            ],
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
    super.key,
  });

  final String title;
  final bool showRootBrand;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showRootBrand
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'favicon.svg',
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(title)),
              ],
            )
          : Text(title),
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    );
  }
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        height: kToolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderedListTile extends StatelessWidget {
  const OrderedListTile({
    required this.index,
    required this.title,
    required this.onTap,
    super.key,
  });

  final int index;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$index.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionItem {
  const SectionItem({
    required this.title,
    required this.entries,
  });

  final String title;
  final List<DetailItem> entries;
}

class DetailItem {
  const DetailItem({
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;
}
