import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/community/chat/private_chat_providers.dart';
import 'package:pet_companion/features/community/community_routes.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/members/member_screen.dart';
import 'package:pet_companion/features/community/members/members_providers.dart';
import 'package:pet_companion/features/community/widgets/post_photo_view.dart';
import 'package:pet_companion/features/settings/settings_pages.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/navigation/app_router.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/services/community/data/push_preferences_repository.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:go_router/go_router.dart';

import '../helpers.dart';
import 'community_helpers.dart';

/// The Community tab with the demo account's private chats: one with
/// Maya, the group walk, and Dana's invitation.
CommunityHarness withChats({AppLanguage? language, FakeAccessRepository? access}) => CommunityHarness(
      chat: FakeChatRepository(latency: Duration.zero, now: testClock),
      appLanguage: language,
      access: access,
    );

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: reads(title));

/// A widget a screen reader names [label] (inside a card the name merges
/// into the card's).
Finder labelled(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label, description: 'labelled "$label"');

Future<void> openChatSection(WidgetTester tester, {CommunityL10n? words}) => openSection(tester, (words ?? en).sectionChat);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(reads(text).first);
  await tester.pumpAndSettle();
  await tester.tap(reads(text).first);
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) => hostContainer(tester);

class _Messaging implements PushMessaging {
  @override
  String get platform => 'android';
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<String?> token() async => 'token-1';
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<PushArrival> get arrivals => const Stream.empty();
  @override
  Stream<String> get taps => const Stream.empty();
  @override
  Future<String?> initialTap() async => null;
  @override
  Future<void> deleteToken() async {}
}

class _Devices implements PushDeviceRepository {
  @override
  Future<void> register({required String token, required String platform, required String language}) async {}
  @override
  Future<void> unregister(String token) async {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('My chats', () {
    testWidgets('the invitation comes first, then my chats, then the topic rooms', (tester) async {
      await pumpCommunity(tester, harness: withChats());
      await openChatSection(tester);

      expect(find.text('Kitten playdates'), findsOneWidget);
      expect(reads('Dana invited you · 3 participants'), findsOneWidget);
      expect(find.text('My chats'), findsOneWidget);
      expect(find.text('Topic rooms'), findsOneWidget);
      // Most recently active first; a chat of two shows the other person.
      final maya = tester.getTopLeft(find.text('Maya')).dy;
      final walks = tester.getTopLeft(find.text('Morning walks in the park')).dy;
      expect(tester.getTopLeft(find.text('Kitten playdates')).dy, lessThan(maya));
      expect(maya, lessThan(walks));
      expect(walks, lessThan(tester.getTopLeft(find.text('Topic rooms')).dy));
      expect(find.text('Saturday at 8 by the lifeguard tower then 🐾'), findsOneWidget);
      expect(find.text('Noa: Lovely walk today, thank you all!'), findsOneWidget);
      expect(labelled('1 unread message'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      expect(find.text('New chat'), findsOneWidget);
      Navigator.of(tester.element(find.text('New chat'))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('joining opens the chat from the moment of the invitation', (tester) async {
      final h = await pumpCommunity(tester, harness: withChats());
      await openChatSection(tester);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();

      expect(headerTitle('Kitten playdates'), findsOneWidget);
      expect(find.text('Dana added you'), findsOneWidget);
      expect(find.text('You joined'), findsOneWidget);
      // Written before Alex was invited.
      expect(find.text('Saturday afternoon at my place? Mitzi needs friends.'), findsNothing);
      expect(reads('Private chat · 3 participants'), findsOneWidget);
      expect(await tester.runAsync(() => h.chat.fetchInvitations(viewer: demoUser)), isEmpty);

      await goBack(tester);
      expect(find.text('Join'), findsNothing);
      expect(find.text('Kitten playdates'), findsOneWidget);
    });

    testWidgets('No thanks drops the invitation', (tester) async {
      await pumpCommunity(tester, harness: withChats());
      await openChatSection(tester);
      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation declined'), findsOneWidget);
      expect(find.text('Kitten playdates'), findsNothing);
    });

    testWidgets('the invitation is on the Activity page too, with the bell', (tester) async {
      await pumpCommunity(tester, harness: withChats());
      await tester.tap(find.byTooltip(en.activityNew));
      await tester.pumpAndSettle();
      expect(find.text('Invitations'), findsOneWidget);
      expect(find.text('Kitten playdates'), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(headerTitle('Kitten playdates'), findsOneWidget);
    });

    testWidgets('without the capability there are no private chats', (tester) async {
      await pumpCommunity(
        tester,
        harness: withChats(access: FakeAccessRepository()..users[demoUser.id] = {privateChatCapability: AccessRule.deny}),
      );
      await openChatSection(tester);
      expect(find.text('My chats'), findsNothing);
      expect(find.text('Kitten playdates'), findsNothing);
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-new-chat')), findsNothing);
      expect(find.byKey(const ValueKey('add-post-moment')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const ValueKey('add-post-moment')))).pop();
      await tester.pumpAndSettle();
      expect(find.text('General'), findsOneWidget);

      GoRouter.of(tester.element(find.byType(CoralHeader).first)).push(CommunityRoutes.member('u-maya'));
      await tester.pumpAndSettle();
      expect(find.text('Private message'), findsNothing);
    });
  });

  group('a group chat', () {
    testWidgets('system lines, the people line and the details of a member', (tester) async {
      final h = await pumpCommunity(tester, harness: withChats(), size: const Size(390, 1400));
      await openChatSection(tester);
      await tapText(tester, 'Morning walks in the park');

      expect(headerTitle('Morning walks in the park'), findsOneWidget);
      for (final line in ['Noa created the chat', 'Noa added you and Jonas', 'You joined', 'Jonas joined', 'Noa added Sam']) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(find.text('Luna and I are in.'), findsOneWidget);
      // No advice note in a private chat.
      expect(find.textContaining(en.adviceNotice, findRichText: true), findsNothing);

      await tester.tap(find.byKey(const ValueKey('chat-people')));
      await tester.pumpAndSettle();
      expect(headerTitle('Chat details'), findsOneWidget);
      expect(reads('Private chat · 4 participants'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      // A member, not an admin: no adding, renaming or menus.
      expect(find.text('Add participants'), findsNothing);
      expect(find.text('Rename'), findsNothing);
      expect(find.byTooltip('Options for Jonas'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mute-chat')));
      await tester.pumpAndSettle();
      expect(h.chat.mutedOnServer(FakeChatRepository.walksChatId, demoUser.id), isTrue);
      expect(containerOf(tester).read(mutedRoomsProvider), contains(FakeChatRepository.walksChatId));
      expect(find.text('Muted: no notifications and no unread count'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('leave-chat')));
      await tester.pumpAndSettle();
      expect(find.text('Leave this chat?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();
      expect(find.text('You left the chat'), findsOneWidget);
      expect(find.text('Morning walks in the park'), findsNothing);
      expect(find.text('Maya'), findsOneWidget);
    });

    testWidgets('an admin starts a group, renames it, adds, makes admin and removes', (tester) async {
      final h = await pumpCommunity(tester, harness: withChats(), size: const Size(390, 1000));
      await openChatSection(tester);
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-new-chat')));
      await tester.pumpAndSettle();

      expect(find.text('People you talked with recently'), findsOneWidget);
      expect(find.text('Community members'), findsOneWidget);
      expect(find.byKey(const ValueKey('person-demo')), findsNothing);
      await tester.enterText(find.byType(TextField), 'pri');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('person-u-priya')), findsOneWidget);
      expect(find.byKey(const ValueKey('person-u-omer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('person-u-priya')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('person-u-omer')), 100,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const ValueKey('person-u-omer')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chosen-u-priya')), findsOneWidget);
      expect(find.byKey(const ValueKey('chosen-u-omer')), findsOneWidget);
      expect(reads('2 selected · Up to 30 people in a chat'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Name the chat'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Create chat');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('chat-name')), 'Beach day');
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(headerTitle('Beach day'), findsOneWidget);
      expect(find.text('You created the chat'), findsOneWidget);
      expect(find.text('You added Priya, Omer'), findsOneWidget);
      final id = (await tester.runAsync(() => h.chat.fetchPrivateChats(viewer: demoUser)))!
          .firstWhere((c) => c.name == 'Beach day')
          .id;

      // Omer joins.
      h.chat.answerAs(id, 'u-omer');
      containerOf(tester).invalidate(privateChatsProvider);
      await tester.pumpAndSettle();
      expect(find.text('Omer joined'), findsOneWidget);

      await tester.tap(find.byTooltip('Chat details'));
      await tester.pumpAndSettle();
      expect(find.text('Add participants'), findsOneWidget);

      await tester.tap(find.byTooltip('Options for Omer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin'));
      await tester.pumpAndSettle();
      expect(find.text('Admin'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Options for Priya'));
      await tester.pumpAndSettle();
      expect(find.text('Make admin'), findsNothing);
      await tester.tap(find.text('Cancel invitation'));
      await tester.pumpAndSettle();
      expect(find.text('Removed from the chat'), findsOneWidget);
      expect(find.byKey(const ValueKey('member-u-priya')), findsNothing);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rename-field')), 'Beach mornings');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Chat renamed'), findsOneWidget);
      expect(find.text('Beach mornings'), findsOneWidget);
      // The snack bar would cover the button of the next page.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add participants'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('person-u-omer')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('person-u-sam')), 100,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const ValueKey('person-u-sam')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation sent'), findsOneWidget);
      expect(find.byKey(const ValueKey('member-u-sam')), findsOneWidget);

      await goBack(tester);
      for (final line in ['You made Omer admin', 'You renamed the chat to Beach mornings', 'You added Sam']) {
        await scrollOnTop(tester, find.text(line));
        expect(find.text(line), findsOneWidget, reason: line);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('a chat of two', () {
    testWidgets('one person: Next opens the chat of the two; Private message reopens it', (tester) async {
      await pumpCommunity(tester, harness: withChats());
      await openChatSection(tester);
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-new-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('person-u-maya')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(headerTitle('Maya'), findsOneWidget);
      expect(find.text('Saturday at 8 by the lifeguard tower then 🐾'), findsOneWidget);
      await goBack(tester);

      GoRouter.of(tester.element(find.byType(CoralHeader).first)).push(CommunityRoutes.member('u-maya'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private message'));
      await tester.pumpAndSettle();
      expect(headerTitle('Maya'), findsOneWidget);
      expect(find.text('Kelly would love that. Saturday morning?'), findsOneWidget);
    });

    testWidgets('another feature opens a chat with a draft ready to send', (tester) async {
      final h = await pumpCommunity(tester, harness: withChats());
      GoRouter.of(tester.element(find.byType(CoralHeader).first)).push(CommunityRoutes.member('u-priya'));
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(MemberScreen));
      unawaited(openDirectChat(element, element as WidgetRef, userId: 'u-priya', draft: 'Hi Priya, about the walk'));
      await tester.pumpAndSettle();

      expect(headerTitle('Priya'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Hi Priya, about the walk');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('Hi Priya, about the walk'), findsOneWidget);
      final chats = await tester.runAsync(() => h.chat.fetchPrivateChats(viewer: demoUser));
      final priya = chats!.firstWhere((c) => c.directWith == 'u-priya');
      expect(priya.member('u-priya')!.joined, isFalse);
    });

    testWidgets('a photo reaches the members only', (tester) async {
      final h = await pumpCommunity(tester, harness: withChats());
      await openChatSection(tester);
      await tester.tap(find.text('Maya'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.byType(PostPhotoView), findsOneWidget);

      Future<int> photosFor(String viewerId) async {
        final seen = await tester.runAsync(
          () => h.chat.watchMessages(FakeChatRepository.mayaChatId, viewerId: viewerId).first,
        );
        return seen!.where((m) => m.photo != null).length;
      }

      expect(await photosFor('u-maya'), 1);
      expect(await photosFor('u-priya'), 0);
    });

    testWidgets('a block closes it: blocked by the other, or by me', (tester) async {
      final harness = withChats();
      harness.chat.blocks.add(('u-maya', demoUser.id));
      final h = await pumpCommunity(tester, harness: harness);
      await openChatSection(tester);
      await tester.tap(find.text('Maya'));
      await tester.pumpAndSettle();
      expect(find.text('This chat is closed.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await goBack(tester);

      h.chat.blocks.clear();
      containerOf(tester).invalidate(privateChatsProvider);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maya'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.longPress(find.text('Saturday at 8 by the lifeguard tower then 🐾'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Maya'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(find.text('You blocked Maya. Unblock them to write here again.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await goBack(tester);
      // Hidden from my list while blocked.
      expect(find.text('Maya'), findsNothing);
    });
  });

  testWidgets('Settings has the private chat push switches', (tester) async {
    final preferences = FakePushPreferencesRepository();
    await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [
      pushMessagingProvider.overrideWithValue(_Messaging()),
      pushDeviceRepositoryProvider.overrideWithValue(_Devices()),
      pushPreferencesRepositoryProvider.overrideWithValue(preferences),
      feedRepositoryProvider.overrideWithValue(FakeFeedRepository(latency: Duration.zero)),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository(latency: Duration.zero)),
    ]);
    await signInAsDemo(tester);
    await tester.pumpAndSettle();
    // The push switches are on Settings > Notifications.
    hostContainer(tester).read(routerProvider).push('/settings/notifications');
    await tester.pumpAndSettle();
    expect(find.byKey(NotificationSettingsScreen.screenKey), findsOneWidget);

    final messages = find.byKey(const ValueKey('push-private-messages'));
    await tester.scrollUntilVisible(messages, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Messages in my private chats'), findsOneWidget);
    expect(find.text('Invitations to a chat'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(messages).value, isTrue);
    await tester.tap(messages);
    await tester.pumpAndSettle();
    expect(preferences.saved['demo']!.privateMessages, isFalse);
    expect(preferences.saved['demo']!.chatInvites, isTrue);
  });

  group('in Hebrew at 320 px', () {
    testWidgets('My chats, an invitation, a conversation, its details and New chat fit', (tester) async {
      await pumpCommunity(tester, harness: withChats(language: AppLanguage.hebrew), size: const Size(320, 568));
      await openChatSection(tester, words: he);
      expect(find.text(he.myChats), findsOneWidget);
      expect(reads(he.invitationFrom('Dana')), findsNothing);
      expect(reads('${he.invitationFrom('Dana')} · ${he.participantCount(3)}'), findsOneWidget);
      expect(find.text(he.joinChat), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapVisible(tester, find.text('Morning walks in the park'));
      for (final line in [he.sysAdded('Noa', 'Sam'), he.sysJoinedMine, he.sysCreated('Noa')]) {
        await scrollOnTop(tester, reads(line));
        expect(reads(line), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('chat-people')));
      await tester.pumpAndSettle();
      expect(headerTitle(he.chatDetails), findsOneWidget);
      expect(find.text(he.invitedTag), findsOneWidget);
      expect(find.text(he.adminTag), findsOneWidget);
      await scrollOnTop(tester, find.byKey(const ValueKey('leave-chat')));
      expect(find.text(he.leaveChat), findsOneWidget);
      expect(tester.takeException(), isNull);
      await goBack(tester);
      await goBack(tester);

      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-new-chat')));
      await tester.pumpAndSettle();
      expect(find.text(he.recentPeople), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('person-u-noa')));
      await tester.tap(find.byKey(const ValueKey('person-u-jonas')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(he.nextStep));
      await tester.pumpAndSettle();
      expect(find.text(he.groupNameTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
