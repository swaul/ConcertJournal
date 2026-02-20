# Localization Scripts

Drei Dateien, ein Workflow.

```
scripts/
├── localization.config.json   ← zentrale Konfiguration
├── sync-locales.js            ← synct alle Sprach-JSONs
└── generate-textkey.js        ← generiert TextKey.swift
```

---

## Workflow

### 1. Neuen String hinzufügen

Einfach in `de-DE.json` (deine Source-Sprache) einen Key hinzufügen:

```json
"action.share": "Teilen"
```

### 2. Alle Sprachen syncen

```bash
node scripts/sync-locales.js
```

- Neue Keys → werden in allen Ziel-Sprachen mit `""` angelegt
- Bestehende Übersetzungen → werden **nie** überschrieben
- Veraltete Keys → wandern in einen `__obsolete` Block am Ende der Datei

```
📖  Source: de-DE.json  (386 keys)

  ✅  en-US.json  —  1 new  |  385 kept
  ✅  fr-FR.json  —  1 new  |  385 kept
  ✅  es-ES.json  —  1 new  |  385 kept

✔  Sync complete.
```

### 3. TextKey.swift neu generieren

```bash
node scripts/generate-textkey.js
```

Generiert `TextKey.swift` mit einem Case pro Key, MARK-Sektionen und dem
`localized` / `localized(with:)` Extension Block.

---

## Optionen

### sync-locales.js

| Flag | Beschreibung |
|------|-------------|
| `--dry-run` | Zeigt was sich ändern würde, schreibt aber nichts |
| `--locale en-US` | Synct nur eine bestimmte Sprache |

```bash
node scripts/sync-locales.js --dry-run
node scripts/sync-locales.js --locale fr-FR
```

### generate-textkey.js

| Flag | Beschreibung |
|------|-------------|
| `--dry-run` | Gibt den generierten Swift-Code auf stdout aus statt zu schreiben |

```bash
node scripts/generate-textkey.js --dry-run
```

---

## localization.config.json

| Feld | Beschreibung |
|------|-------------|
| `sourceLocale` | Die Mastersprache (z.B. `"de-DE"`) |
| `localesDir` | Pfad zum Ordner mit den JSON-Dateien (relativ zum scripts-Ordner) |
| `outputSwiftFile` | Pfad für die generierte `TextKey.swift` |
| `targetLocales` | Array aller Zielsprachen |
| `enumName` | Name des Swift-Enums (Standard: `"TextKey"`) |
| `swiftImports` | Imports im generierten File |
| `stripPrefixInCaseNames` | `true` → `cancel`, `false` → `actionCancel` (Standard: `true`) |
| `commentSections` | Mapping von Key-Prefix → MARK-Kommentar |

---

## Tipp: als npm scripts einbinden

In `package.json`:

```json
{
  "scripts": {
    "loc:sync":     "node scripts/sync-locales.js",
    "loc:generate": "node scripts/generate-textkey.js",
    "loc:check":    "node scripts/sync-locales.js --dry-run"
  }
}
```

Dann einfach:
```bash
npm run loc:sync
npm run loc:generate
```
