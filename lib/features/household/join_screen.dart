import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../presentation/pets_widgets.dart';
import '../../services/household/data/household_models.dart';
import '../../services/household/state/household_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/petloop_icon.dart';
import '../../widgets/primary_button.dart';
import 'household_routes.dart';
import 'household_words.dart';
import 'invite_sheet.dart' show InviteAllows;

/// The join page (`/join`, `/join/<code>`): the invitation code, then the
/// invitation itself (the household's name, its pets, who invited, how many
/// people, what joining allows), Join and No thanks.
class JoinHouseholdScreen extends ConsumerStatefulWidget {
  const JoinHouseholdScreen({super.key, this.code});

  /// From the link; `null` asks for it.
  final String? code;

  static const screenKey = Key('join-screen');
  static const codeFieldKey = Key('join-code');
  static const continueKey = Key('join-continue');
  static const joinKey = Key('join-join');
  static const declineKey = Key('join-decline');

  @override
  ConsumerState<JoinHouseholdScreen> createState() => _JoinState();
}

class _JoinState extends ConsumerState<JoinHouseholdScreen> {
  late final _code = TextEditingController(
    text: widget.code == null
        ? ''
        : formatInviteCode(normalInviteCode(widget.code!)),
  );
  InvitePreview? _preview;
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.code != null && looksLikeInviteCode(widget.code!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _look());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _look() async {
    final l10n = context.householdL10n;
    if (!looksLikeInviteCode(_code.text)) {
      setState(() => _problem = l10n.errNotFound);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final preview = await ref
          .read(householdRepositoryProvider)
          .preview(_code.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _preview = preview.status == InviteStatus.notFound ? null : preview;
        _problem = switch (preview.status) {
          InviteStatus.notFound => l10n.errNotFound,
          InviteStatus.expired => l10n.errExpired,
          InviteStatus.used || InviteStatus.revoked => l10n.errUsed,
          InviteStatus.member => l10n.errMember,
          InviteStatus.open => null,
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = householdErrorText(l10n, e);
      });
    }
  }

  Future<void> _join() async {
    final preview = _preview!;
    final l10n = context.householdL10n;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(householdsProvider.notifier).accept(preview.code);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.joinedSnack)));
      if (!mounted) return;
      // Back to the Household page this was opened from (it shows the new
      // household at once); a join page that came first opens it instead.
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        router?.go(HouseholdRoutes.household);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = householdErrorText(l10n, e);
      });
    }
  }

  void _anotherCode() => setState(() {
    _preview = null;
    _problem = null;
    _code.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    final preview = _preview;
    return PetsPage(
      key: JoinHouseholdScreen.screenKey,
      title: l10n.joinTitle,
      child: preview == null
          ? _CodeForm(
              controller: _code,
              busy: _busy,
              problem: _problem,
              onContinue: _look,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InvitationCard(preview: preview),
                const SizedBox(height: 16),
                if (_problem != null) ...[
                  Text(
                    _problem!,
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _anotherCode,
                    child: Text(l10n.haveCode),
                  ),
                ] else ...[
                  PrimaryButton(
                    key: JoinHouseholdScreen.joinKey,
                    label: l10n.joinAction,
                    loading: _busy,
                    onPressed: _busy ? null : _join,
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: JoinHouseholdScreen.declineKey,
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brown,
                    ),
                    child: Text(l10n.joinDecline),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CodeForm extends StatelessWidget {
  const _CodeForm({
    required this.controller,
    required this.busy,
    required this.problem,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool busy;
  final String? problem;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsLabel(l10n.inviteCodeLabel, topGap: 0),
        TextField(
          key: JoinHouseholdScreen.codeFieldKey,
          controller: controller,
          autofocus: controller.text.isEmpty,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          // A code reads left to right on every screen.
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            hintText: l10n.joinCodeHint,
            errorText: problem,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => busy ? null : onContinue(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          key: JoinHouseholdScreen.continueKey,
          label: l10n.joinContinue,
          loading: busy,
          onPressed: busy ? null : onContinue,
        ),
      ],
    );
  }
}

/// The invitation: the pets, the household's name, who invited, how many
/// people, and what joining allows.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.preview});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return PetsCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final _ in preview.pets.take(4))
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const PetLoopIcon(
                    PetLoopGlyph.pet,
                    size: 28,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            previewName(l10n, preview),
            style: AppText.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (preview.inviterName.trim().isNotEmpty)
                l10n.joinInvitationFrom(preview.inviterName.trim()),
              l10n.peopleCount(preview.memberCount),
            ].join(' · '),
            style: AppText.secondary.copyWith(color: AppColors.brown),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const InviteAllows(),
        ],
      ),
    );
  }
}
