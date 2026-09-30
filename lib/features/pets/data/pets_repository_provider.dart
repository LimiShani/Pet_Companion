import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import 'fake_pets_repository.dart';
import 'pets_repository.dart';
import 'supabase_pets_repository.dart';

/// The pets backend: Supabase when the app is built with its configuration,
/// otherwise the in-memory sample pets.
///
/// The sample pets live in memory, so the app's own fake does not pretend to
/// be slow: nothing is ever left waiting on a timer. Tests that want to see a
/// loading state pass their own `FakePetsRepository(latency: ..., instant:
/// false)`.
final petsRepositoryProvider = Provider<PetsRepository>((ref) => AppConfig.hasSupabase
    ? SupabasePetsRepository(sb.Supabase.instance.client)
    : FakePetsRepository(latency: Duration.zero));

/// "Now" for everything time-related about pets (the 7-day "Not now", the
/// archive date). Tests override it with a fixed instant.
final petsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// User-facing text for a pets failure.
String petsErrorMessage(Object error) =>
    error is PetsException ? error.message : 'Something went wrong. Please try again.';
