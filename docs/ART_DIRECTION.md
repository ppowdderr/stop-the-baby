# Stop the Baby — Art Direction

The visual job of this game is simple: **make the Baby the funniest, most lovable thing on screen, and make
the house a bright toy box it can wreck.** Everything below serves the goals in `SPEC.md` — kid-readable,
clip-able, mobile-first, no fear, no gore, no P2W.

## 1. Style pillars

| Pillar | What it means in practice |
| --- | --- |
| **Toy box, not doll house** | Chunky proportions, rounded silhouettes, thick trims. If a prop could be a wooden toy, it is right. |
| **Baby is the loudest color** | Saturated yellow onesie + blue booties/pacifier on a pastel house. Nothing else may be that saturated except chore accents. |
| **Red = Mom / PANIC only** | The car, headlights, PANIC UI and the stove knobs are the only reds. Players learn "red means she's coming". |
| **Readable at phone size** | Every station has one accent color, one icon label, one silhouette. Walls are low-contrast so props pop. |
| **Comedy through scale & escalation** | Normal furniture, giant baby. Growth per night must be obvious against the same crib/door. |
| **Never scary, never cruel** | Night lighting is warm and lamp-lit, not horror-dark. The Baby is never hurt; falling props are cartoon tumbles. |

## 2. Palette (`src/shared/Palette.lua`)

- **House shell:** cream siding, red roof, white trim, blue door.
- **Rooms:** Living room = mint, Kitchen = sky blue, (future) Nursery = peach. Each has a lighter stripe
  color for wallpaper.
- **Wood:** three steps (light / mid / dark) — floor planks alternate light/dark for rhythm.
- **Chore accents:** Sleep = lavender, Toys = blue, Clean = pink, Kitchen = green, Utility = amber,
  Yard = lime. The HUD uses the same hues (`UI.Colors`), so "pink chore" on the HUD is the pink rug/laundry.
- **Baby:** `Palette.Baby` yellow. **Mom:** `Palette.Mom` red.

Rule: if a new asset needs a color not in the palette, add it to the palette — don't inline it.

## 3. Baby rules (`src/server/Baby/BabyRig.lua`)

- Chibi proportions: head ~1.3× torso width, stubby limbs, ball hands/feet.
- Signature print: yellow onesie, white polka dots, duck patch on the tummy, one hair curl, blue pacifier,
  blue booties with white straps. Keep these on every skin/cosmetic so the mascot stays recognizable.
- 3D cheeks + chin roll give the silhouette; the face is a SurfaceGui the client animates per mood.
- Cartoon `Highlight` outline (dark brown, occluded) so the Baby reads against any wall.
- Face part names (`EyeL/R`, `Pupil`, `Lid`, `BrowL/R`, `Mouth`, `Cover`, `Tongue`, `TearL/R`, `BlushL/R`),
  body parts (`Torso`, `Head`, `SockL/R`, `Pacifier`, `PacifierNub`) and Motor6D names
  (`RootJoint`, `Neck`, `ShoulderL/R`, `HipL/R`) are a contract with `BabyAnimator.lua`.

## 4. House & prop rules (`src/server/World/Furniture.lua`, `MapBuilder.lua`)

- **One root part per prop/station.** The root is an invisible box with the original greybox size;
  it carries `Station`/`Area` or `Prop`/`HomeCFrame`/`Knocked`. All visual parts are massless, non-collide,
  welded children. Gameplay code only ever touches the root, so any prop can be re-dressed freely.
- Fronts face `-Z` locally; rotate the CFrame so fronts face into the room.
- Stations get a floating icon label (`🛏️ CRIB`) — kids don't read menus, they read pictures.
- Environmental storytelling is allowed and encouraged: crayon drawing on the fridge, "BABY CHANNEL" on the
  TV, "SHHH... BABY" doormat, `MOM 1` license plate, toy blocks on the floor. Keep it G-rated.
- Lighting: warm pendant/lamp lights inside, cool blue night outside, subtle bloom on neon bulbs. PANIC
  turns the ambient red (client-side, `Cutscenes.lua`).

## 5. UI rules

- Rounded panels, `FredokaOne`/`Cartoon` fonts, big thumb-sized buttons (min 48 px on phone).
- One number always visible (Stars / Night). Mood meter uses the Baby's face, not a bar alone.
- Deadpan copy: "Baby has eaten the toaster. Toasters remaining: 0."

## 6. Thumbnail & icon briefs

**Icon (512×512):** Baby face only — huge eyes, one tear forming, pacifier, yellow background. Must read at
64 px.

**Thumbnails (1920×1080), rotate and keep the CTR × D1 winner:**
1. Four tiny babysitters straining against a giant yellow bootie; couch flying; "STOP THE BABY" in chunky
   white with a dark outline.
2. Baby chewing the fridge (door bent), Mom's red headlights through the window, babysitter mid-scream.
3. "NIGHT 99?" — Baby taller than the house, roof on its head like a hat.

Never bait: the thumbnail scene must be something that actually happens in the game.

## 7. Asset pipeline

1. **Now:** everything procedural from parts (this doc). Zero external ids, zero moderation risk, syncs via Rojo.
2. **Beta:** replace hero props (crib, couch, fridge, Mom's car, Baby) with authored meshes — same root part,
   same sizes, mesh as a welded child. Source: our own Blender exports, or Creator Store assets we've
   verified are free-to-use (record the asset id + license in `docs/ASSETS.md`).
3. **Launch:** custom face decals per mood, custom SFX pack, animated thumbnails/trailer.

Keep the greybox root sizes forever — they are the interaction ranges kids have learned.
