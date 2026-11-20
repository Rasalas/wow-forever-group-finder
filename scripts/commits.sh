#!/usr/bin/env bash
# Conventional Commits seit dem letzten Tag auswerten.
#   scripts/commits.sh bump [range]              -> major | minor | patch
#   scripts/commits.sh changelog VERSION [range] -> Markdown für die Release-Notizen
# range z. B. v0.6.0..HEAD; ohne Angabe seit dem letzten Tag (bzw. alles).
set -euo pipefail
mode=$1; shift
version=
if [[ $mode == changelog ]]; then version=$1; shift; fi
range=${1:-}
if [[ -z $range ]]; then
  prev=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
  range=${prev:+$prev..}HEAD
fi

breaking=() features=() fixes=() other=()
type_re='^([a-z]+)(\([^)]*\))?(!)?: (.*)$'
while IFS= read -r -d $'\x1e' entry; do
  entry=${entry#$'\n'}
  subject=${entry%%$'\x1f'*}
  body=${entry#*$'\x1f'}
  [[ -z $subject || $subject =~ ^Version\ [0-9] ]] && continue
  if [[ $subject =~ $type_re ]]; then
    type=${BASH_REMATCH[1]} bang=${BASH_REMATCH[3]} text=${BASH_REMATCH[4]}
    if [[ -n $bang || $body == *"BREAKING CHANGE"* || $body == *"BREAKING-CHANGE"* ]]; then breaking+=("$text"); continue; fi
    case $type in
      feat) features+=("$text") ;;
      fix|perf) fixes+=("$text") ;;
      chore|ci|build|test|docs|style|refactor) ;; # intern, nicht in die Notizen
      *) other+=("$text") ;;
    esac
  else
    other+=("$subject") # ältere Commits ohne Typ
  fi
done < <(git log --format='%s%x1f%b%x1e' "$range")

if [[ $mode == bump ]]; then
  if (( ${#breaking[@]} )); then echo major
  elif (( ${#features[@]} )); then echo minor
  else echo patch; fi
  exit 0
fi

section() { local title=$1; shift; (( $# )) || return 0; echo "### $title"; printf -- '- %s\n' "$@"; echo; }
echo "## $version"; echo
section "Breaking changes" ${breaking[@]+"${breaking[@]}"}
section "Features" ${features[@]+"${features[@]}"}
section "Fixes" ${fixes[@]+"${fixes[@]}"}
section "Changes" ${other[@]+"${other[@]}"}
