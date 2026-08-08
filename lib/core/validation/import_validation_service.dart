import '../../features/templates/domain/entities/import_template.dart';

/// Applies the same field and barcode rules for every import file format.
class ImportValidationService {
  const ImportValidationService();

  ImportValidationResult validate({
    required ImportTemplate template,
    required List<String> headers,
    required List<List<String>> rows,
    required Map<String, String?> columnMapping,
    required Set<String> existingBarcodeValues,
  }) {
    final results = <ValidatedImportRow>[];
    final seenBarcodes = <String>{...existingBarcodeValues};

    for (var index = 0; index < rows.length; index++) {
      final sourceRow = rows[index];
      final values = <String, String>{};
      final issues = <ImportValidationIssue>[];
      for (final field in template.fields) {
        final header = columnMapping[field.key];
        final headerIndex = header == null ? -1 : headers.indexOf(header);
        final value = headerIndex >= 0 && headerIndex < sourceRow.length
            ? sourceRow[headerIndex].trim()
            : '';
        values[field.key] = value;

        if (field.required && value.isEmpty) {
          issues.add(
            ImportValidationIssue(
              rowNumber: index + 2,
              fieldKey: field.key,
              message: '${field.displayName} is required.',
            ),
          );
          continue;
        }
        if (value.isNotEmpty && !_matchesDataType(value, field.dataType)) {
          issues.add(
            ImportValidationIssue(
              rowNumber: index + 2,
              fieldKey: field.key,
              message:
                  '${field.displayName} has an invalid ${field.dataType.name} value.',
            ),
          );
        }
      }

      final barcode = values[template.barcodeFieldKey] ?? '';
      if (barcode.isNotEmpty &&
          !_isValidBarcode(barcode, template.barcodeFormat)) {
        issues.add(
          ImportValidationIssue(
            rowNumber: index + 2,
            fieldKey: template.barcodeFieldKey,
            message: 'Barcode does not match the selected format.',
          ),
        );
      }
      if (barcode.isNotEmpty && seenBarcodes.contains(barcode)) {
        issues.add(
          ImportValidationIssue(
            rowNumber: index + 2,
            fieldKey: template.barcodeFieldKey,
            message: 'Barcode already exists or is duplicated in this file.',
          ),
        );
      }
      if (barcode.isNotEmpty) {
        seenBarcodes.add(barcode);
      }
      results.add(
        ValidatedImportRow(
          rowNumber: index + 2,
          values: values,
          issues: issues,
        ),
      );
    }
    return ImportValidationResult(rows: results);
  }

  bool _matchesDataType(String value, FieldDataType type) {
    return switch (type) {
      FieldDataType.text => true,
      FieldDataType.integer => int.tryParse(value) != null,
      FieldDataType.decimal => double.tryParse(value) != null,
      FieldDataType.date =>
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
            DateTime.tryParse(value) != null,
    };
  }

  bool _isValidBarcode(String value, BarcodeFormat format) {
    return switch (format) {
      BarcodeFormat.code128 =>
        value.isNotEmpty && !value.contains(RegExp(r'[\x00-\x1f\x7f-\xff]')),
      BarcodeFormat.code39 => RegExp(r'^[0-9A-Z \-\.\$/\+%]+$').hasMatch(value),
      BarcodeFormat.ean13 =>
        RegExp(r'^\d{13}$').hasMatch(value) && _hasValidEan13CheckDigit(value),
      BarcodeFormat.qrCode => value.isNotEmpty,
    };
  }

  bool _hasValidEan13CheckDigit(String value) {
    var sum = 0;
    for (var index = 0; index < 12; index++) {
      final digit = int.parse(value[index]);
      sum += index.isEven ? digit : digit * 3;
    }
    return (10 - sum % 10) % 10 == int.parse(value[12]);
  }
}

class ImportValidationResult {
  const ImportValidationResult({required this.rows});

  final List<ValidatedImportRow> rows;

  int get validRowCount =>
      rows.where((ValidatedImportRow row) => row.isValid).length;
  int get invalidRowCount => rows.length - validRowCount;
  List<ValidatedImportRow> get validRows =>
      rows.where((ValidatedImportRow row) => row.isValid).toList();
}

class ValidatedImportRow {
  const ValidatedImportRow({
    required this.rowNumber,
    required this.values,
    required this.issues,
  });

  final int rowNumber;
  final Map<String, String> values;
  final List<ImportValidationIssue> issues;

  bool get isValid => issues.isEmpty;
}

class ImportValidationIssue {
  const ImportValidationIssue({
    required this.rowNumber,
    required this.fieldKey,
    required this.message,
  });

  final int rowNumber;
  final String fieldKey;
  final String message;
}
