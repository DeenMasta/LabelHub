# LabelHub UI Design Rules

Apply these rules to every Flutter UI change together with `AGENTS.md`.

## Design language

LabelHub uses a clean, compact operational-tool style: white surfaces, navy ink (`#121C2A`), restrained mint accents, pale-blue data marks (`#BFDBFE`), and dark charcoal panels (`#292D2D`). Use the existing 4 px spacing rhythm. Prefer 8, 12, 16, 20, and 24 px spacing; use 9–12 px radii for controls, 16–20 px for cards, and 22–24 px for major panels. New colours, radii, or spacing values used in more than one place must be promoted to a named app theme token; do not repeat raw values across features.

Keep one visual hierarchy per screen: product app bar, screen heading, optional compact tabs/filters, summary data, then detailed content. Preserve generous whitespace, aligned card edges, and a single obvious primary action. Use text labels for data and icons only when their action is clear.

## Shared shell and component ownership

All primary pages render inside the router shell. Do not add a second `Scaffold`, app bar, or bottom navigation to a feature page. Reuse `AppHeader` and `PrimaryNavigationBar` for shared chrome.

Place a component in `lib/core/presentation/widgets/` only when two or more features use it or it is app shell/chrome. Keep feature-only components in `lib/features/<feature>/presentation/widgets/`. Pages compose components and own layout; reusable widgets receive display data and callbacks only. Repositories, database access, routing decisions, and business validation do not belong in a widget `build` method.

## Naming standard

Use a specific noun based on the UI responsibility:

- Pages: `DashboardPage`, `ImportValidationPage`
- Reusable cards: `PrintSummaryCard`, `LabelLayoutPreviewCard`
- Controls: `PeriodFilter`, `BarcodeFormatSelector`
- Charts/lists: `WeeklyPrintBarChart`, `ImportErrorList`
- Shared chrome: `AppHeader`, `PrimaryNavigationBar`
- Data passed to UI: `PrintMetric`, `LabelLayoutPreview`

Use `lower_snake_case.dart` filenames matching the primary public type, PascalCase types, and lowerCamelCase properties. Do not use vague names such as `CommonWidget`, `CustomCard`, `Helper`, `Utils`, `Item`, `Data`, or numbered widget names. Avoid a `Widget` suffix unless it clarifies an otherwise ambiguous name. Keep private implementation details prefixed with `_` in the same file; promote them only when reuse is proven.

## Interaction and quality gates

Use Material controls with 44 px minimum touch targets, tooltips/semantic labels for icon-only actions, readable contrast, and visible selected, disabled, loading, empty, and error states. Make cards tappable only when the complete card has one clear action.

Before handoff, run `dart format`, `flutter analyze`, and the relevant `flutter test`. For changed mobile layouts, review a 390 × 844 capture and check that the primary content, app bar, and bottom navigation do not overlap.
