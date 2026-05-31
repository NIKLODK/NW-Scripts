# NW Playreward

ESX 1.13.4 activity reward script with small bottom-right UI and ox_inventory support.

## Features
- Configurable milestones (default: 1, 3, 6, 9, 12 hours)
- Rewards from `config.lua`
- Supports `money` and `item` reward types
- Online-time only progression
- Database persistence
- Automatic reset after 24 hours

## Install
1. Place this resource in your resources folder.
2. Import `sql/nw_playreward.sql` (optional because table auto-creates on start).
3. Add `ensure NW-Playreward` to `server.cfg`.
4. Ensure dependencies are started:
   - `es_extended`
   - `oxmysql`
   - `ox_inventory`

## Configure rewards
Edit `config.lua` and change values under:
- `Config.Milestones`
- `Config.Rewards`

Example reward types:
- Money: `{ type = 'money', account = 'money', amount = 5000, label = '$5,000 cash' }`
- Item: `{ type = 'item', name = 'water', count = 2, label = '2x Water' }`
