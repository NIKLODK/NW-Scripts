# NW Boatdealer

Simpel baadforhandler til ESX 1.13.4 med:

- `ox_target` ped interaction
- `lation_ui` menu
- betaling med kontant eller bank (kort)
- leje-funktion med tidsbegraenset lejebaad
- map blip ved forhandleren
- gemmer baaden i `owned_vehicles` til brug med `jg-advancedgarages`

## Dependencies

- `es_extended` (1.13.4)
- `ox_target`
- `ox_lib`
- `oxmysql`
- `lation_ui`
- `jg-advancedgarages`

## Installation

1. Laeg mappen i dine resources.
2. Saet garage-id i `config.lua`:
   - `Config.PurchasedBoatGarage = 'Boats'`
   - Vaerdien skal matche et garage-id i dit `jg-advancedgarages` setup.
3. Tilfoej i `server.cfg` (start order):

```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_target
ensure lation_ui
ensure jg-advancedgarages
ensure nw-boatdealer
```

## Ped placering

Ped er sat til:

- `-797.7985, -1512.0773, 1.5952, 293.5880`

## Tilpas baade

Rediger `Config.Boats` i `config.lua` for modeller og priser.

## Leje og blip

- `Config.Rental.enabled` aktiverer/deaktiverer leje.
- `Config.Rental.pricePercent` saetter lejepris i procent af koebspris.
- `Config.Rental.minimumPrice` er minimum lejepris.
- `Config.Rental.durationMinutes` er lejevarighed i minutter.
- `Config.Rental.spawn` er spawnpunkt for lejebaaden.
- `Config.Blip.enabled` aktiverer/deaktiverer forhandler-blip.
