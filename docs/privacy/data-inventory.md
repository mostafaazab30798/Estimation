# Estimation privacy and Data Safety inventory

**Owner:** Hope TV  
**Android package:** `com.mostafaazab.estimation`  
**Last engineering review:** 2026-08-31  
**Public policy:** `https://legal.hope-tv.site/privacy/`  
**External deletion route:** `https://legal.hope-tv.site/account-deletion/`

This is the engineering source for the Google Play Data Safety form and privacy policy. The Play Console owner must confirm the live Supabase configuration, every production SDK, retention behavior, and any processing added after this review.

## Data map

| Data category | Concrete data | Source | Storage / processing | Purpose | Visible to | Deletion path |
|---|---|---|---|---|---|---|
| Personal info | Email address | Google / Supabase Auth | Supabase Auth and `profiles.email` | Authentication, account recovery/support | Service operators; currently affected by over-broad profile-read policy until RLS is fixed | Delete Supabase auth user; profile cascades |
| Identifiers | Supabase user UUID | Supabase Auth | Auth, profiles, rooms, history | Join account-linked records and authorize access | Service operators; participants may receive identifiers in game state | Delete auth user; dependent rows should cascade |
| Personal info / UGC | Display name | Google profile or player input | Profile, local preferences, multiplayer state | Identify the player in games/leaderboards | Other players | Delete profile/local data; constrain or moderate UGC |
| Photos / UGC | Google avatar, selected photo, or preset avatar | Google or device gallery | Profile/local preferences and multiplayer state | Player avatar | Other players | Delete profile/local data; remove any future storage object |
| App activity | XP, level, games played/won | Gameplay | `profiles` | Progression and leaderboard | Player and leaderboard participants | Delete profile via account deletion |
| App activity | Match history and game data | Gameplay | `game_history` | History and statistics | Intended owner; RLS must be corrected before release | Delete account or individual history records |
| App activity | Room membership, state, actions, scores | Gameplay | `game_rooms`, `room_players`, Supabase Realtime | Online multiplayer/reconnect | Room participants; current policies require security remediation | Delete/cascade account-linked records; expire rooms |
| Device/app data | Sound, haptic, visual and profile preferences | User/device | SharedPreferences on device | Remember settings | Device user | Clear app data/uninstall/account cleanup where applicable |
| Device or other identifiers | Local IP, port, discovery/network status | Device/local network | Processed for LAN discovery and connection | Local multiplayer | Devices on the chosen LAN | Stop session/clear temporary state |
| Photos | Gallery image chosen by player | Device gallery | Resized profile representation | Optional custom avatar | Other players once selected | Replace avatar or delete account/local data |
| Diagnostics | Debug logs in development | Application | Local/debug output | Development troubleshooting | Developers | Do not ship PII logs; define retention before adding a crash SDK |

## SDK and service inventory

| SDK/service | Function | Data considerations | Play form action |
|---|---|---|---|
| Supabase Auth/Database/Realtime | Auth, profiles, rooms, history, realtime | Account identifiers, email, profile/game data, IP/transport metadata | Declare relevant collected data and service-provider processing |
| Google Sign-In | Optional account login | Google identity token, email/profile attributes selected by provider consent | Declare account/auth data and link Google privacy information |
| `shared_preferences` | Local preferences | Stores local settings/profile values | Usually on-device only; confirm backup exclusion behavior |
| `image_picker` | User-selected profile image | Access only after user action | Declare photos if uploaded/transmitted; explain optionality |
| `device_info_plus` | Performance/device classification | Device attributes processed to tune effects | Confirm fields used and whether any leave the device |
| `network_info_plus` / `nsd` | LAN discovery | Local network data | Confirm whether data remains ephemeral/on-device |
| `google_fonts` | Typography | Runtime font fetching can disclose IP/user agent to font hosts | Bundle fonts before release or disclose network behavior |
| `share_plus` / `url_launcher` | User-directed sharing and links | Sends only content the player explicitly shares/opens | Confirm no background collection |
| `audioplayers`, UI/animation libraries | Game presentation | No intended personal-data collection | Verify transitive SDK manifests before release |

## Current answers requiring owner confirmation

- **Sale of data:** No sale is implemented or intended.
- **Targeted advertising:** No advertising SDK was found.
- **Encryption in transit:** Supabase cloud traffic uses HTTPS/WSS. LAN `ws://` traffic is not encrypted and must be addressed or accurately scoped.
- **Optionality:** Google account linking and custom gallery avatar are intended to be optional; online/cloud features require authentication as implemented.
- **Retention:** Active profile/history data persists until deletion. Exact room-expiration, operational-log, and backup expiration must be documented from live infrastructure.
- **Deletion:** Public web request route exists in source. The mailbox, operator workflow, backend deletion, and cascade verification must be operational before marking this complete.
- **Sharing:** Display name/avatar/game-visible state are shown to other players. Service providers process data on Hope TV's behalf. Confirm Play's current definitions when completing the form.
- **Children:** Product/target-audience owner must decide the intended age groups and align the policy, content rating, UGC controls, and Play declarations.

## Release blockers connected to this inventory

1. Fix profile, history, room, hand, and game-state RLS before claiming data is restricted to intended recipients.
2. Implement and test authenticated account deletion. Deleting the Supabase auth user should cascade to profiles, history, hosted rooms, memberships, votes, and future avatar objects; prove each table/object is gone.
3. Activate and monitor `privacy@hope-tv.site`, define request verification, operator access, completion SLA, and audit logging without retaining unnecessary personal data.
4. Decide whether custom names/photos remain. If so, implement UGC terms, validation, reporting, blocking, and moderation.
5. Bundle fonts or account for runtime font requests.
6. Re-run this inventory whenever a crash, analytics, ads, payment, messaging, or moderation SDK is added.

## Deletion verification checklist

- [ ] Request originates from an authenticated in-app flow or the verified account email.
- [ ] Supabase auth user no longer exists.
- [ ] `profiles` row no longer exists.
- [ ] `game_history` rows no longer exist.
- [ ] `room_players` and matchmaking vote rows no longer exist.
- [ ] Hosted `game_rooms` and dependent rows are removed or reassigned under a documented rule.
- [ ] Avatar objects are removed if object storage is introduced.
- [ ] Local session/profile data is cleared after in-app deletion.
- [ ] Completion confirmation is sent without exposing sensitive information.
- [ ] Retained exceptions and backup expiration follow the published policy.
