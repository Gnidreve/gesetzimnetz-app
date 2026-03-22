class LawSummary {
  const LawSummary({required this.code, required this.name});

  factory LawSummary.fromJson(Map<String, dynamic> json) {
    return LawSummary(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
    );
  }

  factory LawSummary.fromDb(Map<String, Object?> map) {
    return LawSummary(
      code: (map['code'] as String? ?? '').trim(),
      name: (map['name'] as String? ?? '').trim(),
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
}

class ParagraphSummary {
  const ParagraphSummary({required this.number, required this.title});

  factory ParagraphSummary.fromJson(Map<String, dynamic> json) {
    return ParagraphSummary(
      number: (json['paragraph_number'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
    );
  }

  factory ParagraphSummary.fromDb(Map<String, Object?> map) {
    return ParagraphSummary(
      number: (map['paragraph_number'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
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
}
