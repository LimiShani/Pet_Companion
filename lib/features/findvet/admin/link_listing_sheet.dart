import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/widgets/health_widgets.dart' show HealthLoading, SheetTitle, kHealthTapTarget, showHealthSheet;
import '../data/vet_admin_repository.dart';
import '../data/vet_models.dart';
import '../findvet_words.dart';
import '../regions/region.dart' show normalizePlaceName;
import '../state/find_vet_providers.dart';

/// Lets a directory reviewer attach a places-provider [listing] (a result
/// that came only from Google) to one of our facilities: a second listing
/// of a hospital we hold, or a facility we never linked. Only the listing's
/// place id is stored, which the provider allows.
///
/// Returns whether the listing was linked. Failures are shown in a snack
/// bar and return false.
Future<bool> linkListingToFacility(BuildContext context, WidgetRef ref, VetResult listing) async {
  final placeId = listing.placeId;
  if (placeId == null) return false;
  final facility = await showHealthSheet<AdminFacility>(context, _ChooseFacility(listing: listing));
  if (facility == null || !context.mounted) return false;

  final l10n = context.findVetL10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.adminLinkConfirm(listing.name, facility.name)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('link-listing-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.adminLink),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(vetAdminRepositoryProvider).linkPlace(facility.id, placeId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.adminLinked)));
    return true;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.adminLinkFailed)));
    return false;
  }
}

/// How much two names share, for putting the likely facility first:
/// the count of words (two letters or more) they have in common.
int _sharedWords(String a, String b) {
  Set<String> words(String s) => normalizePlaceName(s).split(' ').where((w) => w.length > 1).toSet();
  return words(a).intersection(words(b)).length;
}

class _ChooseFacility extends ConsumerWidget {
  const _ChooseFacility({required this.listing});

  final VetResult listing;

  static Key facilityKey(String id) => Key('link-listing-facility-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.findVetL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(l10n.adminLinkTitle, subtitle: listing.name),
        const SizedBox(height: 6),
        Text(l10n.adminLinkNote, style: AppText.secondary.copyWith(color: AppColors.brown)),
        const SizedBox(height: 10),
        FutureBuilder<List<AdminFacility>>(
          future: ref.read(vetAdminRepositoryProvider).facilities(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.adminLoadFailed, style: AppText.body);
            if (!snapshot.hasData) return const HealthLoading();
            int score(AdminFacility f) =>
                [_sharedWords(listing.name, f.name), if (f.nameHe != null) _sharedWords(listing.name, f.nameHe!)]
                    .reduce((a, b) => a > b ? a : b);
            final facilities = snapshot.data!.where((f) => f.reviewStatus != 'withdrawn').toList()
              ..sort((a, b) {
                final byScore = score(b).compareTo(score(a));
                return byScore != 0 ? byScore : a.name.compareTo(b.name);
              });
            if (facilities.isEmpty) return Text(l10n.adminLinkNoFacilities, style: AppText.body);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in facilities)
                  ListTile(
                    key: facilityKey(f.id),
                    minTileHeight: kHealthTapTarget,
                    leading: const AppIcon(Icons.local_hospital_rounded, color: AppColors.coralDark),
                    title: Text(
                      f.nameHe == null ? f.name : '${f.name} · ${f.nameHe}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [?f.address, ?f.city, l10n.reviewStatus(f.reviewStatus)].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(f),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
