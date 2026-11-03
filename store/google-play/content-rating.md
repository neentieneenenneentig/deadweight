# Content rating (IARC questionnaire)

Play Console > Policy > App content > Content ratings. Every app needs an IARC rating, and the
questionnaire must be redone whenever new content changes an answer. Official guide:
[Content ratings](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en).

Answer from what the build contains. The guidance below matches the v1.0 design.

| Topic | What the game contains | Answer |
| --- | --- | --- |
| Category | A game | Game (not "Reference, news or educational", not "Social") |
| Violence | The player shoots and smashes **robots** (hounds, sentries, drones). Robots break apart; no humans or animals are hurt. | Yes: fantasy violence against non-human, robotic characters |
| Blood and gore | None | No |
| Fear / horror | Industrial ruins and hostile robots; no horror imagery or jump scares | No |
| Sexuality, nudity | None | No |
| Language | None | No |
| Controlled substances | None | No |
| Gambling | No real or simulated gambling, no loot boxes | No |
| User interaction | No chat, no user-generated content, no sharing | No |
| Shares location | No | No |
| Digital purchases | Model A: one in-app purchase unlocks the full game. Model B: none | Yes for model A, No for model B |
| Unrestricted internet | No | No |

Expected result: a low age rating (roughly PEGI 7, ESRB Everyone 10+ for fantasy violence). The
calculated ratings appear on the summary page before you submit, and rating authorities may adjust
them later.

## Target audience (Policy > App content > Target audience and content)

Choose **13 and over** (13–15, 16–17, 18+). Choosing any age group under 13 brings in the Families
policy and its extra review. Guide: [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en).
