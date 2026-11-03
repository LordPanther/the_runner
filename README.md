# The Runner

An errand-running marketplace for South Africa. Requesters post an errand, nearby runners bid, and payment sits in escrow until the job is done. Built by [Blackworks Digital](https://github.com/LordPanther) on the same Flutter + Firebase + BLoC foundations as TownPost.

## What it does

- **Post an errand**: pickup and drop-off, queue standing, admin errands, or shopping (with a purchase budget)
- **Runners bid** between the requester's starting fee and cap. Optional instant accept at the starting fee
- **Escrow from day one**: the requester pays into escrow once a bid is accepted; the runner only starts once it's funded
- **Proof of completion**: photos, plus the till slip and total for shopping
- **Auto-release**: payment releases 24 hours after proof unless the requester approves sooner or raises a dispute
- **Fair fees**: 10% commission, split 5% requester / 5% runner. Purchase money is never commissioned
- **Phone-verified accounts**: phone number + OTP, no email

## Tech stack

| Layer | Choice |
|---|---|
| App | Flutter (Android first), BLoC state management |
| Backend | Firebase: Auth (phone), Firestore, Storage, Cloud Functions, Messaging |
| Maps | [MapTiler](https://www.maptiler.com/) via `flutter_map` (no Google billing account) |
| Escrow | [TradeSafe](https://www.tradesafe.co.za/) (wired in Cloud Functions; a fake provider is used until access is set up) |

## Getting started

### Prerequisites
- Flutter SDK (see `pubspec.yaml` for the Dart constraint)
- Node 22 (for Cloud Functions) and the Firebase CLI
- A new Firebase project for The Runner (Blaze plan, since Cloud Functions need it). Pick **africa-south1** for Firestore when asked
- A free MapTiler API key

### Setup

1. **Create the platform folders.** This repo holds the Dart code and backend only; generate Android/iOS once:
   ```bash
   flutter create . --org com.blackworks --project-name the_runner --platforms android,ios
   flutter pub get
   ```

2. **Connect Firebase.** Replaces the placeholder `lib/firebase_options.dart`:
   ```bash
   flutterfire configure
   ```
   In the Firebase console, turn on **Phone** sign-in, Firestore, Storage and Cloud Messaging.

3. **MapTiler key** in `lib/configs/api_keys.dart`.

4. **Deploy the backend:**
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only firestore,storage,functions
   ```

5. **Run it:**
   ```bash
   flutter run
   ```

### Testing the full flow before TradeSafe is connected

Cloud Functions use a **fake escrow provider** by default (`ESCROW_PROVIDER=fake`): "Pay" marks the errand funded instantly, no money moves. Switch to the real thing by adding `ESCROW_PROVIDER=tradesafe` to `functions/.env.<project-id>` once `TradeSafeProvider` in `functions/src/escrow.ts` is wired up.

Only **runners** can bid. Runner onboarding (ID check, bank details) isn't built yet, so for testing, add `"runner"` to a test user's `roles` array in the Firestore console (`users/{uid}`).

### Firestore indexes

All the composite indexes the app and functions need are in `firestore.indexes.json` and deploy with `firebase deploy --only firestore`.

### Tests

```bash
flutter test                  # app: fees, errand model, errors, geohash, phone numbers
cd functions && npm test      # backend: commission and payout maths
```

## How money moves

```
bidding -> accepted -> funded -> in_progress -> proof_submitted -> completed
                                                     \-> disputed -> (admin)
bidding | accepted | funded -> cancelled (refund if funded)
```

The app can only **create an errand** and **place its own bid**. Every other change is a Cloud Function (`functions/src/errands.ts`) that checks who's asking, moves the status inside a transaction, writes to `errands/{id}/events` (the money trail), and calls the escrow provider. `firestore.rules` blocks errand updates from clients entirely.

## Project structure

```
lib/
├── configs/          # Theme, router, size scaling, API keys
├── constants/        # Colors, fonts, images, country codes
├── core/
│   ├── utils/        # Fees, labels, friendly errors, phone numbers
│   └── widgets/      # ErrandCard, RunnerMap, LoadingOverlay
├── data/
│   ├── local/        # SharedPreferences wrapper
│   ├── models/       # Errand, Bid, Proof, PrivateDetails, User, Notification
│   ├── repositories/ # Interface + Firebase implementation per feature
│   └── services/     # Geohash, location, push, block list
├── presentation/
│   ├── common_blocs/ # BLoC per feature (errand, auth, profile, location...)
│   └── screens/      # Errands, home feed, auth, profile, settings
└── utils/            # Localization
functions/src/        # errands, triggers, scheduled, escrow, fees, account, push
```

## Not built yet

- **TradeSafe integration**: `TradeSafeProvider` and `tradesafeWebhook` are stubs with a checklist of what to confirm with TradeSafe
- **Runner onboarding**: ID verification + payout bank details, then the server grants the `runner` role
- **Dispute resolution** for admins (disputes are recorded in `disputes/{errandId}`)
- **Ratings** after a completed errand
- **In-app chat** between requester and runner
- **New-errand alerts** to nearby runners (the settings toggle exists; the function needs runner locations)
- **isiZulu** for the new errand screens (English shows as fallback)

## License

Proprietary. © Blackworks Holdings. All rights reserved.
