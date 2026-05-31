# JantelovenRP S&Box Website

PHP-side til XAMPP med rene routes, Steam OpenID-login, dark/light mode, regler og staff-rettigheder.

## Kom i gang

1. Åbn `app/config.php`.
2. Sæt `base_path` til mappens URL path, hvis mappen skifter navn.
3. Tilføj din SteamID64 i `owner_steamids`, eller behold `first_login_owner` som `true`, så første login bliver owner.
4. Tilføj `steam_api_key`, hvis Steam-navn og avatar skal hentes automatisk.

## Rettigheder

Roller ligger i `data/roles.json`.

- `*` giver alle rettigheder.
- `rules.manage` kan redigere regler.
- `staff.view` kan se staff-panelet.
- `staff.manage` kan give roller og redigere rettigheder.

## Sikkerhed

PHP-koden sendes ikke til browseren, så folk kan ikke bare se kildekoden via "view source". Mapperne `app` og `data` er også blokeret med `.htaccess`. Det beskytter ikke mod adgang til selve serverens filer, så brug stadig ordentlige filrettigheder og lad aldrig backups, `.zip`-filer eller config-dumps ligge offentligt.
