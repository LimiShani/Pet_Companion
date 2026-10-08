# Legal pages: Terms of Use and Privacy Policy

The app links to a published Terms of Use and Privacy Policy from the
sign-up screen (the "By creating an account you agree to…" line) and from
Settings ("About PetLoop"). Both stores require a public privacy policy
URL for the listing too.

The pages are static HTML in `docs/legal/`, in English and Hebrew, served
by GitHub Pages from this repository:

| Page | English | Hebrew |
| --- | --- | --- |
| Index | `legal/index.html` | |
| Terms of Use | `legal/terms.html` | `legal/terms.he.html` |
| Privacy Policy | `legal/privacy.html` | `legal/privacy.he.html` |

The app opens the Hebrew page when it runs in Hebrew and the English page
otherwise (`AppConfig.termsUrl` / `privacyUrl`). The base address is
`https://limishani.github.io/Pet_Companion/legal`; another host is given at
build time with `--dart-define=PETLOOP_LEGAL_URL=https://…/legal`.

## Before the pages go live (owner)

1. **Fill in the placeholders.** Every yellow-marked `[…]` in the four pages:
   the company name, the contact email (used for privacy requests, reports,
   security reports and disputes) and the Supabase region. Search the files
   for `placeholder`.
2. **Have the text reviewed.** The pages were written to describe what the
   app actually does, based on the Hebrew draft in
   `docs/PetLoop_Terms_and_Safety_Draft_HE.docx`, but they are not legal
   advice. A review by an Israeli lawyer (technology, consumer, privacy)
   is still due before real users sign up. Keep the English and Hebrew
   editions saying the same thing.
3. **Enable GitHub Pages**, once: repository *Settings → Pages → Build and
   deployment → Source: Deploy from a branch → Branch: `main`, folder
   `/docs` → Save*. The site appears within a few minutes at
   `https://limishani.github.io/Pet_Companion/legal/`. The `docs/.nojekyll`
   file makes GitHub serve the folder as-is (no Jekyll build), so the other
   docs in the folder are served as plain files; the repository is public,
   so nothing new becomes visible.
4. **Check both languages on a phone** (the pages are responsive) and the
   links from the app: sign-up screen and Settings → About PetLoop.

## Keeping them current

The Privacy Policy lists what the app collects and which services see it
(Supabase, Firebase Cloud Messaging for push, Google Places for vet
searches, Google Fonts). When a feature adds a data category or a service,
update both languages, bump the version and date at the top, and tell
users in the app when the change matters.

## Tests

- `test/auth_test.dart`: the sign-up notice's two links open the English
  pages, and the Hebrew ones in Hebrew.
- `test/settings/settings_test.dart`: Settings → About PetLoop opens the
  pages in the browser.
