import 'dart:convert';

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

      final decodedJson = _tryDecodeJson(normalized);
      if (decodedJson != null) {
        return listFromDynamic(
          decodedJson,
          fallbackToPlaceholder: fallbackToPlaceholder,
        );
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

  static dynamic _tryDecodeJson(String value) {
    final trimmed = value.trimLeft();
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
      return null;
    }

    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
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

  factory ParagraphDetail.fromDb(Map<String, Object?> map) {
    final rawContent = (map['content'] as String? ?? '').trim();

    return ParagraphDetail(
      number: (map['paragraph_number'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      contentNodes: ParagraphContentNode.listFromStoredValue(rawContent),
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
}
