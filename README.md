# Tree Cost Calculator

An iPhone and iPad app for tree service professionals: measure a tree's circumference and height, get a price,
add customer details and photos, and send a professional PDF estimate. Everything is stored on the
device; there are no accounts, servers or analytics.

© 2026 Ryan Hamilton. All rights reserved.

## Repository layout

| Path | What it is |
| --- | --- |
| `Tree Cost Calculator/` | The iOS app (SwiftUI, iOS 17+, iPhone and iPad). |
| `Tree Cost CalculatorUITests/` | UI tests for the main flows. |
| `website/` | The public website: `index`, `support`, `privacy`, `terms` and `404` pages. Plain HTML, no build step. |
| `AppStore/` | Everything for the App Store listing: metadata text, screenshots, links and a submission checklist (start with `AppStore/README.md`). |
| `Config/` | The iCloud entitlements file and the Info.plist additions (Files visibility, iCloud container). |

### The app

- `Model/`: `Estimate` (the single data model and all price math), `EstimateStore` (one JSON file per estimate),
  `DataFolder` (the visible "TCC" folder in Files), `PhotoStore` (photos and logo as files),
  `SettingsFile` (settings copied to `Settings.json`), `BackupMirror` (automatic iCloud Drive copy and restore after a
  reinstall), `LegacyMigration` (imports data from version 1), `AppSettings`, `Format`.
- `Views/`: estimate list, estimate editor, settings, onboarding, PDF preview, shared components.
- `PDF/EstimatePDF.swift`: paginated PDF layout (US Letter or A4 depending on region).

Price math (`Estimate.totals`): `volume = circumference² × height ÷ 12.56`; total = starting fee + volume × rate,
then additional charge, then discount, then tax on the discounted amount. Each step is rounded to cents so
the lines on screen and on the PDF always add up to the total.

### Building and testing

Open `Tree Cost Calculator.xcodeproj` in Xcode, or from the command line:

```bash
xcodebuild test -project "Tree Cost Calculator.xcodeproj" -scheme "Tree Cost Calculator" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Debug builds understand a few launch arguments (see `Model/DebugLaunch.swift`), for example
`-demoData -openEstimate 1 -showPreview` to open a seeded estimate's PDF preview. They are compiled out of
Release builds.

## Website

`website/` is meant to be copied, as is, to the **root** of the `rshamilton/treecostcalculator` repository and
served with GitHub Pages. The app links to `https://rshamilton.github.io/treecostcalculator/support` and
`https://rshamilton.github.io/treecostcalculator/privacy`, which GitHub Pages serves from `support.html` and `privacy.html`.
The pages are self-contained (inline CSS and SVG, system fonts, no scripts or external requests).
