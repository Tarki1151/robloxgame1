# robloxgame1

An empty Rojo project, ready for a new Roblox game.

The toolchain and CI are set up. The only gameplay code is `GroundService`,
which makes the ground grass. By default it paints the baseplate grass green
and leaves it solid and visible. Set `Config.Ground.UseTerrain = true` for
real terrain grass instead, which renders grass blades and can be sculpted -
that mode hides the baseplate underneath, since two solid surfaces at the
same height flicker against each other.

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

Open a place in Studio, click the **Rojo** button under the **Plugins** tab,
then **Connect**.

Two things that caused real confusion before:

- **Connect only copies files in. It does not run anything.** Press **Play**
  to see anything a server script creates.
- **Reconnect after a break.** If the Rojo plugin disconnects, Studio keeps
  running whatever it last received, so you can be testing old code without
  knowing it. When output does not match the code, check the connection first.

Or build a place file without Studio:

```bash
rojo build default.project.json --output game.rbxlx
```

## Layout

```
src/
  shared/   -> ReplicatedStorage.Shared          (both sides)
  server/   -> ServerScriptService.Server        (Script + modules)
  client/   -> StarterPlayerScripts.Client       (LocalScript + modules)
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

## Previous work

This repo previously held a beast-fighting game: an NPC built from scratch as
an R6 rig, a twenty-beast roster, and a crafting forge. It was removed, not
lost:

```bash
git checkout 255ccb0 -- src
```

Before that it was a bird-hunting simulator, at `f77932d`.
