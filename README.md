# Auto Group Finder

WoW-Forever-Add-on: findet Tanks, Heiler und Schaden für deine Gruppe automatisch – ähnlich dem Dungeon-Finder in Retail.

- `AutoGroupFinder/` – das Add-on (in `_forever_/Interface/AddOns/` kopieren)
- `tests/` – Simulatoren mit nachgebauter WoW-Schnittstelle (`luajit tests/<datei>.lua AutoGroupFinder`)
- `scripts/test.sh` – Syntax (Lua 5.1) und alle Tests
- `scripts/deploy.sh` – Tests, dann Kopie auf den Spielrechner

Im Spiel: `/gf` öffnet das Fenster, `/gf test` spielt einen Ablauf mit erfundenen Spielern durch, `/gf testinvite` zeigt die Einladungs-Info.
