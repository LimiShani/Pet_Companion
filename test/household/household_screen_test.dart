import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/household/household.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import '../helpers.dart';
import 'household_test_helpers.dart';

// The Household page from the You page, inviting, removing, renaming,
// joining, and the people badge on Home, in English and Hebrew.

void main() {
  setUpHouseholdTests();

  Finder header(String title) =>
      find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

  testWidgetsInBothLanguages(
    'the You row names the others; the page lists people, the invitation and the pets',
    (tester, language) async {
      final l10n = householdStrings(language);
      await pumpHouseholdHome(tester, language: language);
      await tester.tap(find.byTooltip(appStrings(language).youTitle));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(HouseholdMenuEntry.entryKey),
          matching: find.text('Dana, Noa'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(HouseholdMenuEntry.entryKey));
      await settle(tester);

      expect(header(l10n.nameTwoPets('Kelly', 'Soya')), findsOneWidget);
      expect(
        find.text('${l10n.peopleCount(3)} · ${l10n.petsCount(2)}'),
        findsOneWidget,
      );
      for (final name in ['Alex', 'Dana', 'Noa']) {
        expect(find.text(name), findsWidgets);
      }
      expect(find.text(l10n.roleOwner), findsOneWidget);
      expect(find.text(l10n.roleCarer), findsNWidgets(2));
      expect(find.text(l10n.you), findsOneWidget);
      expect(find.text('${l10n.openInvitation} · KELY-7Q4M'), findsOneWidget);
      expect(find.text(l10n.invitedTag), findsOneWidget);
      expect(find.text('Kelly'), findsOneWidget);
      expect(find.text('Soya'), findsOneWidget);
      expect(find.byKey(HouseholdScreen.inviteKey), findsOneWidget);
      expect(find.text(l10n.soloLine), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgetsInBothLanguages(
    'Invite someone reuses the open code and shares a link with it',
    (tester, language) async {
      final l10n = householdStrings(language);
      final shared = <String>[];
      await pumpHouseholdHome(tester, language: language, shared: shared);
      await openHouseholdPage(tester, language);
      await tester.tap(find.byKey(HouseholdScreen.inviteKey));
      await settle(tester);

      expect(find.text(l10n.inviteCanTitle), findsOneWidget);
      expect(find.text('KELY-7Q4M'), findsOneWidget);
      expect(find.text(l10n.inviteValidity), findsOneWidget);
      await tester.tap(find.byKey(InviteSheet.shareKey));
      await settle(tester);
      expect(shared, hasLength(1));
      expect(shared.single, contains('https://petloop.app/join/KELY7Q4M'));
      expect(shared.single, contains('KELY-7Q4M'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgetsInBothLanguages('the owner removes a carer, after asking', (
    tester,
    language,
  ) async {
    final l10n = householdStrings(language);
    await pumpHouseholdHome(tester, language: language);
    await openHouseholdPage(tester, language);
    // The owner's own row opens nothing.
    await tester.tap(find.byKey(HouseholdScreen.memberKey('demo')));
    await settle(tester);
    expect(find.text(l10n.remove), findsNothing);

    await tester.tap(find.byKey(HouseholdScreen.memberKey('noa')));
    await settle(tester);
    await tester.tap(find.text(l10n.remove));
    await settle(tester);
    expect(find.text(l10n.removeConfirmTitle('Noa')), findsOneWidget);
    await tester.tap(find.byKey(const Key('member-confirm')));
    await settle(tester);

    expect(find.byKey(HouseholdScreen.memberKey('noa')), findsNothing);
    expect(find.text(l10n.removedSnack('Noa')), findsOneWidget);
    expect(
      find.text('${l10n.peopleCount(2)} · ${l10n.petsCount(2)}'),
      findsOneWidget,
    );
  });

  testWidgetsInBothLanguages('the owner renames the household', (
    tester,
    language,
  ) async {
    final l10n = householdStrings(language);
    await pumpHouseholdHome(tester, language: language);
    await openHouseholdPage(tester, language);
    await tester.tap(find.byKey(HouseholdScreen.renameKey));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('household-name-field')),
      ' The Shanis ',
    );
    await tester.tap(find.text(appStrings(language).commonSave));
    await settle(tester);
    expect(header('The Shanis'), findsOneWidget);
    expect(header(l10n.nameTwoPets('Kelly', 'Soya')), findsNothing);
  });

  testWidgetsInBothLanguages(
    'a code opens the invitation; Join adds the household as a carer',
    (tester, language) async {
      final l10n = householdStrings(language);
      await pumpHouseholdHome(tester, language: language);
      await openHouseholdPage(tester, language);
      await tester.ensureVisible(find.byKey(HouseholdScreen.haveCodeKey));
      await tester.tap(find.byKey(HouseholdScreen.haveCodeKey));
      await settle(tester);
      expect(find.byKey(JoinHouseholdScreen.screenKey), findsOneWidget);

      // A code that leads nowhere says so, under the field.
      await tester.enterText(
        find.byKey(JoinHouseholdScreen.codeFieldKey),
        'zzzz-9999',
      );
      await tester.tap(find.byKey(JoinHouseholdScreen.continueKey));
      await settle(tester);
      expect(find.text(l10n.errNotFound), findsOneWidget);

      await tester.enterText(
        find.byKey(JoinHouseholdScreen.codeFieldKey),
        'maya-2345',
      );
      await tester.tap(find.byKey(JoinHouseholdScreen.continueKey));
      await settle(tester);
      expect(find.text(l10n.nameOnePet('Bamba')), findsOneWidget);
      expect(
        find.text(
          '${l10n.joinInvitationFrom('Maya')} · ${l10n.peopleCount(1)}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.inviteCan1), findsOneWidget);

      await tester.tap(find.byKey(JoinHouseholdScreen.joinKey));
      await settle(tester);
      expect(find.text(l10n.joinedSnack), findsOneWidget);
      // Two households now: each under its own name, on one page.
      expect(find.byKey(HouseholdScreen.screenKey), findsOneWidget);
      expect(header(l10n.title), findsOneWidget);
      expect(find.text(l10n.nameTwoPets('Kelly', 'Soya')), findsOneWidget);
      expect(find.text(l10n.nameOnePet('Bamba')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgetsInBothLanguages(
    'an ended invitation says so and offers another code',
    (tester, language) async {
      final l10n = householdStrings(language);
      await pumpHouseholdHome(tester, language: language);
      await openHouseholdPage(tester, language);
      await tester.ensureVisible(find.byKey(HouseholdScreen.haveCodeKey));
      await tester.tap(find.byKey(HouseholdScreen.haveCodeKey));
      await settle(tester);
      await tester.enterText(
        find.byKey(JoinHouseholdScreen.codeFieldKey),
        FakeHouseholdRepository.demoExpiredCode,
      );
      await tester.tap(find.byKey(JoinHouseholdScreen.continueKey));
      await settle(tester);
      expect(find.text(l10n.errExpired), findsOneWidget);
      expect(find.byKey(JoinHouseholdScreen.joinKey), findsNothing);
      await tester.tap(find.text(l10n.haveCode));
      await settle(tester);
      expect(find.byKey(JoinHouseholdScreen.codeFieldKey), findsOneWidget);
    },
  );

  testWidgetsInBothLanguages(
    'Home shows who shares the pet; the badge opens the household',
    (tester, language) async {
      await pumpHouseholdHome(tester, language: language);
      expect(find.byKey(PetPeopleBadge.badgeKey), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(PetPeopleBadge.badgeKey)).label,
        householdStrings(language).heroWithLabel('Dana, Noa'),
      );
      await tester.tap(find.byKey(PetPeopleBadge.badgeKey));
      await settle(tester);
      expect(find.byKey(HouseholdScreen.screenKey), findsOneWidget);
    },
  );

  testWidgetsInBothLanguages('alone, the page invites; Home has no badge', (
    tester,
    language,
  ) async {
    final l10n = householdStrings(language);
    await pumpHouseholdHome(
      tester,
      language: language,
      repository: demoHouseholds(shared: false),
    );
    expect(find.byKey(PetPeopleBadge.badgeKey), findsNothing);
    await tester.tap(find.byTooltip(appStrings(language).youTitle));
    await settle(tester);
    expect(find.text(l10n.youRowSolo), findsOneWidget);
    await tester.tap(find.byKey(HouseholdMenuEntry.entryKey));
    await settle(tester);
    expect(find.text(l10n.soloLine), findsOneWidget);

    // A new code: none is open yet.
    await tester.tap(find.byKey(HouseholdScreen.inviteKey));
    await settle(tester);
    final code = tester.widget<InviteCodeBox>(find.byType(InviteCodeBox)).code;
    expect(looksLikeInviteCode(code), isTrue);
    expect(code, isNot(FakeHouseholdRepository.demoInviteCode));
  });
}
