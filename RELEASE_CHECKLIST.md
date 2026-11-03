# Release checklist: Google Play and Steam

Steps marked **OWNER** need the human who owns the developer accounts. Everything else is a
command or a task card. Store rules change: re-read the linked official page before each step.
Background and dates are in [docs/PLAN.md](docs/PLAN.md) §3–4.

## Before either store

- [ ] **OWNER** Check the name: search Steam, Google Play and trademark databases for
      "Deadweight" / "Dead Weight" (PLAN O9).
- [ ] **OWNER** Pick the publisher name and a contact email that will be public.
- [ ] **OWNER** Replace `[CONTACT EMAIL]` in `PRIVACY_POLICY.md` and `store/privacy-policy.html`,
      then host the HTML file at a permanent public URL (GitHub Pages, Google Sites or your own
      site). Both stores link to it.
- [ ] Run `tools/make-upload-key.ps1` once (done 3 Nov 2026), and **OWNER** back up `.tools/keys/`
      somewhere private.

## Google Play

Rules for personal developer accounts created after 13 Nov 2023: a closed test with **at least 12
testers opted in for 14 days in a row** before you can apply for production
([testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)).
New apps must target API 36 ([target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en));
the builds already do.

1. [ ] **OWNER** Create the developer account at [play.google.com/console/signup](https://play.google.com/console/signup),
       pay the one-time fee and verify your identity. An organisation account (needs a D-U-N-S
       number) is exempt from the 12-tester rule.
2. [ ] **OWNER** Choose the business model (listing.md explains A, free to try with a one-time
       unlock, versus B, paid). **Play never lets a free app become paid**, and closed testers must
       buy a paid app ([pricing](https://support.google.com/googleplay/android-developer/answer/6334373?hl=en),
       [test tracks](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)).
3. [ ] **OWNER** Choose the permanent package id (for example `com.yourname.deadweight`); it can
       never change after the first upload. Put it in `tools/release.json` → `package`.
4. [ ] Build: raise `version_code` in `tools/release.json`, then
       `tools/build.ps1 -Target AndroidAab`. Upload `builds/DEADWEIGHT-<version>.aab`.
5. [ ] **OWNER** Create the app in Play Console: name DEADWEIGHT, default language English, Game,
       free or paid per step 2 ([create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)).
6. [ ] **OWNER** Policy > App content, from the files in `store/google-play/`:
       - Privacy policy: the URL from "Before either store".
       - App access: everything is available without special access.
       - Ads: no ads.
       - Content rating: `content-rating.md` ([content ratings](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en)).
       - Target audience: 13 and over ([target audience](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)).
       - Data safety: `data-safety.md` ([Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)).
       - Remaining declarations (government, financial, health, news): no.
7. [ ] **OWNER** Main store listing: text from `listing.md`, icon `store/art/google-play/icon_512.png`,
       feature graphic, at least two phone screenshots.
8. [ ] **OWNER** Testing > Closed testing: create a track and a release, accept **Play App
       Signing** on the first upload (Google keeps the app signing key; yours is only the upload
       key), upload the AAB, add the testers' email list, roll out, and send them the opt-in link.
       **The 14-day clock starts when 12 testers have opted in.** Keep them opted in.
9. [ ] Keep shipping test builds to the same track: raise `version_code`, rebuild, upload.
10. [ ] **OWNER** After 14 days, apply for production access on the Dashboard and answer the
        questions about the test. Then roll out the v1.0 AAB to production, ideally as a staged
        rollout. Review can take up to about a week ([prepare for review](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)).

## Steam

1. [ ] **OWNER** Join Steamworks through [Steam Direct](https://partner.steamgames.com/steamdirect):
       pay the US$100 app fee and complete identity, tax and bank details. **The release waiting
       period starts at payment** (21 days per the [onboarding guide](https://partner.steamgames.com/doc/gettingstarted/onboarding);
       older pages say 30).
2. [ ] **OWNER** Create the app. Put the App ID and the Windows and Linux depot IDs into
       `tools/release.json` (`steam_app_id`, `steam_depot_windows`, `steam_depot_linux`).
3. [ ] **OWNER** Store page: text from `store/steam/description.md`; capsules and at least five
       screenshots from task R6 ([store assets](https://partner.steamgames.com/doc/store/assets/standard),
       [library assets](https://partner.steamgames.com/doc/store/assets/libraryassets)).
       Submit it for review at least 7 business days before you want it visible; review takes
       about 3–5 business days.
4. [ ] **OWNER** When approved, press "Post as Coming Soon". The page must be public for **at
       least two weeks** before release ([Coming Soon](https://partner.steamgames.com/doc/store/coming_soon)).
5. [ ] **OWNER** Installation > General: launch options `DEADWEIGHT.exe` (Windows) and
       `DEADWEIGHT.x86_64` (Linux).
6. [ ] Build: `tools/build.ps1 -Target Windows,Linux`, then **OWNER**
       `tools/steam/upload.ps1 -SteamUser <account> -Preview` and again without `-Preview`
       ([uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading)). Set the build live
       on a beta branch, install it through Steam on Windows and on Linux or a Steam Deck, and play it.
7. [ ] **OWNER** Submit the build for review (needs the approved store page; about 3–5 business
       days), set the price, and request a Steam Deck compatibility review.
8. [ ] **OWNER** Release: Steam never releases a game by itself; press the release button
       ([release process](https://partner.steamgames.com/doc/store/releasing)).
9. [ ] **OWNER** Content Survey: fill in the AI-generated content disclosure from the draft in
       `store/steam/description.md` (PLAN O11).

## Every release candidate (task Q2)

- [ ] `tools/build.ps1 -Target All` ends with `BUILD: OK`; keep `builds/BUILD_INFO.txt` and
      `SHA256SUMS.txt` with the uploaded files.
- [ ] Played on a real Android phone (install with `tools/install-android.ps1`) and on PC with a
      gamepad; notes in `docs/PLAYTEST.md`.
- [ ] Store text still matches the game (levels, features, prices).
