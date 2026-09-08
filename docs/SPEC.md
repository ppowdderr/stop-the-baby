# STOP THE BABY 👶 — Game Specification & Go-To-Market Plan

**Version:** 1.0 · 8 Sep 2026 · Companion docs: `roblox-top15-research.md`, `roblox-hit-ideas-analysis.md`, `roblox-creativity-ideas.md`

---

## 0. One-line pitch
**"Four babysitters. One giant baby. Finish the chores before it cries — because if Mom comes home, you're done."**
Co-op comedy-survival for 1–4 players. Survive 99 nights of babysitting a colossal toddler that wrecks the house, eats anything, and gets *bigger every night*.

Kid-sayable version: *"You babysit a giant baby and if it cries you lose."*

---

## 1. Why this can be a hit (the bet, stated plainly)
| Evidence | Design consequence |
|---|---|
| Survival/co-op is the fastest-growing genre in 2026 (rose in 94% of weekly comparisons; Animal Hospital 884→430K CCU in 3 weeks; 99 Nights 300K+) | Same skeleton: 1–4 player servers, night counter, classes, finite goal (Night 99) |
| Every top-15 game runs on fear or greed; **no mega-game runs on comedy** | Comedy is the open emotional lane; it's also the most shareable high-arousal emotion for kids |
| Chore/cleaning sims spiked (Dig & Clean 271K, Clean all the leaves! 121K, Wash the House) | Chores are the "job"; satisfying feedback on every task |
| Collectible rarity + mutations drive retention & revenue in every top game | Toys/pacifiers/snacks are the collectibles, with rarity + mutations |
| Discovery now rewards D1/D7/D28 retention, co-play, and 94%+ ratings | Friends-only servers, no P2W, parent-safe content |
| Growth comes from creators; hits need a guaranteed clip in the first 5 minutes | Baby physics, ragdolls, absurd escalation are designed clip generators |

Risk we accept: comedy-survival is unproven at mega scale on Roblox. We mitigate by keeping every *system* proven (only the theme is new).

---

## 2. Target audience
- **Core:** 8–13, mixed gender (babysitting fantasy + chaos comedy skews more balanced than horror or shooters).
- **Secondary:** 13–16 friend groups and streamers (chaos co-op is a top streamer format — see Lethal Company, Content Warning, R.E.P.O.).
- **Parents:** must approve. No gore, no jump-scare violence, no weapons. The "threat" is a crying baby and a disappointed Mom.
- Platforms: mobile-first controls (one thumb + tap), also PC/console.

---

## 3. Core fantasy & tone
- **The Baby**: 3–4 m tall at Night 1, grows to house-sized by Night 50, skyscraper-sized by Night 99. Cute face, giant physics. It is never evil — it's a *baby*. Everything it does is what a toddler does, scaled up: eats the fridge, throws the couch, chases the cat, screams if a toy is taken.
- **Mom**: never fully seen at first (headlights in the driveway, keys in the door, a shadow). Later nights reveal more (the "lore drip" that Animal Hospital used to build fan communities).
- **Humor style**: slapstick physics + escalation + deadpan UI ("Baby has eaten the toaster. Toasters remaining: 0"). Family-friendly; no crude/gross-out beyond harmless (baby burps, spit-up puddles you have to mop).
- **Art**: chunky, bright, low-poly with exaggerated squash-and-stretch. Reads clearly on a phone thumbnail.

---

## 4. Core loop

### 4.1 A Night (one round, 6–9 minutes)
1. **Briefing (15 s)** — Mom leaves: "Back at 10. Feed him, bathe him, bed by 9. DO NOT let him cry." Tonight's chore list appears (3–6 chores).
2. **Chores (5–7 min)** — Players split up: cook, mop, laundry, fix what Baby breaks, hide breakables. Baby roams, wrecking things and creating *new* chores. Chores are quick mini-interactions (hold/tap/rhythm), each with a satisfying pop.
3. **Baby management** — Baby has a **Mood meter** (Happy → Grumpy → Fussy → CRYING). Players soothe with toys, snacks, songs, the pacifier, peek-a-boo, carrying (2 players needed to carry at bigger sizes = forced co-op). Baby wants change every 30–60 s.
4. **Bedtime (final 60 s)** — Get Baby to the crib; one player rocks (rhythm mini-game) while others finish chores and hide evidence.
5. **Mom Check (10 s)** — Mom walks in, inspects. Score = chores done, damage hidden, Baby asleep. **If Baby is CRYING when Mom arrives → Night failed.** Otherwise Night N+1 unlocks, rewards roll.

### 4.2 Fail states (funny, not punishing)
- **Baby cries for 20 s continuously** → Mom's car is heard. You have 30 s of "PANIC MODE" (all chores 2x speed, everyone can carry) to calm him before she opens the door. This is *the* clip moment.
- Failure = "Mom's Disappointment" cutscene (30 s, randomized, funny), lose that night's bonus, keep your collection, retry the same night. Loss aversion without rage-quit.

### 4.3 Escalation (why Night 60 feels different from Night 6)
- Baby size, speed, appetite scale. New behaviors unlock: climbs stairs (N5), opens fridge (N10), goes outside (N15), sleepwalks (N25), learns to say "NO" and refuses (N35), invites the neighbor's baby (N50, two babies), teething = chews furniture (N65), first steps → runs (N80), Night 99 = the **Birthday Party** finale.
- House grows too: kitchen → backyard → upstairs → basement → neighbor's house → the whole street.

### 4.4 Finite brag + infinite ladder
- **Night 99** = "Ultimate Babysitter" badge, exclusive golden pacifier aura, name tag. (99 Nights' proven brag.)
- **Rebirth: "New Family"** — after N99 (or optionally after N25/50/75) restart at Night 1 with a new baby skin, +25% permanent Diaper Coin multiplier, a permanent perk slot. Rebirth tiers unlock new houses and Mom voice lines.

---

## 5. Meta systems

### 5.1 Currency
- **Diaper Coins (DC)** — earned per chore, per soothe, per night completion; spent on toys/snacks/gear. Also earned offline at a slow rate by your **Nursery** (see 5.4) for daily-return pull.
- **Stars** — 1–3 per night by performance; unlock classes and houses.
- **Robux** — cosmetics, passes, boosts (see §7).

### 5.2 Collectibles: Toys & Snacks (the RNG layer)
- Toys soothe Baby; higher rarity = longer soothe, funnier animation. Snacks fill hunger; rarer = bigger effect.
- **Rarities:** Common, Uncommon, Rare, Epic, Legendary, Mythic, **Secret** (0.01%, event-only).
- **Mutations** (apply to any toy): Giant, Tiny, Glowing, Squeaky, Rainbow, Golden, Sticky, Haunted (Halloween), Frozen (winter)… Mutations change soothe effect and look.
- **Sources:** Toy Box (crate) bought with DC; night-completion roll (Night N gives N-scaled odds); Baby "gifts" (Baby randomly hands you something it found — variable reward *from the character*); event drops.
- **Display:** your Nursery shows your toys on shelves — public social currency when friends visit.
- **Trading** (v1.2): player-to-player toy trading with a value board — creates the MM2/Adopt Me second game.

### 5.3 Classes (unlock with Stars, level with use)
| Class | Perk | Fantasy |
|---|---|---|
| Nanny | Soothes 2x, can sing lullaby AOE | The responsible one |
| Chef | Cooks 2x, snacks +50% | Feeds the beast |
| Handyman | Repairs 2x, can barricade doors | Damage control |
| Big Sibling | Can carry Baby alone until N30, sprint | The hero |
| Clown (unlock N20) | Peek-a-boo works at range, funniest animations | The clip class |
| Ninja Nanny (event) | Silent movement, Baby doesn't notice | Streamer favorite |

### 5.4 The Nursery (your persistent base)
- Per-player room decorated with toys, trophies, baby photos of each night; upgradable crib, mobile, shelves. Generates a small offline DC trickle ("Baby napped while you were away: +240 DC").
- Friends can visit → **Public** (Berger STEPPS).

### 5.5 Baby Book (progression/collection log)
- Album of "Firsts": first word, first bite of the couch, first escape… Each unlocks a sticker and shows discovery progress (Explorer motivation). Also the *lore* channel: Mom's notes, mysterious photos, hints about **why the baby is so big** → curiosity-gap that creators theorize about (Animal Hospital's community fuel).

### 5.6 Codes & social
- Launch codes (`BIGBABY`, `MOMISHOME`) give a Toy Box.
- Group join → daily "Grandma's Gift".
- Like/Favorite CTA at first Night complete.
- Friends-only server option; server size 4 (max 6 for events).

---

## 6. Content & live-ops roadmap (first 6 months)
| Week | Update (title tag) | Content |
|---|---|---|
| 0 | `[BETA]` Launch | Nights 1–30, 1 house, 4 classes, 40 toys, 20 snacks, 6 mutations, Nursery, codes |
| 1 | `[UPD 1] 🍼 BATHTIME` | Bath chore, 10 toys, bug fixes from feedback (respond publicly & fast — ratings) |
| 2 | `[🎈 X2 COINS]` | First Saturday event; X2 DC weekend; Rare+ odds up |
| 3 | `[UPD 2] 🐱 THE CAT` | Cat NPC Baby chases; new fail chain; Nights 31–45 |
| 4 | `[👶👶 TWINS]` | Weekend event: two babies, event-exclusive Twin Pacifier |
| 5 | `[UPD 3] 🏠 UPSTAIRS` | Upstairs floor, stairs behaviors, Nights 46–60, Clown class |
| 6 | `[🎃]` seasonal | Halloween: Haunted mutation, Baby in costume, Trick-or-Treat chore |
| 8 | `[UPD 4] 🔄 REBIRTH` | New Family rebirth, House 2, Nights 61–80 |
| 10 | `[UPD 5] 🔁 TRADING` | Trading + value board; Mythic tier |
| 12 | `[🎂 NIGHT 99]` | Finale Birthday Party, Ultimate badge, lore reveal pt.1 |
| 14–24 | Bi-weekly | Neighbor's house, Grandma mode (harder), Baby Park (open area), winter event, ranked "Chaos Mode" (score attack), UGC contest for toys |

Cadence rule: **something new every Saturday**, alternating big update / event weekend. Announce in-game 24 h before with a countdown.

---

## 7. Monetization (profit without hurting ratings)
Principle: **sell speed, style, and slots — never the ability to stop the baby crying.** Target 94%+ rating; no purchase is required to reach Night 99.

| Product | Price (R$) | Notes |
|---|---|---|
| Starter Pack (impulse) | 99 | 1 Epic toy, 500 DC, Party Hat cosmetic. Shown after first successful night |
| Babysitter Pass (battle pass, 4 weeks) | 399 | 30 tiers: cosmetics, Toy Boxes, emotes; free track exists |
| x2 Diaper Coins | 249 | Multiplier, permanent |
| Lucky Nanny (+25% rarity luck) | 299 | Luck, permanent; odds shown |
| Extra Nursery Shelf slots | 99 each | Collection capacity — the "sell slots" pattern |
| Baby Skins (cosmetic) | 149–499 | Dinosaur onesie, astronaut, etc. Shown to whole server = social currency |
| Babysitter outfits/emotes | 49–299 | Cosmetic |
| Class early-access | 199 | New class 2 weeks early, then free (JJS pattern) |
| Premium Toy Box (10-pack) | 149 | RNG with displayed odds; no Secret-tier from paid boxes (fairness) |
| Whale ladder | x3 / x5 / x10 coins at 699 / 1,999 / 5,999 | Later; only after ratings stabilise |

Revenue model (order-of-magnitude, not a promise): at 50K avg CCU the comparable 2026 survival/sim titles are estimated by third-party trackers at roughly $1–3M/month gross; Roblox pays ~29% of Robux spent to developers (after platform share and DevEx rate). Break-even for a 3-person, 4-month build is under 5K sustained CCU.

---

## 8. Clip engineering (designed viral moments)
Each is guaranteed to occur in a typical first session:
1. **First growth** — Baby visibly grows on screen at Night 3 with a "BURP" and the house shakes.
2. **PANIC MODE** — headlights sweep the room, music spikes, 30-second countdown, everyone screaming into mics.
3. **Baby eats the player** — you get swallowed, spat out across the map, covered in slobber (harmless, funny ragdoll).
4. **Carry fail** — two players carry Baby up stairs; Baby wiggles; physics chaos.
5. **Baby gift** — Baby hands you a Legendary toy it found; server-wide announcement.
6. **Mom cutscenes** — randomized funny fails ("Why is the fridge in the pool?").
7. **Sleepwalking night** — Baby wanders into the neighbor's house.
- Built-in **"CLIP THIS" button**: saves the last 15 s via Roblox capture API and prompts share (creators love friction-free clips).
- Ragdoll + squash physics on everything; slow-mo on fail.

---

## 9. Marketing & launch plan

### 9.1 Positioning
- **Title:** `STOP THE BABY 👶 [BETA]` (verb + object; tag rotates weekly).
- **Thumbnail A/B set:** (1) 4 tiny babysitters holding back a giant baby's foot; (2) baby eating the fridge with a Mom silhouette in the door; (3) "NIGHT 99?" baby the size of the house. Rotate; keep the winner by CTR *and* D1.
- **Icon:** baby face, huge eyes, one tear forming.
- **Description:** first line = pitch; then how-to in 4 emoji bullets; codes; group link; "Like 👍 & Favorite ⭐ for Twins weekend!"

### 9.2 Pre-launch (weeks –3 to 0)
- Discord + TikTok + YouTube Shorts accounts; post 3 physics clips/week from dev builds ("we made the baby too big").
- Closed test with 30 kids/teens from Discord; fix onboarding until the first-night completion rate >70%.
- Build a **creator kit**: private server codes, a "Chaos Server" with pre-unlocked Night 40 for clips, thumbnail assets, embargo lift on launch day.

### 9.3 Launch (week 0)
- **Seed 15–20 creators** in the 100K–2M subscriber range who play co-op with friends (the Content Warning/Lethal Company style channels on Roblox: KreekCraft-tier is a stretch; target the tier below). Offer: early access + custom code + in-game statue for their name at N99 (social currency for the creator).
- Launch Friday 3 pm ET (Saturday event follows next day).
- Day-1 code `BIGBABY`. First X2 event Saturday 48 h later — creators' second video.
- Reply to every negative review/DevForum/Discord bug within hours; ship hotfix within 24 h (ratings are the algorithm).

### 9.4 Growth loop
- Weekly Saturday event → creators get a weekly "new thing" video → Home recommendations reward returning co-play.
- **UGC hooks:** Toy design contests (winners become in-game toys with creator credit); "Baby skin" fan art → skins.
- **Memeability:** Baby has a recurring catchphrase ("MORE.") and a signature animation → sticker packs, TikTok sound.
- **Lore drip** in Baby Book → theory videos ("Why is the baby giant? Night 99 explained").
- Cross-promo: later portal to a sister game (Prank a Neighbor) once both exist.

### 9.5 KPIs & gates
| Metric | Gate to keep spending |
|---|---|
| First-night completion | >70% |
| D1 retention | >30% (top sims 35–45%) |
| D7 | >12% |
| Avg session | >25 min |
| Rating | >93% |
| Co-play share (servers with ≥2 friends) | >40% |
| Robux/DAU | monitor only for first 4 weeks |

If D1 <25% after two iterations → the loop, not the marketing, is the problem; stop seeding and fix.

---

## 10. Technical plan (Roblox / Luau, Rojo)

### 10.1 Architecture
- `ServerScriptService/`: `RoundService` (night state machine), `BabyAI` (behavior tree: Wander → Target → Interact/Destroy → Mood tick), `ChoreService` (spawns/validates chores), `EconomyService` (DC, Stars, purchases), `InventoryService` (toys, mutations, RNG with server-side odds), `DataService` (ProfileService/DataStore v2 with session locking), `EventService` (weekly flags via `HttpService`/`MessagingService` config), `Analytics` (Roblox Analytics custom events: night_start/complete/fail, panic_triggered, purchase).
- `ReplicatedStorage/Shared/`: `Config` (all tunables), `ToyCatalog`, `Rarity`, `Net` (remotes with rate-limits), `Util`.
- `StarterPlayerScripts/`: `HUD` (Mood meter, chore list, night counter), `InteractionClient` (ProximityPrompt-based one-tap), `CarryClient`, `Cutscenes`, `ShopUI`, `NurseryUI`, `ClipButton`.
- Baby is a server-authoritative humanoid model with scalable rig; behaviors are data-driven per Night from `Config.NightTable`.
- Anti-exploit: all rewards/rolls server-side; remotes validated; DC never client-authored.

### 10.2 Milestones (3 devs: gameplay, art/anim, UI/live-ops)
| Week | Deliverable |
|---|---|
| 1 | Greybox house; Baby wander + destroy; Mood meter; 3 chores; night loop N1–N5 |
| 2 | Soothe interactions, carry (1–2 players), PANIC MODE, Mom check; playtest #1 |
| 3 | Toys/snacks catalog, rarity + mutations, Toy Box, Nursery v1; DataStore |
| 4 | Classes, Stars, Nights 6–30 behavior table, fail cutscenes ×5; playtest #2 |
| 5 | Art pass (baby rig, squash/stretch, house props), SFX/music, HUD polish, mobile controls |
| 6 | Shop, passes, codes, group rewards, analytics, creator kit; closed test with 30 players |
| 7 | Fix D1 blockers, thumbnails A/B, description, Discord; **launch Friday** |
| 8–12 | Weekly updates per §6 |

### 10.3 Balancing numbers (starting values, tune with data)
- Mood decay: 1 stage per 45 s idle at N1 → per 25 s by N30.
- Cry-to-Mom timer: 20 s crying → PANIC 30 s.
- Chores: 3 at N1, +1 every 8 nights, cap 7; each 8–20 s.
- Toy soothe: Common 1 stage / Rare 2 / Legendary 3 + 20 s immunity.
- Rarity odds (Toy Box): 60 / 25 / 10 / 4 / 0.9 / 0.1 (Secret event-only). Night roll adds +0.2% Legendary per Night.
- Night reward: 100 DC × Night^1.1 × stars; offline Nursery 60 DC/h cap 12 h.
- Target: first Legendary within ~45 min average; first rebirth ~6–8 h.

---

## 11. Safety & policy
- Comply with Roblox Community Standards; content fits "Minimal" or "Mild" maturity rating (slapstick only).
- Paid random items: display odds; no Secret tier purchasable (avoids gambling perception).
- Chat: default filtered; no user-generated text on screens.
- Baby/Mom depicted respectfully (no violence toward the baby — you *soothe*, never hit).

---

## 12. Risks & mitigations
| Risk | Mitigation |
|---|---|
| Comedy doesn't retain like fear | Retention systems are all proven (collectibles, rebirth, Saturday events); comedy is only the coat of paint |
| Empty servers early | Solo mode is fully playable (Baby smaller, fewer chores); matchmaking prefers friends |
| Physics jank hurts rating | Ship carry/ragdoll only after 2 playtests; server-authoritative baby |
| Fast-follow clones | Move fast on updates (weekly); build the toy economy + lore the clones can't copy quickly; trademark the name/logo |
| Creator seeding fails | Have 5-second Shorts ready; run Roblox Sponsored ads for 1 week only to bootstrap CCU for algorithm co-play |

---

## 13. Success definition
- **Week 1:** 5K CCU, 93%+ rating, D1 ≥30%.
- **Month 1:** 30–50K CCU, top-100, first creator videos >1M views.
- **Month 3:** 100K+ peak weekend CCU, trading live, Night 99 finale videos trending — the point at which the 2026 breakouts (Animal Hospital, Kick a Lucky Block, Anime Expeditions) reached the top 15.
