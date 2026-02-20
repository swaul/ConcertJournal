#!/usr/bin/env node
/**
 * generate-textkey.js
 *
 * Generates TextKey.swift from the source locale JSON.
 * - Groups cases under MARK sections based on the key prefix
 * - Derives a camelCase Swift identifier from the JSON key
 * - Automatically resolves name collisions by prepending prefix segments
 *   e.g. "home.title" + "map.title" → homeTitle + mapTitle (not title + title)
 * - Appends the existing extension block (localized helpers) unchanged
 *
 * Usage:
 *   node generate-textkey.js
 *   node generate-textkey.js --dry-run    (print to stdout only)
 *   node generate-textkey.js --report     (show collision resolution summary)
 */

const fs   = require("fs");
const path = require("path");

// ─── Config ──────────────────────────────────────────────────────────────────

const CONFIG_PATH = path.join(__dirname, "localization.config.json");
const config      = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));

const LOCALES_DIR  = path.resolve(__dirname, config.localesDir);
const SOURCE       = config.sourceLocale;
const OUTPUT_FILE  = path.resolve(__dirname, config.outputSwiftFile);
const ENUM_NAME    = config.enumName              || "TextKey";
const IMPORTS      = config.swiftImports          || ["Foundation"];
const SECTIONS     = config.commentSections       || {};
// stripPrefixInCaseNames (default: true)
// true  → start by stripping the first segment, add it back only on collision
// false → always keep full key as camelCase (no collision resolution needed)
const STRIP_PREFIX = config.stripPrefixInCaseNames !== false;
const DRY_RUN      = process.argv.includes("--dry-run");
const REPORT       = process.argv.includes("--report");

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Reserved Swift keywords that need backtick escaping */
const RESERVED = new Set([
  "import", "class", "struct", "enum", "func", "var", "let", "if", "else",
  "for", "while", "return", "true", "false", "nil", "switch", "case",
  "default", "break", "continue", "in", "is", "as", "do", "try", "catch",
  "throw", "throws", "init", "self", "super", "protocol", "extension",
  "typealias", "where", "guard", "defer", "repeat", "operator", "static",
  "internal", "public", "private", "fileprivate", "open", "final",
  "override", "mutating", "nonmutating", "lazy", "weak", "unowned",
  "associatedtype", "subscript", "convenience", "required", "set", "get",
]);

/**
 * Convert a dot/underscore separated key into camelCase,
 * using segments starting from `fromSegment`.
 *
 * "action.open_in_maps", fromSegment=1 → "openInMaps"
 * "action.open_in_maps", fromSegment=0 → "actionOpenInMaps"
 */
function toCamelCase(key, fromSegment) {
  const parts = key.split(/[._]+/).slice(fromSegment);
  return parts
    .map((p, i) => i === 0 ? p : p.charAt(0).toUpperCase() + p.slice(1))
    .join("");
}

function escape(name) {
  return RESERVED.has(name) ? `\`${name}\`` : name;
}

/** Pad a string on the right to a given length */
function padRight(str, len) {
  return str + " ".repeat(Math.max(0, len - str.length));
}

// ─── Load source JSON ─────────────────────────────────────────────────────────

const sourceFile = path.join(LOCALES_DIR, `${SOURCE}.json`);
if (!fs.existsSync(sourceFile)) {
  console.error(`\u2717 Source file not found: ${sourceFile}`);
  process.exit(1);
}

const sourceObj = JSON.parse(fs.readFileSync(sourceFile, "utf8"));
const allKeys   = Object.keys(sourceObj).filter(k => k !== "__obsolete");

// ─── Resolve identifiers (with collision handling) ────────────────────────────

/**
 * Build the final map of JSON key → Swift identifier.
 *
 * Algorithm (only when STRIP_PREFIX = true):
 *   1. Try stripping the first segment (e.g. "cancel" for "action.cancel")
 *   2. If that name is already taken by a *different* key, both conflicting
 *      keys get one more segment from the left until names are unique.
 *   3. Repeat until all names are unique.
 *
 * This means most keys stay short. Only the ones that actually collide
 * get a disambiguating prefix, automatically.
 */
function resolveIdentifiers(keys) {
  if (!STRIP_PREFIX) {
    const map = {};
    for (const key of keys) map[key] = escape(toCamelCase(key, 0));
    return map;
  }

  // Start everyone at fromSegment = 1 (strip the first segment)
  const segments = {};
  for (const key of keys) segments[key] = 1;

  const maxPasses = Math.max(...keys.map(k => k.split(/[._]+/).length));

  for (let pass = 0; pass < maxPasses; pass++) {
    // name → [keys that currently map to it]
    const nameToKeys = new Map();
    for (const key of keys) {
      const name = toCamelCase(key, segments[key]);
      if (!nameToKeys.has(name)) nameToKeys.set(name, []);
      nameToKeys.get(name).push(key);
    }

    let anyCollision = false;
    for (const [, conflicting] of nameToKeys) {
      if (conflicting.length > 1) {
        anyCollision = true;
        for (const key of conflicting) {
          if (segments[key] > 0) segments[key]--;
        }
      }
    }

    if (!anyCollision) break;
  }

  const resolved      = {};
  const collisionLog  = [];

  for (const key of keys) {
    const name  = toCamelCase(key, segments[key]);
    const ident = escape(name);
    resolved[key] = ident;
    if (segments[key] < 1) collisionLog.push({ key, ident });
  }

  if (REPORT && collisionLog.length > 0) {
    console.error("\n── Collision resolution report ──");
    for (const { key, ident } of collisionLog) {
      console.error(`  ${key.padEnd(44)} → ${ident}`);
    }
    console.error("");
  }

  return resolved;
}

const identMap = resolveIdentifiers(allKeys);

// ─── Group keys by prefix ─────────────────────────────────────────────────────

const groups = new Map();
for (const key of allKeys) {
  const pfx = key.split(".")[0];
  if (!groups.has(pfx)) groups.set(pfx, []);
  groups.get(pfx).push(key);
}

const maxIdentLen = Math.max(...Object.values(identMap).map(v => v.length));

// ─── Build enum body ──────────────────────────────────────────────────────────

const lines = [];

const dateStr = new Date().toISOString().split("T")[0];
lines.push(`//`);
lines.push(`//  ${ENUM_NAME}.swift`);
lines.push(`//  Auto-generated by generate-textkey.js on ${dateStr}`);
lines.push(`//  ⚠️  Do not edit manually – re-run the script instead.`);
lines.push(`//`);
lines.push(``);

for (const imp of IMPORTS) lines.push(`import ${imp}`);
lines.push(``);
lines.push(`// MARK: - String Keys Enum`);
lines.push(``);
lines.push(`enum ${ENUM_NAME}: String {`);

for (const [pfx, keys] of groups) {
  const sectionTitle = SECTIONS[pfx] || pfx.charAt(0).toUpperCase() + pfx.slice(1);
  lines.push(``);
  lines.push(`    // MARK: - ${sectionTitle}`);

  for (const key of keys) {
    const ident   = identMap[key];
    const value   = sourceObj[key];
    const hasArgs = typeof value === "string" && value.includes("%");
    const comment = hasArgs ? `  // "${value}"` : "";
    lines.push(`    case ${padRight(ident, maxIdentLen)} = "${key}"${comment}`);
  }
}

lines.push(`}`);
lines.push(``);
lines.push(`// MARK: - SwiftUI Convenience`);
lines.push(``);
lines.push(`extension ${ENUM_NAME} {`);
lines.push(`    /// Direct access: Text(TextKey.homeTitle.localized)`);
lines.push(`    var localized: String {`);
lines.push(`        TextManager.shared.string(for: self)`);
lines.push(`    }`);
lines.push(``);
lines.push(`    func localized(with arguments: CVarArg...) -> String {`);
lines.push(`        TextManager.shared.string(for: self, with: arguments)`);
lines.push(`    }`);
lines.push(`}`);
lines.push(``);

const output = lines.join("\n");

// ─── Write / print ────────────────────────────────────────────────────────────

if (DRY_RUN) {
  console.log(output);
} else {
  fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });
  fs.writeFileSync(OUTPUT_FILE, output, "utf8");
  console.log(`\n✅  Generated ${ENUM_NAME}.swift`);
  console.log(`    ${allKeys.length} cases  →  ${OUTPUT_FILE}\n`);
}
