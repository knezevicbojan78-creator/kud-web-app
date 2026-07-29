import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import XLSX from "xlsx";

const outputDirectory = resolve(".test-data");
const outputFile = resolve(outputDirectory, "codex-e2e-bulk-import-v2.xlsx");
const templateFile = resolve(
  "public/templates/Sablon-za-masovni-unos-osoba-v2.xlsx"
);
mkdirSync(outputDirectory, { recursive: true });

const rows = [
  ["Član", "Test", "Član Automatski", "codex.e2e.member.001@example.com"],
  [
    "Roditelj/staratelj",
    "Test",
    "Roditelj Automatski",
    "codex.e2e.guardian.001@example.com"
  ]
];

const workbook = XLSX.readFile(templateFile, {
  cellFormula: true,
  cellStyles: true
});
const worksheet = workbook.Sheets.OSOBE;

rows.forEach(([personType, firstName, lastName, email], index) => {
  const rowNumber = index + 6;
  worksheet[`A${rowNumber}`] = { t: "s", v: personType };
  worksheet[`B${rowNumber}`] = { t: "s", v: firstName };
  worksheet[`C${rowNumber}`] = { t: "s", v: lastName };
  worksheet[`F${rowNumber}`] = { t: "s", v: email };
});

XLSX.writeFile(workbook, outputFile);

console.log(`Kontrolisani test fajl je napravljen: ${outputFile}`);
