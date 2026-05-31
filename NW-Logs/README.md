# NW Logs (ESX 1.13.4 + ox_inventory)

Discord webhook logs for:

- ox_inventory item drop
- ox_inventory give item
- ox_inventory put in stash
- ox_inventory take from stash
- ox_inventory shop receive/buy item
- loot logs (drop/trunk/glovebox/container -> player)
- damage logs
- kill/death logs

All logs include player identifiers when available:

- character name
- `discord:`
- `steam:`
- `license:`
- player coordinates

## Install

1. Put this folder in your resources directory.
2. Set your webhook URLs in `config.lua`.
3. Ensure start order in `server.cfg`:

```cfg
ensure ox_inventory
ensure es_extended
ensure NW-Logs
```

## Config

Edit `config.lua`:

- `Config.Webhooks.inventory`
- `Config.Webhooks.stash`
- `Config.Webhooks.shop`
- `Config.Webhooks.loot`
- `Config.Webhooks.damage`
- `Config.Webhooks.death`

You can enable/disable damage/death logs and throttle values with:

- `Config.Damage`
- `Config.Death`

## Notes

- Resource is made for ESX 1.13.4 environments.
- Player name lookup uses ESX if available, with fallback to server name.
- Damage/death logs are sent from client event `CEventNetworkEntityDamage`.
