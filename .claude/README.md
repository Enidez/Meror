# .claude/

Configuration Claude Code pour ce dépôt.

## Sauvegarde automatique

`hooks/autosave-git.sh` s'exécute sur l'événement **Stop** (fin de chaque
réponse de Claude) :

- commit uniquement s'il y a des changements (`Auto-save <date>`)
- pousse la branche courante si elle a de l'avance sur `origin`
- ne bloque jamais la session, silencieux quand il n'y a rien à faire
- ne s'active que si le remote `origin` pointe vers `Enidez/Meror`

Le hook est branché dans `settings.local.json` (non versionné, propre à la
machine). Pour le désactiver : `/hooks` → `Stop` → supprimer l'entrée, ou
retirer le bloc `hooks` de `settings.local.json`.
