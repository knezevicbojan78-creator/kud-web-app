import { mkdirSync } from "node:fs";
import { resolve } from "node:path";
import XLSX from "xlsx";

const outputDirectory = resolve(".test-data");
const templateFile = resolve("public/templates/Sablon-za-masovni-unos-osoba-v2.xlsx");
const outputFile = resolve(outputDirectory, "codex-e2e-email-delivery-test.xlsx");

mkdirSync(outputDirectory, { recursive: true });

const workbook = XLSX.readFile(templateFile, { cellFormula: true, cellStyles: true });
const worksheet = workbook.Sheets.OSOBE;
worksheet.A6 = { t: "s", v: "Član" };
worksheet.B6 = { t: "s", v: "CODEX E2E" };
worksheet.C6 = { t: "s", v: "Gmail provera" };
worksheet.F6 = { t: "s", v: "knezevic.bojan78@gmail.com" };
XLSX.writeFile(workbook, outputFile);

console.log(outputFile);
