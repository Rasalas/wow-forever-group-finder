# Auto Group Finder

WoW-Forever-Add-on: findet Tanks, Heiler und Schaden für deine Gruppe automatisch – ähnlich dem Dungeon-Finder in Retail.

- `AutoGroupFinder/` – das Add-on
- `tests/` – Simulatoren mit nachgebauter WoW-Schnittstelle (`luajit tests/<datei>.lua AutoGroupFinder`)
- `docs/checklist.html` – Testliste fürs Spiel, `make pdf` macht daraus ein PDF zum Ausdrucken

## Befehle

Einmalig `cp config.mk.example config.mk` und die Pfade anpassen.

| Befehl | Was passiert |
|---|---|
| `make test` | Syntax (Lua 5.1 wie WoW) und alle Tests |
| `make deploy` | Tests, dann per SSH auf den Spielrechner (`REMOTE_HOST`, `REMOTE_ADDONS`) |
| `make install` | Tests, dann in den lokalen AddOns-Ordner (`LOCAL_ADDONS`) |
| `make zip` | Tests, dann `dist/AutoGroupFinder-<Version>.zip` für CurseForge |
| `make pdf` | `dist/checklist.pdf` aus `docs/checklist.html` |

Neue Dateien in der `.toc` brauchen einen Neustart von WoW, sonst reicht `/reload`.

## Im Spiel

`/gf` öffnet das Fenster, `/gf test` spielt einen Ablauf mit erfundenen Spielern durch, `/gf testinvite [simple|listing]` zeigt die Einladungs-Info, `/gf diag` prüft die Schnittstellen.

## Sprachen

`Locales/` enthält enUS, deDE, frFR, esES (auch esMX), itIT, ptBR und ruRU – alle europäischen Sprachen, die es als WoW-Client gibt. Fehlende Texte fallen auf Englisch zurück. `tests/locales.lua` prüft, dass jede Übersetzung dieselben Platzhalter wie Englisch hat.
