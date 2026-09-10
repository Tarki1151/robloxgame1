# robloxgame1

Fight a beast.

You spawn as your normal Roblox avatar with 100 HP and a classic sword. Press
**FIGHT BEAST** and pick one of twenty from the roster - they scale from
Ashburn at 200 HP up to Ashsovereign at 15,000.

Each beast is a pitch black classic noob, burning, with six feathered angel
wings and a flaming sword.

Killing a beast earns **embers**. Spend them in the **FORGE** to craft better
weapons.

| | Health | Attack |
| --- | --- | --- |
| You | 100 | Your equipped weapon, every 0.6s |
| Ashburn (1) | 200 | Melee 10 every 5s, flame 15 every 15s |
| Ashsovereign (20) | 15,000 | Melee 224 every 2s, flame 354 every 5s |

The flame is aimed where you stood when it launched, so it can be dodged.
Kill a beast and the same one returns after 6 seconds, unless you have picked
another from the menu.

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

## The roster

`Config.Beasts` is twenty rows. Every beast shares one body and one behaviour,
so a beast is a row of numbers rather than a model: name, health, damage,
special damage and interval, attack cooldown, walk speed, size, and three
colours. Change a row and that beast changes.

Adding a twenty-first is one more `beast(...)` line; the menu builds itself
from the list.

## Weapons

`Config.Weapons` is a list of rows, same idea as the beasts:

```lua
weapon("Ember Blade", 55, 220, 5.4, Color3.fromRGB(255, 128, 48), Color3.fromRGB(48, 30, 24), true)
--      name          dmg cost reach blade colour              grip colour            glow
```

Add a row and it appears in the forge on its own. Cost `0` means you own it
from the start. `glow` makes the blade neon and gives it a matching trail and
light.

Embers come from kills: `Config.Craft.RewardPerKill` plus the beast's health
times `RewardHealthScale`, so later beasts pay better.

Progress is **in memory only** - there is no DataStore in this place, so
embers and crafted weapons last for the session and reset when you rejoin.

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
| `Sword.Cooldown` / `HitWindow` | swing rate and how long a swing can hit |
| `Craft.RewardPerKill` | embers per beast |
| `Vfx.*` | trails, sparks, sounds, knockback, camera shake |
| `Wings.FeathersPerRow` / `Rows` | feather count - the first thing to cut if it slows down |

## Layout

```
src/
  shared/
    Config.luau        every tunable value: health, damage, fire, wings, poses
  server/
    init.server.luau   starts services in order
    NpcRig             builds a classic R6 character part by part, at any size
    AngelWings         feathered wings: rows of tapered feathers on two bones
    NpcService         spawns the beast, runs its AI and its attacks
    CraftService       embers, weapon ownership, crafting rules
    WeaponFactory      builds a weapon Tool from a Config.Weapons row
    PoseService        the animation set: hover, idle, chase, swing
    SwordService       hands out the classic sword and resolves its hits
  client/
    init.client.luau   starts controllers
    HealthController   your health bar
    BeastMenuController the FIGHT BEAST button and the roster grid
    ShopController     the CRAFT button, the forge panel, the ember counter
    ImpactController   camera shake and damage flash
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
