# STOP THE BABY 👶

Co-op comedy-survival Roblox game (1–4 players). Four babysitters, one giant baby. Finish the chores before it cries — because if Mom comes home, you're done.

Full design & go-to-market spec: [docs/SPEC.md](docs/SPEC.md).

## Stack

- Luau, synced with [Rojo](https://rojo.space) (`default.project.json`)
- Tooling via [Aftman](https://github.com/LPGhatguy/aftman): `rojo`, `selene`, `stylua`
- All UI and the greybox map are built in code, so the place is playable straight after sync (no `.rbxm` assets required).

## Run it

```sh
aftman install
rojo serve          # then connect from the Rojo plugin in Roblox Studio
```

In Studio: **Test → Clients and Servers → 2–4 players** for the co-op loop. DataStores need "Enable Studio Access to API Services" (Game Settings → Security) or the game falls back to an in-memory profile.

Lint / format:

```sh
selene src
stylua --check src
```

## Layout

```
src/shared/       Config (all tuning numbers), NightTable (escalation), ToyCatalog, Rarity, ChoreCatalog, Net, Signal
src/server/
  init.server.lua           bootstrap
  Services/RoundService     Lobby → Briefing → Night → (Panic) → MomCheck → Results state machine
  Services/ChoreService     chore picking, hold-to-complete, baby "undoes" chores
  Services/InventoryService Toy Box RNG (server-side), mutations, sell/favorite, nursery slots
  Services/EconomyService   coins/stars, codes, group gift, offline income, rebirth, Robux receipts
  Services/DataService      DataStore with session locking, autosave, BindToClose
  Baby/BabyAI               mood decay, behaviors (wander/destroy/wants/fridge/swallow/escape/sleepwalk/refuse/gift), carry, soothe
  Baby/BabyRig              procedural blocky baby that scales per night
  World/MapBuilder          greybox house, stations, knockable props, waypoints, Mom's car
src/client/
  HUD          night/timer, mood meter, chore list, toasts, lobby, results, panic overlay
  Inventory    hotbar (1–8 / tap), toy chest, shop, codes, rebirth
  Interaction  hold E / mobile button near stations (chores) or Baby (carry)
  Cutscenes    Mom leaves / check / fail, birthday finale, panic headlights + shake, "CLIP THAT!" flash
```

## Before publishing

See [docs/PUBLISHING.md](docs/PUBLISHING.md) — Game Settings (max players 4, API access), where each
Creator Hub id goes in `src/shared/Config.lua`, group/codes, asset audit, and the private → public flow.
Unpublished builds run fine with everything left at `0`.
