# Publishing checklist

Everything the code needs from Creator Hub, and where each value goes. Nothing below is
required to run the game in Studio — unpublished builds fall back automatically (no DataStore
persistence, Robux shop hidden, group gift hidden).

## 1. Create the experience (owner does this once)

1. Roblox Studio → **File → Publish to Roblox As…** → *Create new experience*.
   Name: `STOP THE BABY 👶 [BETA]`. Keep it **Private** until the checklist is done.
2. **Game Settings → Basic Info**: genre *Comedy*, playable devices *Computer, Phone, Tablet*
   (the HUD is touch-aware: hold button + tap hotbar). Console is untested — leave off for now.
3. **Game Settings → Places → Start place**: **Max players 4**, server fill *Roblox optimized*.
   `Config.MaxPlayers = 4` is the design assumption (carry needs 2 players from Night 30).
4. **Game Settings → Security**: enable **Studio Access to API Services** — this is what turns
   on DataStores in Studio playtests (otherwise `[DataService] DataStore unavailable` is logged
   and profiles live in memory for the session).
5. **Chat**: `TextChatService.ChatVersion = TextChatService` is set by `default.project.json`, so
   every `rojo build` carries it (the legacy chat throws `ChatScript:116 … CoreGuiChatConnections`
   errors in Studio multi-client tests). Rojo live-sync may fail to apply it to an already-open
   place; rebuild instead.
6. **Game Settings → Avatar**: leave defaults (R15 works with the carry pose).

## 1b. Pushing builds without Studio (Open Cloud)

Collaborator/Team Create access requires a Roblox age check per account, so CI-style publishing
uses an Open Cloud API key instead. Owner: Creator Hub → **Open Cloud → API Keys → Create**, add
API system **universe-places** with scope `universe-places:write`, select the experience, allow
the publisher's IP (or `0.0.0.0/0`), save. Never commit the key.

```sh
rojo build default.project.json -o StopTheBaby.rbxl
curl -X POST "https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=Published" \
  -H "x-api-key: $ROBLOX_OPEN_CLOUD_KEY" -H "Content-Type: application/octet-stream" \
  --data-binary @StopTheBaby.rbxl
# → {"versionNumber": N}
```

- `UNIVERSE_ID` from `https://apis.roblox.com/universes/v1/places/$PLACE_ID/universe`; `PLACE_ID`
  is the number in the experience URL.
- `409 Conflict / "Server is busy"` means the place is open in Studio (Team Create lock) — close it
  and retry. Use `versionType=Saved` to upload without publishing.
- Max players, API access, devices and monetization are **not** in the place file; the owner sets
  them in Creator Hub (steps 2–4 above).
- Current beta target: place `99265860152296`, universe `10765878520`.

## 2. Monetization ids → `src/shared/Config.lua`

Create these in Creator Hub → your experience → **Monetization**, then paste the ids. Prices are the
launch prices from the spec; the code only reads the ids.

| Config key                      | Type              | Creator Hub item          | Suggested price |
| ------------------------------- | ----------------- | ------------------------- | --------------- |
| `Config.Products.StarterPack`   | developer product | Starter Pack              | R$99            |
| `Config.Products.ToyBox10`      | developer product | 10 Toy Boxes              | R$149           |
| `Config.Products.NurseryShelf`  | developer product | +3 Nursery shelf slots    | R$99            |
| `Config.Products.X2Coins`       | game pass         | x2 Diaper Coins           | R$249           |
| `Config.Products.LuckyNanny`    | game pass         | Lucky Nanny               | R$299           |

- Leave an id at `0` to keep that item hidden in the shop (`Inventory.lua` hides unconfigured
  buttons; `EconomyService.registerProducts` only registers handlers for non-zero ids).
- `Config.productsConfigured()` returns true once any real id exists.
- Products are granted in `EconomyService.productHandlers`; passes are read through
  `MarketplaceService:UserOwnsGamePassAsync` in `refreshPasses` at profile load.

## 3. Group + codes

- `Config.GroupId`: your group id → enables **Grandma's Gift** (+200 coins / 20 h for members) and
  the "join our group" line on the Like/Favorite card after Night 1.
- `Config.Codes`: launch codes. Add/rotate freely; redeemed codes are stored per profile.
  Ship day-one codes in the experience description (`BIGBABY`, `MOMISHOME`).

## 4. Assets still on placeholders

- **Sounds** (`src/shared/Sounds.lua`): ids are free Creator Store audio picked in Studio; audit them
  once under the publishing account (privately-owned audio silently fails to load for other
  players). Replace any that log `Failed to load sound`.
- **Baby face** is procedural (SurfaceGui), no decal ids needed. **Icon / thumbnails** are not in
  the repo — needed before going public (512×512 icon, 1920×1080 thumbnails; show the giant Baby
  and one panicking babysitter, no text bait).

## 5. Private test → public

1. Publish (private) → invite 2–3 testers → play Nights 1–5 end to end on PC **and** phone.
2. Watch **Creator Hub → Analytics → Engagement** for D1 and session length; the first-night flow
   is tuned so a new player gets a guaranteed Rare toy within ~6 minutes
   (`Config.Onboarding.FirstPullMinRarity`).
3. Description: one-line pitch, controls, codes, "Like 👍 + Favorite ⭐ so friends can find it",
   group link. No reward for likes (against Roblox rules); the group gift is the incentive.
4. Flip to **Public**, then follow the launch plan in `docs/SPEC.md` (creator seeding, weekly
   `[UPD]` title tags, Saturday events).

## Studio-only behaviour to remember

- No API access ⇒ every session is a fresh profile (rattle + cracker, Night 1). Good for testing
  onboarding, bad for testing persistence — enable API access for that.
- `Config.Onboarding.CoachEnabled = false` turns the first-session coach off if it gets in the way
  during testing.
