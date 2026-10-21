# RSM asset provenance

Recorded 19 October 2026 during release-readiness review. Inventory extended 20 October 2026.

## Club badges, flags and player portraits

The user confirmed that ChatGPT created these assets. The repository import record independently documents that origin:

- Commit: `06bf51e490dc99676c29b2d220de6be048881181` (24 August 2026).
- Commit subject: `Add real club badge, national flag, and player portrait art`.
- Its body identifies three **AI-generated (ChatGPT, user-owned) reference sheets**, sliced into 24 club badges, 163 national flags and 66 player portraits.
- Imported asset folders: `Retro Season Manager/Assets.xcassets/Badges`, `Flags` and `Portraits`.
- The phrase “real” in the subject and rendering comments distinguishes image assets from the prior procedural drawing system. It must not be treated as evidence that these are licensed professional-club crests or photographs of actual players.

This record documents the user's confirmation and the Git import history. The original generation prompts/reference sheets are not included in this repository, so this file does not claim to reproduce those records or provide independent legal clearance.

## Scope

This inventory covers all bundled artwork families below. On 21 October 2026, John confirmed in the release-readiness conversation: “all artwork was created by you”, referring to ChatGPT. This confirmation covers the app icon, backgrounds, overlays, navigation icons, manager art, pack art and experience/control artwork as well as the previously documented badges, flags and portraits. It establishes the reported creator; it does not identify exact prompts, generation dates, model versions or which reference sheets were used. Git dates below remain import dates. Identifiable parody names and likeness questions remain a separate content review.

## Remaining artwork inventory

The catalog at `Retro Season Manager/Assets.xcassets` holds 299 PNG rasters. Of these, 253 are the badge, flag and portrait slices above. The remaining 46 are listed below. Each family was traced through `git log` on the catalog paths; the commit dates are committer dates.

Evidence levels: **Documented** identifies the sets supported by both user confirmation and an explicit Git origin record. **User-confirmed** identifies ChatGPT origin confirmed by John on 21 October 2026; the associated Git records establish import history rather than independently documenting generation. Original prompts/reference sheets are not present in the repository. PR descriptions remain author statements.

| Asset family | Repository paths | Origin evidence | Import/creation record | Status | Missing information / next action |
|---|---|---|---|---|---|
| Club badges (24), national flags (163), player portraits (66) | `Assets.xcassets/Badges`, `Flags`, `Portraits` | ChatGPT-generated, user-owned reference sheets, sliced (see above) | `06bf51e` (24 Aug 2026) | Documented | Original sheets/prompts not in repo; keep them with the user's records. |
| Manager portraits and full-body art (5 archetypes × 2 = 10: Architect, General, Maverick, Professor, Strategist) | `Assets.xcassets/Managers/Manager*.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). Commit body says "real portrait/full-body art for the five manager archetypes". No tool, prompt or sheet named. | `9ea1023` (24 Aug 2026), same commit as the Settings fix | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Legends pack art (12 packs: Starter, Bronze, Silver, Gold, Heroes, Legend, Icons, Wonderkids, 1990s, 2000s, 2010s, Hall of Icons) | `Assets.xcassets/LegendsPacks/LegendsPack*.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). PR #8 (johnwderrick/RSM#8) describes "12 original pack designs" that are "original, fictional and licensing-safe". No generation method named. | Merge commit `8fc58ab` (2 Sep 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Settings button, normal and pressed (2) | `Assets.xcassets/Experience/RSMSettingsButton*.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). Original set added in `06bf51e`. Replaced twice on 2 Sep 2026: `8130e8e` (PR #9, "Fix clipped home settings button artwork", a "purple-chrome" redesign) and `d551122` (PR #10, "Give Settings a distinct control design"). Both PRs describe the design and the 1020×324 RGBA dimensions. Neither names a tool. | `06bf51e` (added); `8130e8e` and `d551122` (replaced) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Career and Legends entry buttons, normal and pressed (4), and experience background (1) | `Assets.xcassets/Experience/RSMCareerEntryButton*`, `RSMLegendsEntryButton*`, `RSMExperienceBackground.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). Added in `06bf51e`, the ChatGPT-sheet import commit. Its body names only badges, flags and portraits, so these images are not described there. | `06bf51e` (24 Aug 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| App icon and accent colour | `Assets.xcassets/AppIcon.appiconset/AppIcon.png`; `AccentColor.colorset` | John confirms ChatGPT created this artwork (21 Oct 2026). First committed in the initial project import. No creation record. | `f52db78` (12 Aug 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Main-menu and stadium backgrounds (2) | `Assets.xcassets/Backgrounds/MainMenuBackground`, `StadiumBackground` | John confirms ChatGPT created this artwork (21 Oct 2026). First committed in `f52db78`. Moved into `Backgrounds/` in `b3b8bc7`. No creation record. | `f52db78` (12 Aug 2026); relocated `b3b8bc7` (13 Aug 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Flash-screen overlays (4): goal against, goal celebration, penalty awarded, red-card flash | `Assets.xcassets/FlashScreens/*.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). First committed in `f52db78`. Moved in `b3b8bc7`. No creation record. | `f52db78` (12 Aug 2026); relocated `b3b8bc7` (13 Aug 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Match and navigation icons (10): Club, Fixtures, Home, Inbox, Search, Settings, Squad, Table, Tactics, Transfers | `Assets.xcassets/Icons/Icon*.imageset` | John confirms ChatGPT created this artwork (21 Oct 2026). First committed in `f52db78`. Moved into `Icons/` in `b3b8bc7`. No creation record. | `f52db78` (12 Aug 2026); relocated `b3b8bc7` (13 Aug 2026) | User-confirmed | Creator confirmed. Retain original prompts, sheets or conversation records if available; exact generation details are not established by the import commit. |
| Launch screen | `Retro Season Manager/LaunchScreen.storyboard` | No image references in the storyboard, so it bundles no raster artwork. | `c9c9802` (16 Aug 2026) | No bundled art | None for artwork provenance. |

### Fonts

No font files are bundled. There are no `.ttf`, `.otf`, `.ttc` or `.woff` files, no `UIAppFonts` entry, and no `Font.custom` or `UIFont(name:)` calls. Text uses system fonts. This record does not treat Apple system fonts or SF Symbols (for example `speaker.wave.2.fill` in `AppSettingsView.swift`) as bundled third-party files.

### Audio

No audio files are bundled, and the app has no sound by design — there is no audio code. If audio is ever added, each file needs its own provenance entry and licence record.

## Record status (for release readiness)

All inventoried artwork families now have a recorded ChatGPT origin: explicit Git evidence plus user confirmation for the original three slice sets, and user confirmation for the remaining families. The earlier requests to identify their creator are resolved by John's 21 October 2026 confirmation.

Original prompts, reference sheets, generation dates and any editing/export steps remain supporting records to retain if available. Their absence is recorded here without inventing details or requiring the user to repeat the creator confirmation. The confirmation does not establish whether the experience artwork came from the same three reference sheets. Apple system fonts and SF Symbols are separate from this artwork confirmation.

## Name and likeness review (separate from image provenance)

These are content questions. This record does not resolve them, and no legal clearance is claimed:

- A comment in `GameStore+SquadManagement.swift` describes fictional names mapping to real-world players and cites "Thiago Cerezo" as an ambiguous mapping. This is source commentary, not independent verification of any individual identity.
- The commit `06bf51e` describes "RSM Legends' real-player parody cards". Any parody of named people needs its own review.
- Club and competition names in the code also need a separate trademark and name review.

Image-generation provenance above does not clear any of these questions.
