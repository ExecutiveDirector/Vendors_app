# AquaGas Vendor App

Flutter app for AquaGas vendors (LPG gas sellers in Kenya): receive and fulfil
orders, manage products, inventory and outlets, track riders and deliveries,
and view sales and reviews.

## Features

- **Orders** – new-order alert sheet with sound and haptics, accept / decline
  with a reason, status progression, live delivery tracking, one-tap call to
  the customer. The last list is cached so it still opens offline.
- **Products & inventory** – catalogue, stock levels, price edits, history.
- **Wholesaler sync** – review queue for catalogue updates coming from
  WhatsApp wholesaler groups.
- **Outlets, riders, promotions, reviews, support, subscriptions, analytics.**
- Push notifications (Firebase Cloud Messaging), light and dark themes.

## Getting started

```bash
flutter pub get
flutter run
```

Requires Flutter 3.32 or newer. Firebase is configured through
`lib/firebase_options.dart` (Android values only; run `flutterfire configure`
to add iOS or web).

## Project layout

```
lib/
  main.dart                 app entry, theme and text-scale setup
  src/core/
    theme.dart              AppTheme, AppColors, AppSpacing (design tokens)
    widgets/shared_widgets.dart   ButtonPair, StatusBadge, skeleton loaders,
                                  empty/error states, friendlyError()
    api/ services/          Dio client, storage, push and alert services
  src/features/<feature>/   data/ (API + models) and presentation/ (screens)
test/                       unit and widget tests
```

## Design conventions

- Use `AppColors` / `AppTheme.statusColor` instead of hard-coded `Colors.*`.
- Two actions side by side use `ButtonPair`; never stack a pair vertically.
- Show loading with `SkeletonList`, failures with `AppError` (it converts raw
  exceptions into plain language through `friendlyError`).
- Keep tap targets at least 48 x 48 and let text scale with the system font
  size (the app caps it between 0.9x and 1.4x).

## Checks and releases

- Pull requests run `flutter analyze` and `flutter test` (`.github/workflows/ci.yml`).
- Pushes to `main` build a release APK and send it to Firebase App
  Distribution (`.github/workflows/firebase-distribute.yml`). Merge only after
  CI is green.
