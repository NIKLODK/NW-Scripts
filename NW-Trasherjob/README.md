# nw_trashjob

Basis skraldemand job til ESX 1.13.4 med:

- `lation_ui` menu/input/notify/progress/text
- Team-system (opret/join/forlad)
- Team-skraldebil
- Random rute med skraldespande
- Pick-up -> baer pose -> toem bag i bilen
- Aflevering af bil giver `trash_bag` via chance/min/max pr. toemt spand
- Recycle station med random rewards via config chance/min/max

## Krav

- `es_extended` (1.13.4)
- `lation_ui`

## Installation

1. Læg resource i din server mappe som `nw_trashjob`.
2. Kør SQL fra `sql/nw_trashjob.sql` (job + items).
3. Tilpas `config.lua` (coords, rewards, chance, min/max, bin spots osv).
4. Sørg for at dependencies startes foer job resource:

```cfg
ensure es_extended
ensure lation_ui
ensure nw_trashjob
```

## Brug

1. Gå til depot blip (`Skraldemand Depot`).
2. Tryk `E` og brug menuen:
   - Opret team eller join med kode
   - Spawn skraldebil
   - Start rute
3. Kør til skraldespande:
   - Tag pose fra spand
   - Bær posen hen til bagenden af skraldebilen og tøm den
4. Når I er færdige, aflever bilen ved depot for at få `trash_bag`.
5. Kør til recycle blip og genbrug poser for random rewards.

## Konfig

Alt centralt er i `config.lua`:

- Job/navn krav: `Config.Job`
- Team størrelse/kodelængde: `Config.Team`
- Bil model/spawn/return/afstande: `Config.Vehicle`
- Depot/recycle coords: `Config.Depot`, `Config.Recycle`
- Antal spande pr. rute + alle bin coords: `Config.Route`
- Pickup/dump/recycle durations: `Config.Actions`
- Pose prop/bone/offset: `Config.Carry`
- Skraldepose payout chance/min/max: `Config.TrashBagReward`
- Recycle rewards med chance/min/max: `Config.Recycle.Rewards`

## Lunar multijob / jobscreator

Resource bruger aktiv ESX job (`xPlayer.job.name`) som adgangstjek.  
Det betyder den virker med `lunar_multijob`, så længe spillerens aktive job er `Config.Job.Name`.

`lunar_jobscreator` er ikke påkrævet for denne basis version.
