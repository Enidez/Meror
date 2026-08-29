#!/bin/bash
# Stop hook : sauvegarde automatique du depot sur GitHub.
# - ne commit que s'il y a des changements
# - pousse les commits en attente sur la branche courante
# - ne bloque jamais la session (sort toujours 0)
# stdin = JSON du hook (ignore).

set -u

REPO="${CLAUDE_PROJECT_DIR:-/Users/enidez/Documents/Xcode/Enidez}"
cd "$REPO" 2>/dev/null || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
case "$(git remote get-url origin 2>/dev/null)" in
  *Enidez/Meror*) ;;
  *) exit 0 ;;
esac

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -q -m "Auto-save $(date '+%Y-%m-%d %H:%M:%S')"
fi

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || exit 0
ahead="$(git rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)"
if [ "$ahead" != "0" ]; then
  if git push -q origin "$branch" 2>/dev/null; then
    printf '{"systemMessage": "Sauvegarde sur GitHub (Enidez/Meror, %s)."}\n' "$branch"
  else
    printf '{"systemMessage": "Commit local fait, push GitHub echoue (hors ligne ?)."}\n'
  fi
fi

exit 0
