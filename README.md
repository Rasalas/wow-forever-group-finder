# Auto Group Finder

A World of Warcraft **Forever** add-on that finds tanks, healers and damage dealers for your group automatically – a bit like the Dungeon Finder in Retail, but built on Blizzard's own group finder.

You pick your role, the dungeons and a play style and click **Find Group**. The add-on lists your group, searches, and invites fitting players on its own: rare roles first, players already standing at the dungeon first, and nobody twice who just declined.

## Features

- **Automatic invites** for exactly the open spots; declines, busy and unreachable players are skipped for a while
- **Rare roles first** – plentiful roles (usually damage) wait until tanks and healers have joined
- **Players at the dungeon first**, based on the zone Blizzard reports for each listing
- **Quick start at the dungeon** – stand in front of it and search for exactly that dungeon with one click
- **Wait-time estimate** from real finished groups (same dungeon, size and missing roles), corrected against its own past errors; optionally shared anonymously with other users
- **Invite info** under Blizzard's invite popup: dungeon, picture, which roles are filled and which spot is yours
- **Players Found** page with role, level, zone and a context menu; click the role icon to target
- **Group history** per character, **backfill** with one click when someone leaves, raid conversion, ready check
- Blizzard look and feel: animated group-finder eye on the minimap, side tabs, a tab inside Blizzard's group finder
- English, Deutsch, Français, Español, Italiano, Português, Русский

## Installation

Copy the `AutoGroupFinder` folder into `World of Warcraft/_forever_/Interface/AddOns/` and restart the game.

## Usage

`/gf` opens the window. The first time, a short guide explains the three steps.

Blizzard only lets add-ons search the group finder right after a click or key press. While a search is running, right-click the minimap eye, press your key binding (Key Bindings > Auto Group Finder) or click into the game world to search again.

| Command | |
|---|---|
| `/gf` | Open or close the window |
| `/gf config` | Options |
| `/gf start`, `/gf stop` | Start or stop the search |
| `/gf whisper <text>` | Whisper text sent with invites (`{dungeon}` and `{role}` are filled in) |
| `/gf minimap [reset]` | Show/hide the minimap icon, or move it back |
| `/gf test` | List the test commands – nothing real happens in them |
| `/gf diag` | Client info and Lua errors the add-on caught |

## Privacy

The add-on has no server of its own and collects no usage data.

- **Stored on your computer only** (WoW SavedVariables): settings, your group history and blocked players (these contain character names), wait times, and for 30 minutes the names seen in the group finder (for the popularity display).
- **Sent to other players** as invisible add-on messages: what you invite someone for (to the invited player), and – unless you turn it off – wait times of finished groups without names, via your guild, your group and the hidden channel `AutoGroupFinderStats`. WoW shows the receiving add-ons which character a message came from; the add-on does not store it.

## Support

Bugs and ideas: [open an issue](https://github.com/Rasalas/wow-forever-group-finder/issues). Please include the output of `/gf diag`.

If the add-on saves you some waiting time and you'd like to say thanks: [buy me a coffee](https://buymeacoffee.com/tbuck91j). (Blizzard's add-on policy doesn't allow donation requests inside the game, so you'll only find this link here.)

## Development

Everything in `AutoGroupFinder/` is plain Lua 5.1 for the WoW client. `tests/` contains simulators with a mocked WoW API that run under LuaJIT.

```sh
cp config.mk.example config.mk   # set your paths once
make test      # syntax check (Lua 5.1) and all simulator tests
make install   # tests, then copy into LOCAL_ADDONS
make deploy    # tests, then copy to a game PC via SSH
make zip       # tests, then dist/AutoGroupFinder-<version>.zip
make pdf       # printable in-game test checklist (German) from docs/checklist.html
```

## License

[MIT](LICENSE)
