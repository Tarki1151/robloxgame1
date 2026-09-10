# robloxgame1

An empty Rojo project, ready for a new Roblox game.

The toolchain and CI are set up; only the gameplay code is missing.

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

## Previous game

This repo previously held a bird-hunting simulator. It was removed, not lost:

```bash
git checkout f77932d -- src
```
