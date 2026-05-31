# nw-storerobbery (ESX 1.13.4)

Store robbery script built for ESX with:
- `ox_target` interactions
- `lation_ui` skill check for registers
- `bl_ui` minigames for alarm/computer
- Optional `va_polititablet` dispatch call when register/safe is used while alarm is still active

## Features

- Start robbery in 2 ways:
  - Disable alarm at back of store (with spawned alarm prop + `bl_ui` minigame)
  - Skip alarm and lockpick register directly (`lation_ui` skill check)
- Register can give random cash reward and a chance to find safe code
- If code is not found from register, hack office computer (`bl_ui`) to get code
- Open office safe with entered code for final reward
- Full store definitions and coordinates are in `config.lua`
- Per-shop robbery state, cooldown, timeout, and anti-distance checks on server
- Dispatch hook for `va_polititablet` when robbing register/safe without disabling alarm first

## Dependencies

Required:
- `es_extended` (ESX 1.13.4)
- `ox_lib`
- `ox_target`
- `lation_ui`
- `bl_ui`

Optional:
- `va_polititablet` (only for dispatch call)

## Install

1. Place resource folder in your server resources.
2. Ensure dependencies are started before this script.
3. Add `ensure NW-Storerobbery` to `server.cfg` (or rename folder and ensure that name).

## Config

Main config file: `config.lua`

Important sections:
- `Config.Shops`: all shops and coords (`alarm`, `registers`, `computer`, `safe`, `alarm.prop`)
- `Config.Register.codeFindChance`: chance to get safe code from register
- `Config.Register.reward` / `Config.Safe.reward`
- `Config.Register.skillCheck`: `lation_ui` settings
- `Config.Alarm.minigame` / `Config.Computer.minigame`: `bl_ui` game type + params
- `Config.Dispatch.useVaPolitiTabletExport`: use `va_polititablet` export directly
- `Config.Dispatch.tabletResource` / `Config.Dispatch.tabletExport`: export target
- `Config.Dispatch.defaultPhone`: fallback phone number
- `Config.Dispatch.serverEvent`: fallback event if export is disabled/fails
- `Config.BuildDispatchPayload`: payload format for your tablet resource

## va_polititablet note

Default export call is:
- `exports['va_polititablet']:OpretNytOpkaldTilTablet(source, besked, telefon, coords)`

If your tablet setup differs, change:
- `Config.Dispatch.*`
- `Config.BuildDispatchPayload`

## Tested flow

1. Go behind shop and interact with alarm target.
2. Complete `bl_ui` minigame to disable alarm.
3. Lockpick register with `lation_ui`.
4. If no code drops, hack computer via `bl_ui`.
5. Enter code on safe and receive final payout.
