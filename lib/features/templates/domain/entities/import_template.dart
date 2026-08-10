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

  ImportTemplate withRequiredFieldKeys(Set<String> requiredFieldKeys) {
    return ImportTemplate(
      id: id,
      name: name,
      description: description,
      barcodeFieldKey: barcodeFieldKey,
      barcodeFormat: barcodeFormat,
      fields: fields
          .map(
            (TemplateField field) =>
                field.copyWith(required: requiredFieldKeys.contains(field.key)),
          )
          .toList(),
    );
  }
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

  TemplateField copyWith({bool? required}) {
    return TemplateField(
      key: key,
      displayName: displayName,
      dataType: dataType,
      required: required ?? this.required,
      example: example,
    );
  }
}
