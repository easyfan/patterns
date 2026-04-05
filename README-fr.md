[English](README.md) | [中文](README-CN.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# patterns

Gestionnaire de patterns de workflow pour Claude Code — liste les templates, les instancie en commands/agents spécifiques au projet et corrige les étapes de hook manquantes via `--patch`.

```
/patterns                        # lister tous les patterns disponibles
/patterns <pattern_name>         # instancier un pattern de workflow
/patterns --patch [command_name] # corriger les étapes de hook manquantes dans les commands existantes
```

---

## Fonctionnement

**Mode liste** (`/patterns`) : Lit `~/.claude/patterns/` et affiche un catalogue avec description et date de dernière modification. Un indice `💡` en bas rappelle l'option `--patch`. Dans les méta-projets, les proposals en attente sont également affichées.

**Mode instanciation** (`/patterns <name>`) : Charge le template du pattern, détecte automatiquement les informations du projet (depuis `CLAUDE.md` en priorité, sinon par sondage shell) et pré-remplit le prompt de démarrage. Crée ensuite les fichiers `.claude/commands/` et `.claude/agents/` correspondants. Tous les fichiers générés contiennent `generated-from: <pattern_name>` dans leur front-matter YAML pour la traçabilité. Si un fichier cible existe déjà, un choix à trois options est proposé (écraser / ignorer / voir puis décider) — jamais d'écrasement silencieux. Un contrôle qualité `/skill-review` optionnel est proposé en fin de processus, uniquement si des fichiers command ou agent ont été écrits.

**Mode patch** (`/patterns --patch`) : Scanne les commands instanciées existantes à la recherche d'étapes de hook manquantes par correspondance exacte de titre de section. Affiche un plan de correction pour confirmation, puis ajoute les étapes manquantes. Signale positivement que tout est complet si aucun patch n'est nécessaire.

---

## Installation

### Option A — Marketplace de plugins Claude Code (recommandé)

```
/plugin marketplace add easyfan/patterns
/plugin install patterns@patterns
```

> ⚠️ **Non couvert par les tests automatisés** : `/plugin` est un builtin du REPL Claude Code et ne peut pas être invoqué via `claude -p`. À exécuter manuellement dans une session Claude Code.

### Option B — Script d'installation

```bash
# macOS / Linux
git clone https://github.com/easyfan/patterns
cd patterns
./install.sh

# Windows
.\install.ps1
```

```bash
# Options
./install.sh --dry-run      # aperçu des changements sans écriture
./install.sh --uninstall    # supprimer les fichiers installés
CLAUDE_DIR=/custom ./install.sh   # répertoire de configuration Claude personnalisé
```

> ✅ **Vérifié** : couvert par le pipeline de tests de skills (looper Stage 5).

### Option C — Manuel

```bash
cp commands/patterns.md         ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

> ✅ **Vérifié** : couvert par le pipeline de tests de skills (looper Stage 5).

---

## Utilisation

```
/patterns [pattern_name | --patch [command_name]]
```

| Argument | Description |
|----------|-------------|
| _(aucun)_ | Lister tous les patterns dans `~/.claude/patterns/` |
| `<name>` | Instancier le pattern nommé pour le projet courant |
| `--patch` | Scanner toutes les commands connues et corriger les étapes de hook manquantes |
| `--patch <cmd>` | Corriger uniquement la command spécifiée |

**Exemples :**

```
/patterns                              # afficher le catalogue (avec indice --patch en bas)
/patterns agent-monitoring             # configurer le monitoring d'agent en temps réel
/patterns --patch research-module      # ajouter le hook de contrôle qualité manquant
/patterns --patch                      # corriger toutes les commands connues
```

---

## Fichiers installés

```
~/.claude/
├── commands/
│   └── patterns.md              # slash command /patterns
└── patterns/
    └── agent-monitoring.md      # pattern de monitoring d'agent en temps réel
```

---

## Prérequis

- **Claude Code** CLI
- **find**, **stat** (outils système) — pour le scan des patterns et les horodatages
- Aucune autre dépendance

---

## Architecture

```
/patterns (coordinateur)
│
├── Sans arg :  Bash — find ~/.claude/patterns/*.md → liste avec descriptions + indice --patch
│               (méta-projet uniquement) Bash — scanner les proposals en attente
│
├── <name> :    Lire le template du pattern
│               Bash — détecter les infos du projet (CLAUDE.md ou sondage shell)
│               Remplir les espaces réservés du prompt de démarrage
│               Étape 5a — vérifier l'existence des fichiers → 3 choix : écraser/ignorer/voir
│               Écrire .claude/commands/<cmd>.md + agents si nécessaire
│               → Étape 7 : contrôle qualité /skill-review (uniquement si nouveaux fichiers .claude/)
│
└── --patch :   Bash — rechercher les fichiers de commands installées
                Grep — détecter les étapes de hook manquantes par titre exact
                Afficher le plan de correction → attendre confirmation
                Edit — ajouter les étapes de hook manquantes
                Signaler l'état sain si aucun patch n'est nécessaire
```

---

## Exemple concret : Du pattern à la sécurité en temps réel

Le 2026-03-24, le pattern `agent-monitoring` a été créé après que `/news-digest` a mis en avant un article d'OpenAI Engineering sur le monitoring d'agents en temps réel. À la session suivante, `/patterns agent-monitoring` a été exécuté dans le méta-projet :

1. **Pattern chargé** : `agent-monitoring.md` lu depuis `~/.claude/patterns/`
2. **Projet détecté** : `CLAUDE.md` trouvé → contexte projet rempli automatiquement, sans sondage shell
3. **Fichiers créés** :
   - `~/.claude/commands/agent-monitoring-workflow.md` — command coordinateur pour les audits post-tâche
4. **Contrôle qualité** : L'utilisateur a exécuté `/skill-review agent-monitoring-workflow` — 3 recommandations, toutes appliquées dans la même session

De l'instanciation du pattern à la command prête pour la production, le tout en moins de 10 minutes.

---

## Développement

### Evals

`evals/evals.json` contient 7 cas de test couvrant les modes liste, instanciation et `--patch` :

| ID | Prompt | Ce qui est vérifié |
|----|--------|--------------------|
| 1 | `/patterns` | Liste tous les patterns avec noms et dates de modification ; indice `--patch` en bas |
| 2 | `/patterns` | Affiche un indice d'utilisation ; le mode liste ne déclenche pas `/skill-review` |
| 3 | `/patterns nonexistent_pattern_xyz_12345` | Affiche « non trouvé » et liste les patterns disponibles ; pas de crash |
| 4 | `/patterns --patch` | Scanne les commands avec le champ `generated-from` ; affiche le résultat ou « aucune trouvée » |
| 5 | `/patterns --patch research-module` | Affiche le résultat du scan pour la command nommée |
| 6 | `/patterns` | Liste les patterns avec l'indice d'utilisation `--patch` en bas |
| 7 | `/patterns --patch nonexistent_cmd_xyz_99999` | Nom de command inconnu → message « non trouvé » ; pas de crash |

---

## Licence

MIT
