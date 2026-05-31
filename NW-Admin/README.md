# NW Admin (ESX 1.13.4)

Simpelt admin script til ESX med `lation_ui` menu og `ox_inventory` integration.

## Funktioner
- Viser alle online spillere i en admin menu
- Revive spiller
- Heal spiller
- Draeb spiller
- Teleport til spiller (`goto`)
- Hent spiller til dig (`bring`)
- Freeze / unfreeze spiller
- Åbn spillerens `ox_inventory`

## Krav
- `es_extended` (ESX 1.13.4)
- `lation_ui`
- `ox_inventory` (kun noedvendig for inventory-funktionen)

## Installation
1. Laeg mappen i din resources, fx `resources/[admin]/nw_admin`
2. Tilfoej i `server.cfg` efter dependencies:
   - `ensure lation_ui`
   - `ensure ox_inventory`
   - `ensure nw_admin`

## Brug
- Kommando: `/adminpanel`
- Standard keybind: `F10`

## Permissions
Som standard har disse ESX grupper adgang:
- `superadmin`
- `admin`
- `mod`

Du kan redigere grupper i `config.lua`.

Hvis du vil bruge ACE permissions, saet:
- `Config.RequireAce = true`
- `Config.AcePermission = 'nwadmin.use'`

Og i `server.cfg`:
```cfg
add_ace group.admin nwadmin.use allow
add_principal identifier.license:din_license group.admin
```
