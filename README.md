# robloxgame1

Every player spawns as the same figure: a pitch black classic noob, on fire,
with six fire wings and a flaming sword, floating above the ground.

The look is forced server-side - accessories, clothing and the face from the
player's own Roblox avatar are stripped on every spawn.

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

## Requires R6

The pose set drives R6 joints (`Right Shoulder`, `Left Hip`, `RootJoint`).
In Studio: **File > Game Settings > Avatar > Rig Type > R6**.

On an R15 rig the character still spawns black, burning and winged, but
`PoseService` prints a warning and skips posing rather than moving half a body.

## About the animation

There is no uploaded animation pack. Roblox animations are assets: you build
them in the Animation Editor, publish them to your account, and play the
resulting IDs. Nothing in a repo can produce those IDs.

Instead `PoseService` writes the `Motor6D` joints directly every frame, which
needs no uploads and can be tuned by editing numbers in `Config.Pose`:

- **Idle** - floating upright, arms and legs drifting
- **Flight** - airborne: pitches forward, legs trail
- **Slash** - sword swing, overrides the right arm for `Config.Sword.SwingDuration`

The stock `Animate` script is disabled on spawn so it cannot fight these poses.
If you record real animations later, keep `AvatarService` and replace
`PoseService` with `Animator:LoadAnimation` calls.

The character does not truly fly - it hovers and takes a flight pose while
airborne. Jump height and gravity are untouched.

## Tuning

Everything visual lives in `src/shared/Config.luau`; edit and it syncs live:

| Setting | Effect |
| --- | --- |
| `Wings.Pairs` | number of wing pairs (3 pairs = 6 wings) |
| `Wings.FlapSpeed` / `FlapAmount` | flap rate and swing |
| `Fire.TorsoRate` / `LimbRate` | flame density |
| `Pose.HoverHeight` / `BobAmount` | float height and bob |
| `Sword.BladeLength` | sword size |

## Layout

```
src/
  shared/
    Config.luau        every tunable value: colors, fire, wings, sword, poses
  server/
    init.server.luau   starts services in order
    AvatarService      how the character looks: black body, fire, wings, sword
    PoseService        the animation pack: hover, idle, flight, slash
  client/
    init.client.luau   empty; no client logic needed yet
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
