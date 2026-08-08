import 'package:csv/csv.dart';

class CsvImportDocument {
  const CsvImportDocument({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class CsvImportParser {
  const CsvImportParser();

  CsvImportDocument parse(String source) {
    final table = Csv(dynamicTyping: false).decode(source);
    if (table.isEmpty) {
      throw const FormatException('The CSV file is empty.');
    }
    final headers = table.first
        .map((Object? value) => '$value'.trim())
        .toList();
    if (headers.isEmpty || headers.any((String header) => header.isEmpty)) {
      throw const FormatException('Every CSV column must have a header.');
    }
    if (headers.toSet().length != headers.length) {
      throw const FormatException('CSV headers must be unique.');
    }
    return CsvImportDocument(
      headers: headers,
      rows: table
          .skip(1)
          .where(
            (List<dynamic> row) =>
                row.any((Object? value) => '$value'.trim().isNotEmpty),
          )
          .map(
            (List<dynamic> row) =>
                row.map((Object? value) => '$value').toList(),
          )
          .toList(),
    );
  }
}
