# PetLoop on iPhone

The app is one Flutter code base for Android and iPhone. Windows cannot
build for iPhone, so a Mac in the cloud does it: `.github/workflows/ios.yml`
builds on every push to `main` (or with "Run workflow" on GitHub's Actions
tab) and keeps an **unsigned** build as the artifact `PetLoop-ios-unsigned`
for 14 days. That proves the iPhone app compiles. It cannot go on a phone
until it is signed.

## Ready today

- Bundle id `com.limi.petCompanion`, display name PetLoop, iOS 13 or later,
  app icon from the PetLoop pack, English and Hebrew (`CFBundleLocalizations`).
- Permission texts in `ios/Runner/Info.plist`: photo library, camera, saving
  to photos (the share sheet's "Save Image" needs it), and the export
  compliance answer (no special encryption) so TestFlight does not ask.
- Reminders: local notifications with the "In 15 min" action
  (`ios/Runner/AppDelegate.swift`), at most 60 waiting on iOS (Apple's limit
  is 64). iOS has no "Alarms & reminders" permission: reminders arrive on
  time once notifications are allowed.
- Calls, SMS, WhatsApp and web links open with `launchUrl`, which needs no
  extra settings.

## When there is an iPhone and an Apple licence

1. **Apple Developer Program** (USD 99 a year, enrolled by the owner).
   Create the app id `com.limi.petCompanion` and an App Store Connect app.
2. **Signing in the cloud build.** Add the signing certificate and the
   provisioning profile (or an App Store Connect API key) as GitHub secrets,
   and switch the workflow from `--no-codesign` to `flutter build ipa` with
   an export options file. Then upload to **TestFlight** from the workflow.
3. **Backend.** Add the repository secrets `SUPABASE_URL` and
   `SUPABASE_PUBLISHABLE_KEY` (the values of the local `env.json`); without
   them the build runs on the demo data.
4. **Hebrew permission texts.** The texts in `Info.plist` are English. Add
   `he.lproj/InfoPlist.strings` through Xcode (it must be registered in the
   project file, so do it on a Mac rather than by hand).
5. **Test on the phone**, the same list as on Android: sign-up and email
   confirmation, add a pet with a photo (camera and library), feeding and
   walks, the walk clock, reminders (allow, a reminder on time, "In 15 min",
   tapping opens the right page), emergency call / SMS / WhatsApp, PDF and
   lost-pet card sharing, the budget and basket, the first 30 days, Hebrew
   and English, and the back gesture (swipe from the edge).

Without a licence there is a free way to try a build on your own iPhone:
Sideloadly (Windows) re-signs the unsigned `.ipa` with a normal Apple ID.
Such an install expires after 7 days.
