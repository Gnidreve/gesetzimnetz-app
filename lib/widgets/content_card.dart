import 'package:flutter/material.dart';

import '../models/paragraph_detail.dart';
import '../theme.dart';

class ContentCard extends StatelessWidget {
  const ContentCard({required this.node, super.key});

  final ParagraphContentNode node;

  @override
  Widget build(BuildContext context) {
    return _ParagraphContentNodeView(node: node);
  }
}

class _ParagraphContentNodeView extends StatelessWidget {
  const _ParagraphContentNodeView({
    required this.node,
    this.depth = 0,
    this.siblingIndex,
  });

  final ParagraphContentNode node;
  final int depth;
  final int? siblingIndex;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: kAppSerifFont,
      fontFamilyFallback: kAppSerifFallback,
      height: 1.5,
    );

    final hasText = node.text.isNotEmpty;
    final indentation = depth == 0 ? 0.0 : 22.0;
    final prefix = depth == 0 || siblingIndex == null ? null : '${siblingIndex! + 1}.';

    final textBlock = hasText
        ? () {
            final textWidget = SelectableText(node.text, style: textStyle);
            return prefix == null
                ? textWidget
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          prefix,
                          style: textStyle,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(child: textWidget),
                    ],
                  );
          }()
        : null;

    return Padding(
      padding: EdgeInsets.only(left: indentation),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...?(textBlock == null ? null : <Widget>[textBlock]),
          if (hasText && node.children.isNotEmpty) const SizedBox(height: 6),
          for (var index = 0; index < node.children.length; index++) ...[
            _ParagraphContentNodeView(
              node: node.children[index],
              depth: depth + 1,
              siblingIndex: index,
            ),
            if (index != node.children.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
