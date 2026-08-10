import '../domain/entities/import_template.dart';

const productTemplate = ImportTemplate(
  id: 'system-product-v1',
  name: 'Product label',
  description: 'Products with a barcode, item code, name and optional pricing.',
  barcodeFieldKey: 'barcode',
  barcodeFormat: BarcodeFormat.code128,
  fields: <TemplateField>[
    TemplateField(
      key: 'item_code',
      displayName: 'Item code',
      dataType: FieldDataType.text,
      required: false,
      example: 'ITEM-1001',
    ),
    TemplateField(
      key: 'item_name',
      displayName: 'Item name',
      dataType: FieldDataType.text,
      required: true,
      example: 'Blue T-Shirt',
    ),
    TemplateField(
      key: 'barcode',
      displayName: 'Barcode',
      dataType: FieldDataType.text,
      required: true,
      example: '9551234567890',
    ),
    TemplateField(
      key: 'price',
      displayName: 'Price',
      dataType: FieldDataType.decimal,
      required: false,
      example: '29.90',
    ),
    TemplateField(
      key: 'quantity',
      displayName: 'Quantity',
      dataType: FieldDataType.integer,
      required: false,
      example: '10',
    ),
    TemplateField(
      key: 'batch_no',
      displayName: 'Batch number',
      dataType: FieldDataType.text,
      required: false,
      example: 'BATCH-01',
    ),
    TemplateField(
      key: 'expiry_date',
      displayName: 'Expiry date',
      dataType: FieldDataType.date,
      required: false,
      example: '2027-12-31',
    ),
  ],
);
