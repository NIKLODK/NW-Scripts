# nw-jobscreator

Job/rang skaber + boss-menu manager til FiveM (ESX DB sync).

## Krav

- `ox_lib`
- `oxmysql`
- (valgfrit) `ox_target` til target-baserede boss-menuer
- (valgfrit) `lation_ui` til TextUI/menu (fallback til `ox_lib`)
- (valgfrit) `esx_addonaccount` (og typisk `esx_society`) til firmapenge i boss-menu

## Installation

1. Læg resource i din `resources` mappe.
2. Importér `sql/nw_jobscreator.sql` i din database.
3. `server.cfg`:
   - `ensure ox_lib`
   - `ensure oxmysql`
   - `ensure nw-jobscreator`

## Rettigheder

Du kan give adgang via ACE, Discord allowlist eller ESX gruppe (admin).

ACE eksempel:

```
add_ace group.admin jobscreator.admin allow
```

Discord/ESX gruppe:
- Konfigurer `Config.Admin.discordIds` / `Config.Admin.esxGroups` i `shared/config.lua`.

## Brug

- `/jobscreator` (admins): administrer jobs + rang.
- I menuen: `Boss-menuer` kan oprette/slette boss-menu lokationer.

Boss-menu:
- Tekst boss-menu viser en prompt og åbner med `E`.
- Target boss-menu kræver `ox_target`.
- Firma penge + ansatte kræver at du er tæt på boss-menuen og har den rigtige rang (se permissions nedenfor).

## Config

Redigér `shared/config.lua`.
Hvis din `users` tabel bruger andre kolonnenavne, så ret `Config.UsersTable`.

## Noter

- Hvis du bruger `lation_ui` (Lation Scripts Modern UI), så sørg for `ensure lation_ui` ligger før `ox_lib`.
- UI kan vælges pr. boss-menu (`ox_lib` eller `lation_ui`) når du opretter den.
- Boss-menu permissions:
  - `min_grade` = kan åbne boss-menu
  - `money_min_grade` = kan indsætte/hæve firmapenge
  - `employees_min_grade` = kan ansætte/fyre/skifte rang + ændre løn pr. rang

## Coords (ex-3dcoord)

Når du opretter en boss-menu, starter en `ex-3dcoord`-style pointer picker:
- Peg med kameraet
- Tryk `E` for at placere boss-menu
- Tryk `Backspace` for at annullere

Den kopierer også `vec3(x, y, z)` til dit clipboard.
