#!/usr/bin/env node
/**
 * sync-locales.js
 *
 * Syncs all target locale JSON files against the source locale.
 *
 * Rules:
 *  - New keys (in source, not in target)  → added with empty string ""
 *  - Existing keys                        → kept as-is (never overwritten)
 *  - Obsolete keys (in target, not source)→ moved to a "__obsolete" block at the bottom
 *  - Key order                            → always matches source file order
 *
 * Usage:
 *   node sync-locales.js                  (uses localization.config.json next to this script)
 *   node sync-locales.js --dry-run        (prints diff without writing)
 *   node sync-locales.js --locale en-US   (only sync one locale)
 */

const fs   = require("fs");
const path = require("path");

// ─── Config ─────────────────────────────────────────────────────────────────

const CONFIG_PATH = path.join(__dirname, "localization.config.json");
const config      = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));

const LOCALES_DIR  = path.resolve(__dirname, config.localesDir);
const SOURCE       = config.sourceLocale;          // e.g. "de-DE"
const TARGETS      = config.targetLocales;         // e.g. ["en-US", "fr-FR"]
const DRY_RUN      = process.argv.includes("--dry-run");
const ONLY_LOCALE  = (() => {
  const idx = process.argv.indexOf("--locale");
  return idx !== -1 ? process.argv[idx + 1] : null;
})();

// ─── Helpers ─────────────────────────────────────────────────────────────────

function readJson(filePath) {
  if (!fs.existsSync(filePath)) return {};
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (e) {
    console.error(`  ✗ Failed to parse ${filePath}: ${e.message}`);
    process.exit(1);
  }
}

/**
 * Serialise a flat key→value object to a pretty-printed JSON string,
 * preserving insertion order.
 */
function toJson(obj) {
  return JSON.stringify(obj, null, 2);
}

/**
 * Build a merged object for one target locale.
 * Returns { merged, stats }
 */
function merge(sourceObj, targetObj) {
  const merged   = {};
  const stats    = { added: 0, kept: 0, obsolete: 0 };
  const sourceKeys = Object.keys(sourceObj);
  const targetKeys = new Set(Object.keys(targetObj));

  // Walk source keys in order
  for (const key of sourceKeys) {
    if (targetKeys.has(key)) {
      // Keep existing translation (even if empty – translator's choice)
      merged[key] = targetObj[key];
      stats.kept++;
    } else {
      // New key → empty string as placeholder
      merged[key] = "";
      stats.added++;
    }
  }

  // Collect obsolete keys (exist in target but not in source)
  const obsolete = {};
  for (const key of targetKeys) {
    if (!(key in sourceObj) && key !== "__obsolete") {
      obsolete[key] = targetObj[key];
      stats.obsolete++;
    }
  }

  // Carry over previous obsolete block too
  const prevObsolete = targetObj["__obsolete"] || {};
  const allObsolete  = { ...prevObsolete, ...obsolete };

  if (Object.keys(allObsolete).length > 0) {
    merged["__obsolete"] = allObsolete;
  }

  return { merged, stats };
}

// ─── Main ────────────────────────────────────────────────────────────────────

const sourceFile = path.join(LOCALES_DIR, `${SOURCE}.json`);
if (!fs.existsSync(sourceFile)) {
  console.error(`✗ Source file not found: ${sourceFile}`);
  process.exit(1);
}

const sourceObj = readJson(sourceFile);
console.log(`\n📖  Source: ${SOURCE}.json  (${Object.keys(sourceObj).length} keys)\n`);

const localesToSync = ONLY_LOCALE ? [ONLY_LOCALE] : TARGETS;

for (const locale of localesToSync) {
  const targetFile = path.join(LOCALES_DIR, `${locale}.json`);
  const targetObj  = readJson(targetFile);  // {} if file doesn't exist yet
  const isNew      = !fs.existsSync(targetFile);

  const { merged, stats } = merge(sourceObj, targetObj);

  const summary = [
    stats.added    > 0 ? `+${stats.added} new`           : null,
    stats.kept     > 0 ? `${stats.kept} kept`             : null,
    stats.obsolete > 0 ? `${stats.obsolete} obsolete`     : null,
  ].filter(Boolean).join("  |  ");

  if (DRY_RUN) {
    console.log(`  [dry-run] ${locale}.json  —  ${summary}`);
    if (stats.added > 0) {
      const newKeys = Object.keys(merged).filter(k => targetObj[k] === undefined && k !== "__obsolete");
      newKeys.forEach(k => console.log(`    + ${k}`));
    }
    if (stats.obsolete > 0) {
      const obsKeys = Object.keys(merged.__obsolete || {});
      obsKeys.forEach(k => console.log(`    ~ obsolete: ${k}`));
    }
  } else {
    fs.writeFileSync(targetFile, toJson(merged) + "\n", "utf8");
    const icon = isNew ? "🆕" : "✅";
    console.log(`  ${icon}  ${locale}.json  —  ${summary}`);
  }
}

console.log(DRY_RUN ? "\n(dry run – no files written)\n" : "\n✔  Sync complete.\n");
