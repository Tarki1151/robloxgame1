# robloxgame1

Fight a burning noob.

You spawn as your normal Roblox avatar with 100 HP and a classic sword. An
NPC - a pitch black classic noob, on fire, with six fire wings and a flaming
sword - hunts you down with 200 HP.

| | Health | Attack | Rate |
| --- | --- | --- | --- |
| You | 100 | Sword, 20 damage | every 0.6s |
| Burning Noob | 200 | Melee, 10 damage | every 5s |
| | | Flame projectile, 15 damage | every 15s |

The flame is aimed where you stood when it launched, so it can be dodged by
moving. Kill the noob and a new one spawns after 6 seconds.

Your health bar sits at the bottom left; the noob's is over its head.

## Setup

Tools are pinned with [Rokit](https://github.com/rojo-rbx/rokit):

```bash
rokit install
rojo plugin install
```

## Live sync with Studio

```bash
rojo serve
```

Open an empty Baseplate in Studio, click the **Rojo** button under the
**Plugins** tab, then **Connect**. Every file change now lands in Studio
instantly.

Server-created objects only exist while the game is *running* — press
**Play**, not just **Connect**, or the place will look empty.

Or build a place file without Studio:

```bash
rojo build default.project.json --output game.rbxlx
```

## Rig type does not matter

The NPC is built part by part in `NpcRig` as a proper R6 rig, so it is always
R6 no matter what Game Settings say. Your own avatar can be R6 or R15; nothing
touches it.

## About the animation

There is no uploaded animation pack. Roblox animations are assets: you build
them in the Animation Editor, publish them to your account, and play the
resulting IDs. Nothing in a repo can produce those IDs.

Instead `PoseService` writes the NPC's `Motor6D` joints directly every frame,
which needs no uploads and can be tuned by editing numbers in `Config.Pose`:

- **Idle** - floating upright, arms and legs drifting
- **Chase** - walking at you: leans forward, legs trail
- **Swing** - melee or special windup, overrides the sword arm

Players are untouched and keep their normal Roblox animations. If you record
real animations later, keep `NpcService` and replace `PoseService` with
`Animator:LoadAnimation` calls.

The NPC does not fly - it hovers above the ground and walks.

## Tuning

Everything visual lives in `src/shared/Config.luau`; edit and it syncs live:

| Setting | Effect |
| --- | --- |
| `Wings.Pairs` | number of wing pairs (3 pairs = 6 wings) |
| `Wings.FlapSpeed` / `FlapAmount` | flap rate and swing |
| `Fire.TorsoRate` / `LimbRate` | flame density |
| `Pose.HoverHeight` / `BobAmount` | float height and bob |
| `Npc.MaxHealth` / `Damage` / `AttackCooldown` | how hard the noob hits |
| `Special.Interval` / `Damage` / `Speed` | the flame attack |
| `Sword.Damage` / `Cooldown` | your sword |

## Layout

```
src/
  shared/
    Config.luau        every tunable value: health, damage, fire, wings, poses
  server/
    init.server.luau   starts services in order
    NpcRig             builds a classic R6 character part by part
    NpcService         spawns the noob, runs its AI and its attacks
    PoseService        the animation set: hover, idle, chase, swing
    SwordService       hands out the classic sword and resolves its hits
  client/
    init.client.luau   starts controllers
    HealthController   your health bar
```

## Commands

```bash
rojo serve                    # live sync with Studio
rojo build -o game.rbxlx      # build a place file
stylua src                    # format
selene src                    # lint (first: selene generate-roblox-std)
wally install                 # install dependencies
```

`.github/workflows/ci.yml` runs lint, format check and build on every push.

## Previous game

This repo previously held a bird-hunting simulator. It was removed, not lost:

```bash
git checkout f77932d -- src
```
