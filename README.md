# Tree Cost Calculator

**Tree Cost Calculator is a free iPhone and iPad app for tree service professionals that turns a tree's circumference
and height into a priced tree removal estimate, then sends it to the customer as a PDF estimate or invoice.**
No ads, no subscription, no account, works offline, and the code is open source under the GNU GPL v3.

[Download on the App Store](https://apps.apple.com/app/id6760602763) ·
[Website](https://rshamilton.github.io/treecostcalculator/) ·
[Report a bug or suggest a feature](https://github.com/rshamilton/tcc-app/issues)

![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg) ![Platform: iOS 17+](https://img.shields.io/badge/iOS-17%2B-lightgrey.svg) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange.svg)


## What it does

**Estimate tree removal on the spot**
- Enter a trunk's circumference and height; the app shows the volume and the price immediately (feet or meters).
- Any number of trees per job, each with a name, measurements and photos.
- Your own starting fee, price per cubic foot (or cubic meter) and tax rate, plus a discount or additional charge.
- **Other work as line items**: stump grinding priced per inch of diameter with a minimum charge, trimming and pruning,
  haul away, crew labor by the hour, crane or bucket truck time, emergency storm work. Keep a saved price list.
- **Tax regions**: a tax rate and license number for each state or area you work in.

**Send it, get it signed, get paid**
- Professional **PDF estimate** with your logo, contact details, license number, terms, photos and a signature block.
- **Customer signature** captured on the phone and printed on the PDF.
- **Deposit** on acceptance.
- **Invoices**: turn an approved estimate into an invoice in one tap, with a due date, amount paid, balance due and payment
  instructions. Statuses Draft, Sent, Approved, Declined, Invoiced and Paid, with Open, Won and Unpaid totals.
- Import the customer from Contacts; call, email or get directions with a tap.
- Search, duplicate, and **export everything to CSV**.

**Tree Tools (field calculators)**
- **Tree height** using the phone's tilt sensor (clinometer, tangent method).
- **Trunk diameter (DBH)** from circumference.
- **Stump grinding price**, **firewood cords** and face cords, **log board feet** (Doyle and International ¼-inch rules),
  and approximate **green log weight** by species.

**Your data stays yours**
- No account, no ads, no analytics, no tracking, no network requests.
- Everything is stored as ordinary files in a "TCC" folder visible in the Files app, with an automatic copy in the
  user's own iCloud Drive so it survives deleting and reinstalling the app.

## How the price is worked out

```
volume      = circumference² × height ÷ 12.56        (12.56 ≈ 4π, i.e. the volume of a cylinder)
tree price  = volume × your price per cubic foot (or m³)
base        = starting fee + tree price + other work (line items)
subtotal    = base + additional charge
total       = subtotal − discount + tax on the discounted amount
```

Example: circumference 6 ft and height 50 ft gives 143.3 cu ft. At $10 per cubic foot with a $150 starting fee, the
estimate is $1,583.12 before tax. Every step is rounded to whole cents so the lines on screen and on the PDF always add
up to the total (`Estimate.totals` in [`Model/Estimate.swift`](Tree%20Cost%20Calculator/Model/Estimate.swift)).

## FAQ

**Is it really free?** Yes. No ads, no subscription, no in-app purchases and no account.

**Does it need the internet?** No. Everything works offline. iCloud Drive backup syncs when a connection is available.

**Where is my data?** On your device, in the Files app under "TCC", plus a copy in your own iCloud Drive. The developer
never receives it.

**Can I make invoices?** Yes. Open an estimate, then choose Create Invoice from the status menu.

**How do I price stump grinding?** Add a Stump grinding line item under Other Work: quantity = the stump's widest
diameter in inches, price per inch, and an optional minimum charge.

**How does it measure tree height?** Stand a known distance from the tree, sight along the phone at the top and then at
the base; height = distance × (tan top angle + tan base angle).

**Does it work in meters?** Yes, choose Meters in Settings. Prices are then per cubic meter.

## Building

Requirements: Xcode 26 or later, iOS 17 SDK or later. No third-party dependencies.

```bash
git clone https://github.com/rshamilton/tcc-app.git
cd tcc-app
open "Tree Cost Calculator.xcodeproj"
```

To build or test from the command line:

```bash
xcodebuild test -project "Tree Cost Calculator.xcodeproj" -scheme "Tree Cost Calculator" \
  -destination 'platform=iOS Simulator,name=iPhone 13'
```

To run on your own device, change the bundle identifier (`me.ryham.tcc`) and the development team in the target's
Signing & Capabilities, and turn off the iCloud capability or point it at your own container.

Debug builds understand a few launch arguments (see `Model/DebugLaunch.swift`), for example
`-demoData -openEstimate 1 -showPreview` to open a seeded estimate's PDF preview. They are compiled out of Release builds.

## Repository layout

| Path | What it is |
| --- | --- |
| `Tree Cost Calculator/` | The iOS app (SwiftUI, iOS 17+, iPhone and iPad). |
| `Tree Cost CalculatorUITests/` | UI tests for the main flows. |
| `website/` | The public website (plain HTML, no build step), published from `rshamilton/treecostcalculator` with GitHub Pages. |
| `Config/` | The iCloud entitlements file and the Info.plist additions. |

Inside the app:

- `Model/`: `Estimate` (the data model and all price math), `EstimateStore` (one JSON file per estimate, CSV export),
  `TreeMath` (height, diameter, board feet, cords, wood weight), `DataFolder` (the visible "TCC" folder), `PhotoStore`
  (photos, signatures and logo as files), `SettingsFile` (settings copied to `Settings.json`), `BackupMirror` (iCloud
  Drive copy and restore), `ReviewPrompter` (when to show Apple's rating prompt), `LegacyMigration`, `AppSettings`,
  `AppLinks`, `Format`.
- `Views/`: estimate list, estimate editor, line items, signature capture, contact picker, Tree Tools, settings,
  onboarding, PDF preview, shared components.
- `PDF/EstimatePDF.swift`: paginated PDF estimate and invoice (US Letter or A4 depending on region).

## Contributing

Bug reports and feature requests are welcome in [Issues](https://github.com/rshamilton/tcc-app/issues). Pull requests
are welcome too; please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

Copyright © 2026 Ryan Hamilton.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See [LICENSE](LICENSE) for the full text.

**Additional permission under GNU GPL version 3 section 7 (App Store distribution).** If you modify this program, or any
covered work, by linking or combining it with Apple's iOS SDK and frameworks, or distribute it through Apple's App
Store or TestFlight, the licensors of this program grant you additional permission to convey the resulting work
through those channels, subject to Apple's terms of service and usage rules, provided that you otherwise comply with
the GNU GPL version 3 for the source code (Corresponding Source must remain available to recipients under the GPL).
See [APP_STORE_EXCEPTION.md](APP_STORE_EXCEPTION.md).

The names "Tree Cost Calculator" and "TCC" and the app icon identify the official app. If you publish your own build,
please give it a different name and icon so users can tell them apart.

Prices, volumes, heights, weights, tax rates and every other figure the app produces are estimates and examples only.
See the [Terms of Use](https://rshamilton.github.io/treecostcalculator/terms).
