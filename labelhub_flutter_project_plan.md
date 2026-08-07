# LabelHub — Flutter Project Plan

## 1. Product Overview

**LabelHub** is an offline Flutter application for importing structured data, storing it locally, generating barcode labels, and printing those labels as stickers.

The application provides predefined import templates. Users must enter their data according to the selected template before importing it into LabelHub.

### Core workflow

```text
Select template
      ↓
Download or view required columns
      ↓
Fill in data using CSV or Excel
      ↓
Import file into LabelHub
      ↓
Validate imported records
      ↓
Save valid records locally
      ↓
Select records and label design
      ↓
Preview labels
      ↓
Print barcode stickers
```

## 2. Initial Assumptions

The first release can use these assumptions:

- The app works fully offline.
- Data is imported through CSV or Excel files.
- All imported records are stored locally.
- Users can print one or multiple labels.
- Labels may contain:
  - Barcode
  - Product name
  - SKU or item code
  - Price
  - Batch number
  - Expiry date
  - Optional custom fields
- The app supports common barcode formats such as:
  - Code 128
  - Code 39
  - EAN-13
  - QR code
- The first release targets Android tablets and phones.
- Printer integration is separated from the application logic so Bluetooth, USB, network, or system printers can be added independently.

## 3. Main Application Modules

### A. Dashboard

The dashboard should show:

- Total imported records
- Number of templates
- Recent imports
- Recent print jobs
- Invalid records requiring correction
- Quick actions:
  - Import data
  - Create template
  - Print labels
  - View records

### B. Template Management

Templates define the structure that imported files must follow.

Each template should contain:

- Template name
- Description
- Required columns
- Optional columns
- Data types
- Validation rules
- Barcode source field
- Label display fields
- Default barcode type
- Default label layout

Example product template:

| Column | Type | Required | Example |
|---|---|---:|---|
| `item_code` | Text | Yes | ITEM-1001 |
| `item_name` | Text | Yes | Blue T-Shirt |
| `barcode` | Text | Yes | 9551234567890 |
| `price` | Decimal | No | 29.90 |
| `quantity` | Integer | No | 10 |
| `batch_no` | Text | No | BATCH-01 |
| `expiry_date` | Date | No | 2027-12-31 |

Template actions:

- Create template
- Edit template
- Duplicate template
- Delete template
- Export blank CSV template
- Export blank Excel template
- Preview sample data
- Configure validation rules

For the minimum viable product, LabelHub should include several built-in templates rather than starting with a fully dynamic template builder.

Suggested built-in templates:

1. Product label
2. Inventory label
3. Asset label
4. Batch and expiry label
5. Shipping or carton label

## 4. Import and Validation Module

### Supported file formats

Start with:

- `.csv`
- `.xlsx`

CSV should be implemented first because it is simpler and more reliable. Excel support can follow immediately afterward.

### Import process

1. User selects a template.
2. User selects an import file.
3. The application reads the header row.
4. Columns are mapped to template fields.
5. Every record is validated.
6. A validation summary is shown.
7. User confirms the import.
8. Valid records are stored locally.
9. Invalid records remain available for correction or export.

### Validation rules

The validation engine should support:

- Required field
- Text length
- Integer
- Decimal
- Date
- Allowed values
- Unique value
- Duplicate barcode detection
- Barcode-format validation
- Minimum and maximum values
- Regular-expression validation

Example validation errors:

```text
Row 8: item_code is required.
Row 12: price must be a number.
Row 19: barcode already exists.
Row 24: expiry_date must use YYYY-MM-DD.
```

### Import result

The import summary should show:

- Total rows
- Valid rows
- Invalid rows
- Duplicate rows
- Skipped rows
- Updated rows
- Newly inserted rows

The user should be able to:

- Import valid rows only
- Cancel the entire import
- Export invalid rows
- Correct values before saving

## 5. Local Data Storage

A relational local database is appropriate because LabelHub contains structured records and relationships.

Recommended database options:

- **Drift with SQLite** for strong typing, migrations, queries, and testability
- SQLite directly for a simpler implementation
- Isar only if document-style storage is preferred

Drift is the strongest default choice for this project.

### Proposed database tables

#### `templates`

```text
id
name
description
barcode_type
barcode_field_key
created_at
updated_at
is_system_template
```

#### `template_fields`

```text
id
template_id
field_key
display_name
data_type
is_required
default_value
validation_config
sort_order
```

#### `import_batches`

```text
id
template_id
file_name
total_rows
valid_rows
invalid_rows
imported_at
status
```

#### `records`

```text
id
template_id
import_batch_id
record_reference
barcode_value
created_at
updated_at
is_archived
```

#### `record_values`

```text
id
record_id
template_field_id
text_value
number_value
date_value
```

#### `label_layouts`

```text
id
name
template_id
width_mm
height_mm
orientation
layout_config
created_at
updated_at
```

#### `print_jobs`

```text
id
printer_name
label_layout_id
record_count
copies
status
created_at
completed_at
error_message
```

For a simpler first release, imported row data can be stored as JSON inside the `records` table. However, normalized `record_values` are better when advanced searching and filtering are required.

## 6. Record Management

Users should be able to:

- View imported records
- Search by name, SKU, or barcode
- Filter by template
- Filter by import batch
- Sort by date or field
- Edit a record
- Archive a record
- Delete a record
- Select multiple records
- Detect duplicates
- Reprint labels
- View import history

Recommended record list columns:

```text
Selection | Barcode | Main Name | Template | Import Batch | Updated Date
```

## 7. Label Designer

The label designer controls how imported data appears on the sticker.

### Label elements

Support these elements:

- Static text
- Dynamic field value
- Barcode
- QR code
- Price
- Date
- Line
- Rectangle
- Image or logo
- Sequence number

### Element properties

Each label element can have:

- X and Y position
- Width and height
- Font size
- Font weight
- Alignment
- Rotation
- Field binding
- Visibility
- Prefix and suffix
- Barcode type
- Barcode height
- Text wrapping

### Label settings

- Width in millimetres
- Height in millimetres
- Portrait or landscape
- Margins
- Number of columns
- Gap between labels
- Printer resolution, such as 203 DPI or 300 DPI

For the MVP, use fixed layouts with configurable fields. A drag-and-drop designer should be introduced only after printing and unit conversion are stable.

## 8. Barcode Generation

A barcode service should accept:

```dart
class BarcodeRequest {
  final String value;
  final BarcodeFormat format;
  final double widthMm;
  final double heightMm;
  final bool showText;
}
```

The service should:

- Validate the source value
- Generate the barcode
- Produce a preview
- Convert physical dimensions to pixels or printer dots
- Return a printable image or printer command

Important barcode rules:

- EAN-13 must contain valid numeric data.
- Code 128 is suitable for general alphanumeric identifiers.
- QR codes are suitable for longer values.
- The app should not silently replace invalid barcode data.
- Invalid data should be shown before printing.

## 9. Printing Architecture

Printing is likely the most hardware-sensitive area, so it should use an adapter-based design.

```dart
abstract class LabelPrinter {
  Future<List<PrinterDevice>> discover();
  Future<void> connect(PrinterDevice device);
  Future<PrintResult> printLabels(PrintRequest request);
  Future<void> disconnect();
}
```

Possible implementations:

```text
SystemPdfPrinter
BluetoothThermalPrinter
UsbThermalPrinter
NetworkPrinter
ZplPrinter
TsplPrinter
EscPosPrinter
```

### Recommended rollout

#### Phase 1

Generate a PDF using the correct physical label dimensions and print through the operating system.

Advantages:

- Easier to implement
- Works with many standard printers
- Suitable for A4 label sheets and desktop label printers

#### Phase 2

Add direct thermal-printer support.

Possible command languages:

- ZPL
- TSPL
- ESC/POS, where appropriate

Direct printer support requires testing with the exact printer models used by customers.

### Print preview

Before printing, show:

- Label dimensions
- Selected records
- Number of copies
- Total labels
- Page or roll arrangement
- Barcode rendering
- Missing-field warnings

## 10. Offline File Handling

The app should support:

- Importing from device storage
- Exporting templates
- Exporting validation errors
- Exporting local backups
- Restoring backups
- Exporting selected records
- Saving generated PDFs locally

Because there is no server, backup and restore are important. A user who loses the device could otherwise lose all templates and imported records.

Suggested backup package:

```text
labelhub_backup_2026-08-04.zip
├── database.sqlite
├── metadata.json
├── label-layouts/
└── images/
```

## 11. Proposed Flutter Architecture

Use a feature-first clean architecture.

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
├── core/
│   ├── database/
│   ├── errors/
│   ├── files/
│   ├── printing/
│   ├── validation/
│   └── utilities/
├── features/
│   ├── dashboard/
│   ├── templates/
│   ├── imports/
│   ├── records/
│   ├── labels/
│   ├── printing/
│   ├── backup/
│   └── settings/
└── main.dart
```

Inside each feature:

```text
imports/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── controllers/
    ├── pages/
    └── widgets/
```

### Suggested Flutter packages

Package choices should be confirmed before implementation, but the project will likely need:

- Riverpod for state management
- Drift and SQLite for storage
- GoRouter for navigation
- File Picker for file selection
- CSV parser
- Excel parser
- Barcode-generation library
- PDF-generation library
- Printing integration
- Freezed and JSON serialization
- Permission handling
- Path provider
- UUID generation
- Logging

## 12. Key Domain Models

```dart
class ImportTemplate {
  final String id;
  final String name;
  final String description;
  final List<TemplateField> fields;
  final String barcodeFieldKey;
  final BarcodeFormat barcodeFormat;
}

class TemplateField {
  final String key;
  final String displayName;
  final FieldDataType dataType;
  final bool required;
  final List<FieldValidationRule> rules;
}

class ImportedRecord {
  final String id;
  final String templateId;
  final String importBatchId;
  final Map<String, Object?> values;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LabelLayout {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final List<LabelElement> elements;
}
```

## 13. Recommended Screens

```text
Splash
Dashboard
Template List
Template Details
Template Editor
Import File Selection
Column Mapping
Import Validation
Import Summary
Record List
Record Details
Label Layout List
Label Layout Editor
Print Selection
Print Preview
Printer Selection
Print History
Backup and Restore
Settings
```

## 14. MVP Scope

The first usable version should include:

1. Offline Android application
2. Built-in product template
3. CSV template export
4. CSV import
5. Required-field validation
6. Duplicate barcode validation
7. Local SQLite storage
8. Record search and editing
9. Code 128, EAN-13, and QR generation
10. Two or three fixed label layouts
11. Label preview
12. PDF label generation
13. System print dialog
14. Import history
15. Database backup and restore

Avoid placing these in the MVP:

- User accounts
- Cloud synchronization
- Team collaboration
- Fully dynamic drag-and-drop label design
- Many direct printer protocols
- Complex permissions
- Cross-device synchronization

## 15. Development Phases

### Phase 1 — Foundation

- Set up Flutter project
- Configure architecture
- Add navigation
- Add local database
- Define domain entities
- Add error and logging strategy

### Phase 2 — Templates and Imports

- Build template screens
- Create built-in templates
- Export blank CSV
- Import CSV
- Map columns
- Validate records
- Save import batches

### Phase 3 — Record Management

- Record listing
- Search and filters
- Record details
- Editing
- Deletion and archiving
- Duplicate detection

### Phase 4 — Labels

- Barcode generation
- Fixed label layouts
- Dynamic field binding
- Millimetre-based dimensions
- Label preview

### Phase 5 — Printing

- Generate PDF
- Configure paper and label dimensions
- Add copies and batch printing
- Open system print dialog
- Store print history

### Phase 6 — Reliability

- Backup and restore
- Large-file import testing
- Printer calibration
- Database migration testing
- Error handling
- User acceptance testing

### Phase 7 — Hardware Extensions

- Bluetooth printer discovery
- USB printer support
- Network printer support
- ZPL or TSPL command generation
- Printer profiles

## 16. Important Technical Risks

### Printer compatibility

Different printers interpret dimensions, DPI, margins, and command languages differently. Printer support should be planned around known printer models.

### Physical-size accuracy

A preview that looks correct on screen may print at the wrong physical size. All dimensions should use millimetres internally and be converted only at the rendering boundary.

```text
inches = millimetres / 25.4
printerDots = inches × printerDpi
```

### Large imports

The app should parse large files in chunks or isolates so the interface does not freeze.

### Dynamic templates

Changing a template after records have been imported may invalidate existing data. Template versions should therefore be retained.

Example:

```text
Product Template v1
Product Template v2
```

Existing records remain linked to the version used during import.

### Data loss

Because the system is offline, automated local backup reminders and manual export are important.

## 17. Acceptance Criteria for the MVP

The MVP is complete when a user can:

1. Open LabelHub without an internet connection.
2. Select a built-in template.
3. Export a blank CSV template.
4. Fill the CSV with product information.
5. Import the completed CSV.
6. See clear validation errors.
7. Save valid rows locally.
8. Search imported records.
9. Select one or more records.
10. Preview correctly formatted barcode labels.
11. Generate a correctly sized PDF.
12. Print through the device’s print system.
13. Review previous imports and print jobs.
14. Back up and restore the local database.

## 18. Recommended First Release Strategy

Build the first version around **CSV import plus PDF printing**. This validates the complete business workflow without tying the application to one printer manufacturer.

Once the workflow is reliable, add direct printer adapters for the printer models actually used by LabelHub customers. This prevents printer-specific code from dominating the initial application design.
