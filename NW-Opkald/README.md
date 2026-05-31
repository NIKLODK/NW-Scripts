# NW-Opkald

Automatisk politi-opkald ved skud affyret af spillere, der **ikke** er allowlistet i `config.lua`.

## Funktion
- Klienten registrerer skud med `IsPedShooting`.
- Serveren tjekker spillerens job mod `Config.AllowlistedJobs`.
- Hvis jobbet ikke er allowlistet, oprettes et opkald via:
  - `exports["va_polititablet"]:OpretNytOpkaldTilTablet(source, besked, telefon, coords)`
- Beskeden sendes som: `Skud affyrt (ZONE)`.

## Installation
1. Laeg resource-mappen i din `resources` mappe.
2. Soerg for at `va_polititablet` er startet.
3. Tilfoej i `server.cfg`:
   - `ensure nw-opkald`

## Konfiguration (`config.lua`)
- `Config.Framework`:
  - `"auto"` (anbefalet), `"qb"`, `"esx"` eller `"none"`
- `Config.AllowlistedJobs`:
  - Jobs som **ikke** skal trigge opkald.
- `Config.CallCooldownSeconds`:
  - Cooldown per spiller paa server-side.
- `Config.ClientShotDebounceMs`:
  - Debounce paa client-side.
- `Config.CallPrefix`:
  - Tekst i opkaldet (fx `"Skud affyrt"`).
