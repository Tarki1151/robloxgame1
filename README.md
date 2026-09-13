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

Removed, not lost. To bring any of it back:

```bash
git checkout 660f5ec -- src   # castle, cave, sword, sprint, tutorial, save slots
git checkout 255ccb0 -- src   # beast roster, angel wings, crafting forge
git checkout f77932d -- src   # bird-hunting simulator
```
