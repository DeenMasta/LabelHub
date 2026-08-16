import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class ImportDocument {
  const ImportDocument({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

class ImportParser {
  const ImportParser();

  ImportDocument parseCsv(String source) {
    final table = Csv(dynamicTyping: false).decode(source);
    if (table.isEmpty) {
      throw const FormatException('The CSV file is empty.');
    }
    return _processTable(table);
  }

  ImportDocument parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('The Excel file has no sheets.');
    }
    
    // Read the first available sheet
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;
    
    if (table.rows.isEmpty) {
      throw const FormatException('The Excel sheet is empty.');
    }

    final rawTable = table.rows.map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();

    return _processTable(rawTable);
  }

  ImportDocument _processTable(List<List<dynamic>> table) {
    final headers = table.first
        .map((Object? value) => '$value'.trim())
        .toList();
    
    if (headers.isEmpty || headers.any((String header) => header.isEmpty)) {
      throw const FormatException('Every column must have a header.');
    }
    if (headers.toSet().length != headers.length) {
      throw const FormatException('Headers must be unique.');
    }
    
    return ImportDocument(
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
