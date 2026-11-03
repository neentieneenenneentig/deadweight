# Google Play Data safety form

Play Console > Policy > App content > Data safety. Every app must complete it, even one that
collects nothing, and it needs the privacy policy URL. Answers must cover every version on Google
Play. Official guide: [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

## Why the answer is "nothing collected"

- The release build requests one permission, `android.permission.VIBRATE`. `tools/build.ps1`
  fails any Android build that asks for more, so this stays true.
- No internet permission: the game cannot send data anywhere.
- No third-party SDKs: no ads, analytics, crash reporting or sign-in. The Godot engine adds none.
- Saves, settings and logs stay on the device. Data processed only on the device doesn't need
  disclosure.

## Answers

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| (The form then skips the data-type questions.) | |
| Is all of the user data collected by your app encrypted in transit? | Not asked when nothing is collected |
| Do you provide a way for users to request that their data is deleted? | Not asked when nothing is collected |

## Re-check before changing

Redo the form before any update that adds a permission, an SDK or a network feature. If model A
(the Play Billing full-game unlock, task P1) ships, re-read the guide above for how purchase
information processed by Google Play's billing system must be declared, and update this file with
the answers you give.
