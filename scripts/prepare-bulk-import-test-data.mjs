import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import * as XLSX from "xlsx";

const outputDirectory = resolve(".test-data");
const outputFile = resolve(outputDirectory, "codex-e2e-bulk-import.xlsx");
mkdirSync(outputDirectory, { recursive: true });

const rows = [
  {
    Ime: "Test Član",
    Prezime: "Automatski",
    Email: "codex.e2e.member.001@example.com"
  },
  {
    Ime: "Test Roditelj",
    Prezime: "Automatski",
    Email: "codex.e2e.guardian.001@example.com"
  }
];

const workbook = XLSX.utils.book_new();
const worksheet = XLSX.utils.json_to_sheet(rows);
XLSX.utils.book_append_sheet(workbook, worksheet, "Osobe");
XLSX.writeFile(workbook, outputFile);

console.log(`Kontrolisani test fajl je napravljen: ${outputFile}`);
