#!/bin/zsh
# Erst alle Tests, dann auf den Spielrechner kopieren. Zielordner wird vorher geleert (keine Altdateien).
root=${0:A:h:h}
target="/path/to/World of Warcraft/_forever_/Interface/AddOns/AutoGroupFinder"
$root/scripts/test.sh || { echo "Tests fehlgeschlagen – nichts kopiert."; exit 1 }
ssh -o BatchMode=yes my-gaming-pc "rm -rf '$target' && mkdir -p '$target'" &&
  scp -q -r $root/AutoGroupFinder/* "my-gaming-pc:$target/" && echo DEPLOYED
