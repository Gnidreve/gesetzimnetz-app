import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/paragraph_detail.dart';
import '../models/summaries.dart';

class LawsApi {
  static final Uri _rootUri = Uri.parse('https://gesetzimnetz.de/api');

  LawsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
