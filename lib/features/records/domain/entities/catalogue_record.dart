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
    required this.isArchived,
  });

  final String id;
  final String templateId;
  final String reference;
  final String barcodeValue;
  final Map<String, String> values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  String get name => values['item_name']?.trim().isNotEmpty == true
      ? values['item_name']!
      : reference;

  CatalogueRecord copyWith({
    String? reference,
    String? barcodeValue,
    Map<String, String>? values,
    bool? isArchived,
  }) {
    return CatalogueRecord(
      id: id,
      templateId: templateId,
      reference: reference ?? this.reference,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      values: values ?? this.values,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
