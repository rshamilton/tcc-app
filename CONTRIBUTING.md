# Contributing to Tree Cost Calculator

Thanks for helping. Bug reports, feature ideas and pull requests are all welcome.

## Reporting a bug or asking for a feature

Open an [issue](https://github.com/rshamilton/tcc-app/issues). For bugs, say what you did, what you expected, what
happened, your device and iOS version, and the app version (Settings ▸ About). Please don't post customers' personal
details or real estimates; use made-up data.

## Pull requests

1. Keep changes focused: one fix or feature per pull request.
2. Match the existing style: SwiftUI, no third-party dependencies, plain-English interface text, comments that explain
   *why*. Use `Format` for every number shown to the user and `NumberField` for numeric input.
3. The app must keep working offline, with no accounts, analytics, ads or network requests.
4. Support Dynamic Type, VoiceOver, dark mode, iPhone and iPad.
5. Price math lives in `Estimate.totals`. If you change it, existing saved estimates must keep their totals.
6. Saved data must stay readable: add new fields to `Estimate` with lenient decoding and a default.
7. Run the UI tests before submitting:

   ```bash
   xcodebuild test -project "Tree Cost Calculator.xcodeproj" -scheme "Tree Cost Calculator" \
     -destination 'platform=iOS Simulator,name=iPhone 13'
   ```

## License of contributions

By submitting a contribution you agree that it is licensed under the GNU GPL version 3 or later **together with the
additional App Store permission** in [APP_STORE_EXCEPTION.md](APP_STORE_EXCEPTION.md), and that you have the right to
license it that way. This keeps the official app distributable on the App Store.
