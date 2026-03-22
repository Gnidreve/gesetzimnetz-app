import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

import '../data/laws_repository.dart';

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
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: kWeightBold);

    return AppBar(
      leading: showRootBrand
          ? Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SvgPicture.asset('favicon.svg', width: 28, height: 28),
              ),
            )
          : null,
      leadingWidth: showRootBrand ? 56 : null,
      title: Text(title, style: titleStyle),
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      actions: actions,
    );
  }
}

class CacheWarmupButton extends StatelessWidget {
  const CacheWarmupButton({
    required this.isLoading,
    required this.progress,
    required this.onPressed,
    super.key,
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
            fontWeight: kWeightBold,
          ),
        ),
      ),
    );
  }
}
