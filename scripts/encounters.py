#!/usr/bin/env python3
"""Bosse je Dungeon aus der DungeonEncounter-Tabelle des Forever-Builds (wago.tools) -> AutoGroupFinder/Encounters.lua.
Aufruf: scripts/encounters.py [build]   (ohne build: neuester wowf-Build)"""
import csv, io, json, sys, urllib.request

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "AutoGroupFinder-build"})
    return urllib.request.urlopen(req, timeout=60).read().decode("utf-8")

build = sys.argv[1] if len(sys.argv) > 1 else json.loads(get("https://wago.tools/api/builds"))["wowf"][0]["version"]
rows = csv.DictReader(io.StringIO(get(f"https://wago.tools/db2/DungeonEncounter/csv?build={build}")))
maps = {}
for r in rows:
    maps.setdefault(int(r["MapID"]), {})[int(r["ID"])] = (int(r["OrderIndex"]), r["Name_lang"])

out = [f"-- Erzeugt von scripts/encounters.py aus DungeonEncounter, Build {build}. Nicht von Hand ändern.",
       "-- Karte (Instanz) -> Boss-IDs wie in ENCOUNTER_END, in Reihenfolge; der letzte ist der Endboss.",
       "local _, ns = ...", "setfenv(1, ns.env)", "ENCOUNTERS = {"]
for m in sorted(maps):
    ids = [i for i, _ in sorted(maps[m].items(), key=lambda kv: (kv[1][0], kv[0]))]
    names = ", ".join(maps[m][i][1] for i in ids[-1:])
    out.append(f"  [{m}] = {{ {', '.join(map(str, ids))} }}, -- Ende: {names}")
out.append("}")
open("AutoGroupFinder/Encounters.lua", "w").write("\n".join(out) + "\n")
print(f"{len(maps)} Karten aus Build {build}")
