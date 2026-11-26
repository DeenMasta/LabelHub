import '../domain/entities/import_template.dart';

const productTemplate = ImportTemplate(
  id: 'system-product-v1',
  name: 'Product label',
  description: 'Products with an Item, SKU, and optional barcode and pricing.',
  barcodeFieldKey: 'barcode',
  barcodeFormat: BarcodeFormat.code128,
  fields: <TemplateField>[
    TemplateField(
      key: 'item_name',
      displayName: 'Item',
      dataType: FieldDataType.text,
      required: false,
      example: 'Plain Thosai',
    ),
    TemplateField(
      key: 'item_code',
      displayName: 'SKU',
      dataType: FieldDataType.text,
      required: false,
      example: '102',
    ),
    TemplateField(
      key: 'barcode',
      displayName: 'Barcode',
      dataType: FieldDataType.text,
      required: true,
      example: '9551234567890',
    ),
    TemplateField(
      key: 'category',
      displayName: 'Category',
      dataType: FieldDataType.text,
      required: false,
      example: 'THOSAI',
    ),
    TemplateField(
      key: 'price',
      displayName: 'Selling Price',
      dataType: FieldDataType.text,
      required: false,
      example: 'RM 2.50',
    ),
    TemplateField(
      key: 'expiry_date',
      displayName: 'Expiry date',
      dataType: FieldDataType.date,
      required: false,
      example: '2027-12-31',
    ),
    TemplateField(
      key: 'receive_date',
      displayName: 'Receive date',
      dataType: FieldDataType.date,
      required: false,
      example: '2026-11-19',
    ),
  ],
);
