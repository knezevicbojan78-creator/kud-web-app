import { readFileSync } from "node:fs";

const allowedStatuses = new Set(["applied", "prepared", "retired"]);
const ledger = JSON.parse(
  readFileSync(new URL("../supabase/migration-ledger.json", import.meta.url), "utf8")
);
const errors = [];
const seen = new Set();

for (const entry of ledger.entries ?? []) {
  if (!entry.file || seen.has(entry.file)) {
    errors.push(`Neispravan ili dupliran zapis: ${entry.file ?? "(bez fajla)"}`);
    continue;
  }
  seen.add(entry.file);
  if (!allowedStatuses.has(entry.status)) {
    errors.push(`${entry.file}: nepoznat status "${entry.status}"`);
  }
  try {
    readFileSync(new URL(`../supabase/${entry.file}`, import.meta.url));
  } catch {
    errors.push(`${entry.file}: SQL fajl ne postoji`);
  }
  if (entry.verified_by) {
    try {
      readFileSync(new URL(`../supabase/${entry.verified_by}`, import.meta.url));
    } catch {
      errors.push(`${entry.file}: dijagnostički SQL ne postoji`);
    }
  }
  if (entry.status === "applied" && !entry.applied_on) {
    errors.push(`${entry.file}: primenjena promena nema datum`);
  }
}

if (errors.length) {
  console.error("Evidencija promena baze nije ispravna:");
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log(`Evidencija promena baze je ispravna (${seen.size} zapisa).`);
