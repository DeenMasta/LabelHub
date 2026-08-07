# LabelHub UI/UX Design Prompt

Design a polished, Android-first mobile and tablet application named **LabelHub**. It is an offline business tool for importing product data, generating barcode labels, previewing them at physical size, and printing sticker labels. The primary users are shop owners, warehouse staff, and inventory teams who need a fast, dependable workflow without internet access.

Create a clean, calm Material 3 interface with a professional inventory-tool feel: warm off-white background, deep forest green as the primary colour, dark charcoal text, soft green success states, amber warnings, and red validation errors. Use rounded cards, clear typography, roomy touch targets, simple line icons, and restrained shadows. Prioritize scanability, data accuracy, and confident actions over decoration. Support phone and Android tablet layouts: bottom navigation on phones; navigation rail or persistent sidebar and multi-column content on tablets.

Design these connected screens and show realistic sample data:

1. **Dashboard** — summary cards for total records, templates, recent imports, print jobs, and records needing review. Prominent quick actions: Import data, View templates, View records, Print labels. Include a small recent activity list.
2. **Template list and details** — built-in templates: Product Label, Inventory Label, Asset Label, Batch & Expiry Label, Shipping/Carton Label. Product Label detail shows columns in a clear table: item code, item name, barcode, price, quantity, batch number, expiry date; visibly distinguish required and optional fields. Actions: export blank CSV, preview sample data.
3. **Import flow** — a stepper: Select template → Choose CSV file → Map columns → Validate → Import summary. Show a drop zone/file-selection card, a CSV header mapping interface, and a validation screen with row-level errors such as missing item code, invalid price, duplicate barcode, and incorrect date format. Make “Import valid rows only” and “Export invalid rows” clear but secondary to reviewing issues.
4. **Records** — searchable, filterable list with barcode, product name, template, import batch, and updated date. Include multi-select controls, filter chips, empty state, record detail/edit form, archive action, and reprint action.
5. **Label layouts** — fixed layout cards with physical dimensions in millimetres, such as 50 × 30 mm, 60 × 40 mm, and 100 × 50 mm. Each preview should show barcode, product name, SKU, price, batch, and expiry fields. Clearly show barcode format selection: Code 128, Code 39, EAN-13, QR code.
6. **Print preview** — selected-record count, copies input, total-label count, printer selection, physical label dimensions, page/roll arrangement, and barcode previews. Include missing-field warnings. Use a strong primary “Print labels” button and a clear PDF/system-print indication.
7. **History and backup** — import history, print-job history with status badges, and a Backup & Restore screen that explains the offline local-database backup file.

The design must make this workflow obvious at a glance: select a template, export or fill CSV data, import and validate it, save valid records locally, select records, choose a label layout, preview, then print. Avoid dashboards that resemble social apps, consumer e-commerce, cloud collaboration, or complex drag-and-drop label design. Use concise English labels and accessible contrast.

Deliver high-fidelity linked screens, a small design-system page (colour, typography, buttons, inputs, status chips, data tables), and phone/tablet responsive variants for the Dashboard, Import Validation, Records, and Print Preview screens.
