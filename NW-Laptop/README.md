# nw_laptop (ESX 1.13.4 + ox stack)

Place a laptop item from `ox_inventory`, interact with it via `ox_target`, then install an app from `simcard` to `tablet` and receive `bande_tablet`.

## Features
- Placeable world laptop from inventory item.
- `ox_target` interactions:
  - Open laptop UI.
  - Pick up laptop.
- UI mode:
  - Tries DUI first (`Config.PreferDui = true`).
  - Falls back to NUI if DUI fails and fallback is enabled.
- Install flow:
  - Requires `simcard` + `tablet`.
  - Consumes both and gives `bande_tablet`.

## Install
1. Put this folder in your resources.
2. Ensure start order includes dependencies before `nw_laptop`.
3. Add item definitions to your `ox_inventory` items file.
4. `ensure nw_laptop`.

Example `server.cfg` order:
```cfg
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure ox_target
ensure nw_laptop
```

## ox_inventory item snippets
Add (or merge) these in your `ox_inventory/data/items.lua`:

```lua
['laptop'] = {
    label = 'Bande Laptop',
    weight = 2500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        event = 'nw_laptop:client:placeLaptop'
    }
},

['simcard'] = {
    label = 'SIM Card',
    weight = 50,
    stack = true,
    close = true
},

['tablet'] = {
    label = 'Tablet',
    weight = 400,
    stack = true,
    close = true
},

['bande_tablet'] = {
    label = 'Bande Tablet',
    weight = 500,
    stack = false,
    close = true
}
```

## Config
Edit `config.lua`:
- Item names
- Distances
- Owner-only pickup
- DUI preference
- `Config.EnableEsxUsableFallback` can force item usability via ESX even if `client.event` is missing on the item definition.

## lation_ui note
This script uses `ox_lib` notify/progress. If your server uses a lation bridge for `ox_lib` UI, notifications/progress will follow that style automatically.

## Notes
- Laptops are runtime objects (not DB persisted by default).
- Ownership is bound to identifier when `Config.AllowAnyoneToPickup = false`.
