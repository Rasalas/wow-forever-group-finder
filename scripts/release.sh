#!/bin/zsh
# Neue Version veröffentlichen: Version in der .toc setzen, testen, committen, taggen, pushen.
# Den Rest (Zip, GitHub-Release, CurseForge) erledigt GitHub Actions beim Tag.
#   scripts/release.sh            Version aus den Conventional Commits seit dem letzten Tag:
#                                 feat -> 0.x+1.0, Breaking (! oder BREAKING CHANGE) -> x+1.0.0
#                                 (vor 1.0 nur 0.x+1.0), sonst letzte Stelle +1
#   scripts/release.sh 0.7.0      bestimmte Version
#   BUMP=major|minor|patch        Stufe erzwingen
#   DRY=1 scripts/release.sh ...  nur zeigen, nichts ändern
set -e
root=${0:A:h:h}
cd $root
toc=AutoGroupFinder/AutoGroupFinder.toc
current=$(sed -n 's/^## Version: *//p' $toc | tr -d '\r')

if [[ -n $1 ]]; then
  next=$1 why="angegeben"
else
  bump=${BUMP:-$(scripts/commits.sh bump)}
  why="Commits: $bump"; [[ -n $BUMP ]] && why="BUMP=$BUMP"
  parts=(${(s:.:)current})
  major=$parts[1] minor=$parts[2] patch=$parts[3]
  if [[ $bump == major && $major == 0 ]]; then bump=minor; why="$why (vor 1.0 als minor)"; fi
  case $bump in
    major) next="$((major + 1)).0.0" ;;
    minor) next="$major.$((minor + 1)).0" ;;
    patch) next="$major.$minor.$((patch + 1))" ;;
    *) echo "BUMP muss major, minor oder patch sein"; exit 1 ;;
  esac
fi
[[ $next =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "Version muss wie 1.2.3 aussehen: $next"; exit 1 }
[[ $next != $current ]] || { echo "Version ist schon $current"; exit 1 }

branch=$(git rev-parse --abbrev-ref HEAD)
[[ $branch == main ]] || { echo "Nur von main aus (gerade: $branch)"; exit 1 }
[[ -z $(git status --porcelain) ]] || { echo "Es gibt nicht committete Änderungen"; git status --short; exit 1 }
git fetch -q origin
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || { echo "main ist nicht auf dem Stand von origin/main (erst pushen oder pullen)"; exit 1 }
git rev-parse -q --verify "refs/tags/v$next" >/dev/null && { echo "Tag v$next gibt es schon"; exit 1 }

echo "Version $current -> $next ($why)"
echo
scripts/commits.sh changelog $next | sed 's/^/  /' 
[[ -n $DRY ]] && { echo "(DRY: nichts geändert)"; exit 0 }

scripts/test.sh >/dev/null || { echo "Tests schlagen fehl, abgebrochen"; scripts/test.sh | grep -v '^ok'; exit 1 }
# YES=1 überspringt die Rückfrage (ohne Terminal, z. B. aus Skripten)
[[ -n $YES ]] || read -q "?Veröffentlichen (Commit, Tag v$next, Push)? [y/N] " || { echo; echo "Abgebrochen"; exit 1 }
echo

sed -i '' "s/^## Version: .*/## Version: $next/" $toc
git commit -q -m "Version $next" -- $toc
git tag -a "v$next" -m "Auto Group Finder $next"
git push -q origin main "v$next"
echo "v$next gepusht. Ablauf: $(gh run list --limit 1 --json url -q '.[0].url' 2>/dev/null || echo 'GitHub > Actions')"
