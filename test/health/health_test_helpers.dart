import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/data/file_services.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/reminder_scheduler.dart';
import 'package:pet_companion/features/health/emergency/contact_launcher.dart';
import 'package:pet_companion/features/health/share/health_pdf.dart';
import 'package:pet_companion/features/health/share/health_report.dart';
import 'package:pet_companion/features/health/share/lost_card_renderer.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/theme/app_theme.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/coral_segmented_control.dart';
import 'package:pet_companion/widgets/pet_selector.dart';
import 'package:pet_companion/state/pets_provider.dart';

import '../helpers.dart';

/// The instant every Health test runs at: the sample data's day, late
/// afternoon (a Tuesday).
final fixedNow = DateTime(2025, 6, 10, 17, 40);

/// A zero-latency copy of the sample data at [fixedNow].
FakeHealthRepository fakeHealth({bool seeded = true}) =>
    FakeHealthRepository(latency: Duration.zero, now: () => fixedNow, seeded: seeded);

/// Remembers every plan the app hands to the reminder scheduler.
class RecordingReminderScheduler implements ReminderScheduler {
  final plans = <ReminderPlan>[];

  ReminderPlan get last => plans.last;

  @override
  Future<void> sync(ReminderPlan plan) async => plans.add(plan);
}

/// Hands out prepared files instead of opening the camera or a file dialog.
class FakeAttachmentPicker implements AttachmentPicker {
  FakeAttachmentPicker({this.photo, this.pdf});

  PickedFile? photo;
  PickedFile? pdf;
  final asked = <String>[];

  @override
  Future<PickedFile?> takePhoto() async {
    asked.add('camera');
    return photo;
  }

  @override
  Future<PickedFile?> pickPhoto() async {
    asked.add('gallery');
    return photo;
  }

  @override
  Future<PickedFile?> pickPdf() async {
    asked.add('pdf');
    return pdf;
  }
}

/// Remembers what the app asked to share or open instead of doing it.
class FakeFileSharer implements FileSharer {
  final shared = <SharedFile>[];
  final opened = <Uri>[];
  bool succeeds = true;

  @override
  Future<bool> share(SharedFile file) async {
    shared.add(file);
    return succeeds;
  }

  @override
  Future<bool> openLink(Uri link) async {
    opened.add(link);
    return succeeds;
  }
}

/// Remembers the reports the app asked to turn into a PDF, and hands back
/// a small stand-in file.
class RecordingPdfBuilder implements HealthPdfBuilder {
  final reports = <HealthReport>[];
  bool failing = false;

  HealthReport get last => reports.last;

  @override
  Future<Uint8List> build(HealthReport report) async {
    if (failing) throw const HealthException('Could not prepare the PDF. Please try again.');
    reports.add(report);
    return FakeHealthRepository.samplePdf;
  }
}

/// Hands back small stand-in files instead of photographing the lost card.
class FakeLostCardRenderer implements LostCardRenderer {
  int pictures = 0;
  final pdfTitles = <String>[];
  bool failing = false;

  @override
  Future<Uint8List> png(GlobalKey boundary, {double width = 1080}) async {
    if (failing) throw const HealthException('Could not prepare the card. Please try again.');
    pictures++;
    return FakeHealthRepository.samplePng;
  }

  @override
  Future<Uint8List> pdf(Uint8List png, {required String title}) async {
    pdfTitles.add(title);
    return FakeHealthRepository.samplePdf;
  }
}

/// The photo a lost card gets: none, unless a test sets one.
class FakeLostCardPhotoSource implements LostCardPhotoSource {
  ImageProvider? photo;
  final asked = <String>[];

  @override
  Future<ImageProvider?> photoOf(Pet pet) async {
    asked.add(pet.id);
    return photo;
  }
}

PickedFile testPhoto([String name = 'booklet.png']) =>
    PickedFile(name: name, mimeType: 'image/png', bytes: FakeHealthRepository.samplePng);

PickedFile testPdf([String name = 'lab-results.pdf']) =>
    PickedFile(name: name, mimeType: 'application/pdf', bytes: FakeHealthRepository.samplePdf);

/// A file over the bucket's 5 MB limit.
PickedFile hugePdf() =>
    PickedFile(name: 'huge.pdf', mimeType: 'application/pdf', bytes: Uint8List(PickedFile.maxBytes + 1));

/// Everything a Health test can swap out.
class HealthHarness {
  HealthHarness({FakeHealthRepository? repository, this.pets})
    : repository = repository ?? fakeHealth(),
      launcher = RecordingContactLauncher(),
      scheduler = RecordingReminderScheduler(),
      picker = FakeAttachmentPicker(),
      sharer = FakeFileSharer(),
      pdf = RecordingPdfBuilder(),
      cardRenderer = FakeLostCardRenderer(),
      cardPhotos = FakeLostCardPhotoSource();

  final FakeHealthRepository repository;
  final RecordingContactLauncher launcher;
  final RecordingReminderScheduler scheduler;
  final FakeAttachmentPicker picker;
  final FakeFileSharer sharer;
  final RecordingPdfBuilder pdf;
  final FakeLostCardRenderer cardRenderer;
  final FakeLostCardPhotoSource cardPhotos;

  /// Replaces the shared sample pets (to test other species).
  final List<Pet>? pets;

  DateTime now = fixedNow;

  ProviderContainer container() {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);
    return container;
  }

  List<Override> _overrides() => [
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
    healthClockProvider.overrideWithValue(() => now),
    healthRepositoryProvider.overrideWithValue(repository),
    contactLauncherProvider.overrideWithValue(launcher),
    reminderSchedulerProvider.overrideWithValue(scheduler),
    attachmentPickerProvider.overrideWithValue(picker),
    fileSharerProvider.overrideWithValue(sharer),
    healthPdfBuilderProvider.overrideWithValue(pdf),
    lostCardRendererProvider.overrideWithValue(cardRenderer),
    lostCardPhotoSourceProvider.overrideWithValue(cardPhotos),
    if (pets != null) petsProvider.overrideWith(() => _FixedPets(pets!)),
  ];
}

class _FixedPets extends PetsNotifier {
  _FixedPets(this._pets);

  final List<Pet> _pets;

  @override
  List<Pet> build() => _pets;
}

/// Pumps the whole app on fakes at phone size, signs in as the demo user
/// (Alex) and opens the Health tab.
Future<HealthHarness> pumpHealth(
  WidgetTester tester, {
  HealthHarness? harness,
  Size size = const Size(390, 844),
  bool openTab = true,
}) async {
  // Sign in at phone size (the login form needs the room), then switch to
  // the size under test.
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final h = harness ?? HealthHarness();
  await tester.pumpWidget(ProviderScope(overrides: h._overrides(), child: const PetCompanionApp()));
  await tester.pumpAndSettle();
  await signInAsDemo(tester);
  tester.view.physicalSize = size * 3;
  await tester.pumpAndSettle();
  if (openTab) await openHealthTab(tester);
  return h;
}

/// Taps "Health" in the bottom bar.
Future<void> openHealthTab(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Health')));
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  // A text field that was just typed in scrolls itself back into view
  // once; the second pass wins.
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pumps [child] alone (in the app's theme, at phone size) on the fakes,
/// signed in as the demo user (Alex) unless [signedIn] is false. For
/// pieces that other tabs place, such as the emergency button.
Future<HealthHarness> pumpHealthHost(
  WidgetTester tester,
  Widget child, {
  HealthHarness? harness,
  bool signedIn = true,
  bool page = false,
  TextDirection textDirection = TextDirection.ltr,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final h = harness ?? HealthHarness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: h._overrides(),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, app) => Directionality(textDirection: textDirection, child: app!),
        // [page]: the child is a whole screen and brings its own Scaffold.
        home: page
            ? child
            : Scaffold(
                body: SafeArea(child: SingleChildScrollView(child: child)),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (signedIn) {
    // Not awaited: the fake's delays only elapse while the tester pumps.
    unawaited(
      hostContainer(tester)
          .read(authControllerProvider.notifier)
          .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword),
    );
    await tester.pumpAndSettle();
  }
  return h;
}

/// The provider container of the widget tree under test.
ProviderContainer hostContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)), listen: false);

/// Runs [body] outside the test's fake clock and returns its result. Use
/// it to ask the fake repository something directly: its (zero) delays
/// never elapse inside a widget test otherwise.
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async => (await tester.runAsync(body)) as T;

/// Keeps [provider] alive, lets its loading finish and returns its state.
Future<AsyncValue<T>> settled<T>(WidgetTester tester, ProviderListenable<AsyncValue<T>> provider) async {
  final container = hostContainer(tester);
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return sub.read();
}

/// Opens one of the tab's four sections by its label in the switcher.
Future<void> openSection(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(CoralSegmentedControl), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Selects another pet in the tab's pet switcher.
Future<void> selectPet(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(of: find.byType(PetSelector), matching: find.text(name)));
  await tester.pumpAndSettle();
}
