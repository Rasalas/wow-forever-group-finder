#!/bin/zsh
# docs/checklist.html -> dist/checklist.pdf (A4) über Chrome ohne Fenster
set -e
root=${0:A:h:h}
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x $chrome ]] || { echo "Google Chrome nicht gefunden: $chrome"; exit 1 }
version=$(sed -n 's/^## Version: *//p' $root/AutoGroupFinder/AutoGroupFinder.toc)
mkdir -p $root/dist
sed -e "s/{{VERSION}}/$version/" -e "s/{{DATE}}/$(date +%d.%m.%Y)/" $root/docs/checklist.html > $root/dist/checklist.html
"$chrome" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf-no-header \
  --print-to-pdf=$root/dist/checklist.pdf file://$root/dist/checklist.html 2>/dev/null
echo "dist/checklist.pdf"
