/// A product record stored locally and available for label preparation.
class CatalogueRecord {
  const CatalogueRecord({
    required this.id,
    required this.templateId,
    required this.reference,
    required this.barcodeValue,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String templateId;
  final String reference;
  final String barcodeValue;
  final Map<String, String> values;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => values['item_name']?.trim().isNotEmpty == true
      ? values['item_name']!
      : reference;

  /// The cleaned category name used consistently in record lists and filters.
  String? get category => _cleanValue(values['category']);

  /// A case-insensitive category identifier for grouping and filtering.
  String? get categoryKey => category?.toLowerCase();

  static String? _cleanValue(String? value) {
    if (value == null) {
      return null;
    }
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? null : cleaned;
  }

  CatalogueRecord copyWith({
    String? reference,
    String? barcodeValue,
    Map<String, String>? values,
  }) {
    return CatalogueRecord(
      id: id,
      templateId: templateId,
      reference: reference ?? this.reference,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      values: values ?? this.values,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
