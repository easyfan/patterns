[English](README.md) | [中文](README-CN.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

# patterns

Workflow-Pattern-Manager für Claude Code — listet Pattern-Vorlagen auf, instanziiert sie als projekt­spezifische Commands/Agents und behebt fehlende Hook-Schritte per `--patch`.

```
/patterns                        # alle verfügbaren Pattern auflisten
/patterns <pattern_name>         # Workflow-Pattern instanziieren
/patterns --patch [command_name] # fehlende Hook-Schritte in vorhandenen Commands ergänzen
```

---

## Funktionsweise

**Listenmodus** (`/patterns`): Liest `~/.claude/patterns/` ein und gibt einen Katalog mit Beschreibung und letztem Änderungsdatum aus. Am Ende erscheint ein `💡`-Hinweis auf die `--patch`-Option. In Meta-Projekten werden zusätzlich unbehandelte Pending Proposals angezeigt.

**Instanziierungsmodus** (`/patterns <name>`): Lädt die Pattern-Vorlage, erkennt automatisch Projektinformationen (bevorzugt aus `CLAUDE.md`, sonst per Shell-Sonden) und befüllt den Kickoff-Prompt vor. Anschließend werden die entsprechenden `.claude/commands/`- und `.claude/agents/`-Dateien erzeugt. Alle generierten Dateien enthalten `generated-from: <pattern_name>` im YAML-Front-Matter zur Nachverfolgbarkeit. Existiert eine Zieldatei bereits, wird eine Dreifach-Auswahl angeboten (überschreiben / überspringen / ansehen und entscheiden) — nie ein stilles Überschreiben. Abschließend ist ein optionales `/skill-review`-Qualitätstor verfügbar, das nur ausgelöst wird, wenn Command- oder Agent-Dateien geschrieben wurden.

**Patch-Modus** (`/patterns --patch`): Scannt vorhandene instanziierte Commands auf fehlende Hook-Schritte anhand exakter Titelzeilen-Erkennung. Zeigt einen Patch-Plan zur Bestätigung an und hängt die fehlenden Schritte anschließend an. Gibt eine positive Bestätigung aus, wenn kein Patching nötig ist.

---

## Installation

### Option A — Claude Code Plugin-Marktplatz (empfohlen)

```
/plugin marketplace add easyfan/patterns
/plugin install patterns@patterns
```

> ⚠️ **Nicht durch automatisierte Tests abgedeckt**: `/plugin` ist ein Claude Code REPL-Builtin und kann nicht per `claude -p` aufgerufen werden. Bitte manuell in einer Claude Code-Sitzung ausführen.

### Option B — Installations-Skript

```bash
# macOS / Linux
git clone https://github.com/easyfan/patterns
cd patterns
./install.sh

# Windows
.\install.ps1
```

```bash
# Optionen
./install.sh --dry-run      # Änderungen anzeigen, ohne zu schreiben
./install.sh --uninstall    # installierte Dateien entfernen
CLAUDE_DIR=/custom ./install.sh   # eigenes Claude-Konfigurationsverzeichnis
```

> ✅ **Verifiziert**: durch die Skill-Test-Pipeline (looper Stage 5) abgedeckt.

### Option C — Manuell

```bash
cp commands/patterns.md         ~/.claude/commands/
cp patterns/agent-monitoring.md ~/.claude/patterns/
```

> ✅ **Verifiziert**: durch die Skill-Test-Pipeline (looper Stage 5) abgedeckt.

---

## Verwendung

```
/patterns [pattern_name | --patch [command_name]]
```

| Argument | Beschreibung |
|----------|-------------|
| _(keins)_ | Alle Pattern in `~/.claude/patterns/` auflisten |
| `<name>` | Das genannte Pattern für das aktuelle Projekt instanziieren |
| `--patch` | Alle bekannten Commands auf fehlende Hook-Schritte prüfen und ergänzen |
| `--patch <cmd>` | Nur den angegebenen Command patchen |

**Beispiele:**

```
/patterns                              # Katalog anzeigen (mit --patch-Hinweis)
/patterns agent-monitoring             # Laufzeit-Agent-Monitoring einrichten
/patterns --patch research-module      # fehlenden Quality-Gate-Hook ergänzen
/patterns --patch                      # alle bekannten Commands patchen
```

---

## Installierte Dateien

**Option A — Plugin-Installation** (`/plugin install`):
```
~/.claude/
└── skills/
    └── patterns/                # /patterns:patterns Skill (automatisch erkannt)
        └── SKILL.md
# Mitgelieferte Templates verbleiben im Plugin-Cache — Zugriff via $SKILL_FILE, keine Kopie nötig
```

**Option B/C — Installations-Skript / Manuell**:
```
~/.claude/
├── commands/
│   └── patterns.md              # /patterns-Slash-Command
├── patterns/
│   └── agent-monitoring.md      # Laufzeit-Agent-Monitoring-Pattern
└── skills/
    └── patterns/                # /patterns:patterns Skill
        └── SKILL.md
```

---

## Voraussetzungen

- **Claude Code** CLI
- **find**, **stat** (Systemprogramme) — für Pattern-Scan und Zeitstempel
- Keine weiteren Abhängigkeiten

---

## Architektur

```
/patterns:patterns (Skill, Koordinator)
│
│  Pfadauflösung (bei jedem Start):
│    PLUGIN_ROOT      = dirname(dirname($SKILL_FILE))
│    PLUGIN_TEMPLATES = $PLUGIN_ROOT/templates/   ← mitgelieferte Templates im Plugin-Cache
│    USER_PATTERNS    = ~/.claude/patterns/        ← benutzereigene Templates
│    (beide Quellen scannen; benutzereigene Templates überschreiben gleichnamige Plugin-Templates)
│
├── Kein Arg:  Bash — USER_PATTERNS + PLUGIN_TEMPLATES scannen → Liste + --patch-Hinweis
│              (nur Meta-Projekt) Bash — Pending Proposals scannen
│
├── <name>:    Pattern-Vorlage lesen (zuerst USER_PATTERNS, dann PLUGIN_TEMPLATES)
│              Bash — Projektinfos erkennen (CLAUDE.md oder Shell-Sonde)
│              Kickoff-Prompt-Platzhalter befüllen
│              Schritt 5a — Dateiexistenz prüfen → 3-Weg: überschreiben/überspringen/ansehen
│              .claude/commands/<cmd>.md + Agents schreiben (falls nötig)
│              → Schritt 7: /skill-review-Qualitätstor (nur bei neuen .claude/-Dateien)
│
└── --patch:   Bash — installierte Command-Dateien suchen
               Grep — fehlende Hook-Schritte per Titelzeile erkennen
               Patch-Plan anzeigen → Bestätigung abwarten
               Edit — fehlende Hook-Schritte anhängen
               Gesunden Zustand melden, wenn kein Patching nötig
```

---

## Praxisbeispiel: Vom Pattern zur Laufzeit-Sicherheit

Am 2026-03-24 wurde das `agent-monitoring`-Pattern erstellt, nachdem `/news-digest` einen OpenAI-Engineering-Beitrag über Laufzeit-Agent-Monitoring surfaced hatte. In der nächsten Sitzung wurde `/patterns agent-monitoring` im Meta-Projekt ausgeführt:

1. **Pattern geladen**: `agent-monitoring.md` aus `~/.claude/patterns/` gelesen
2. **Projekt erkannt**: `CLAUDE.md` gefunden → Projektkontext automatisch befüllt, keine Shell-Sonden nötig
3. **Dateien erstellt**:
   - `~/.claude/commands/agent-monitoring-workflow.md` — Koordinator-Command für Post-Task-Audits
4. **Qualitätstor**: Benutzer führte `/skill-review agent-monitoring-workflow` aus — 3 Empfehlungen, alle in derselben Sitzung umgesetzt

Vom Pattern bis zum geprüften, produktionsreifen Command vergingen weniger als 10 Minuten.

---

## Entwicklung

### Evals

`evals/evals.json` enthält 7 Testfälle für List-, Instanziierungs- und `--patch`-Modus:

| ID | Prompt | Was geprüft wird |
|----|--------|-----------------|
| 1 | `/patterns` | Listet alle Pattern mit Namen und Änderungsdatum; `--patch`-Hinweis am Ende |
| 2 | `/patterns` | Gibt Verwendungshinweis aus; kein `/skill-review`-Aufruf im Listenmodus |
| 3 | `/patterns nonexistent_pattern_xyz_12345` | Gibt „nicht gefunden"-Meldung aus und listet verfügbare Pattern; kein Absturz |
| 4 | `/patterns --patch` | Scannt nach Commands mit `generated-from`-Feld; gibt Scan-Ergebnis oder „keine gefunden" aus |
| 5 | `/patterns --patch research-module` | Zeigt Scan-Ergebnis für benannten Command |
| 6 | `/patterns` | Listet Pattern mit `--patch`-Verwendungshinweis am Ende |
| 7 | `/patterns --patch nonexistent_cmd_xyz_99999` | Unbekannter Command-Name liefert „nicht gefunden"-Meldung; kein Absturz |

---

## Lizenz

MIT
