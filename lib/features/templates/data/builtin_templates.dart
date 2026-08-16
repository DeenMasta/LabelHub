import '../domain/entities/import_template.dart';

const productTemplate = ImportTemplate(
  id: 'system-product-v1',
  name: 'Product label',
  description: 'Products with an Item, SKU, Barcode, and optional pricing.',
  barcodeFieldKey: 'barcode',
  barcodeFormat: BarcodeFormat.code128,
  fields: <TemplateField>[
    TemplateField(
      key: 'item_name',
      displayName: 'Item',
      dataType: FieldDataType.text,
      required: true,
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
  ],
);
