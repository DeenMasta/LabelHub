enum BarcodeFormat { code128, code39, ean13, qrCode }

enum FieldDataType { text, integer, decimal, date }

class ImportTemplate {
  const ImportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.fields,
    required this.barcodeFieldKey,
    required this.barcodeFormat,
  });

  final String id;
  final String name;
  final String description;
  final List<TemplateField> fields;
  final String barcodeFieldKey;
  final BarcodeFormat barcodeFormat;
}

class TemplateField {
  const TemplateField({
    required this.key,
    required this.displayName,
    required this.dataType,
    required this.required,
    this.example,
  });

  final String key;
  final String displayName;
  final FieldDataType dataType;
  final bool required;
  final String? example;
}
