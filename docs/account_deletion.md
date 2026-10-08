# Account deletion

Google Play and the App Store both require that a user can delete their
account from inside the app. PetLoop does it from the account sheet (the
initial at the top of Home): *Delete account* → a dialog that explains what
goes and asks for the confirmation word (`DELETE`, `מחיקה` in Hebrew) →
the account is deleted and the app returns to the login screen with
"Your account was deleted."

```
AccountSheet ─ DeleteAccountDialog (typed word) ─ AuthController.deleteAccount
  ├─ beforeSignOut tasks (push device unregistered)
  ├─ AuthRepository.deleteAccount
  │    Supabase: rpc delete_my_account() ─ delete from auth.users where id = auth.uid()
  │              then a local sign-out (the session is already dead)
  └─ state = signed out → router shows login
```

## What goes with the account

`delete from auth.users` cascades through the schema (0001 onwards):
profile, pets, care plan and logs, health records and documents, budget and
basket, community posts, comments, likes, chat messages, reports, blocks,
push devices and preferences, saved deals. Stored files (pet photos, health
documents, community photos) are queued for the storage clean-up worker by
the triggers from 0018 and removed within days. Crash reports keep their
row with `user_id` cleared (0024). Moderation records of actions taken
against the account are kept as the policy says.

## Setup (owner, once)

1. Run `supabase/migrations/0025_delete_my_account.sql` in the SQL editor
   (after 0024). Idempotent.
2. Rebuild the app.

The function runs as the database owner (`security definer`) because
clients have no rights on `auth.users`; it can only delete the caller.

## Store forms

- Google Play *Data safety → Data deletion*: the app offers in-app
  deletion; the web page is the Privacy Policy's "Deleting your account"
  section, `…/legal/privacy.html#delete` (Hebrew: `privacy.he.html#delete`),
  which also gives the contact address for users who cannot open the app.
- App Store Connect asks the same question; answer "yes, in app".

## Tests

- `test/auth_test.dart`: the sheet's button, the dialog's word gate, the
  return to login, the account really gone.
- `supabase/tests/delete_my_account_test.sql` (in `tool/test_database.ps1`):
  signed-out calls refused, only the caller deleted, cascades and file
  clean-up queue, crash reports kept without the account.
