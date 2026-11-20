#!/bin/zsh
# Syntax unter Lua 5.1 (LuaJIT, wie WoW) prüfen und alle Simulator-Tests ausführen.
root=${0:A:h:h}
addon=$root/AutoGroupFinder
for f in $addon/**/*.lua; do
  luajit -b "$f" /dev/null || { echo "Syntaxfehler: $f"; exit 1 }
done
failed=0
for t in $root/tests/*.lua; do
  out=$(luajit "$t" "$addon" 2>&1)
  if echo "$out" | grep -q "^luajit:\|stack traceback\|konnte nicht starten\|could not start"; then
    echo "FEHLER in ${t:t}:"; echo "$out" | grep -m4 "luajit:\|attempt\|starten\|start"; failed=1
  else
    echo "ok  ${t:t}"
  fi
done
exit $failed
