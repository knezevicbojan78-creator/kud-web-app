import assert from "node:assert/strict";
import test from "node:test";
import { fileURLToPath } from "node:url";

import XLSX from "xlsx";

import {
  parseBulkImportFile
} from "../../app/_lib/memberBulkImport.ts";

const templatePath = fileURLToPath(
  new URL("../../public/templates/Sablon-za-masovni-unos-osoba-v2.xlsx", import.meta.url)
);

function loadTemplate() {
  return XLSX.readFile(templatePath, {
    cellDates: true,
    cellFormula: true,
    cellStyles: true
  });
}

function addRows(workbook, rows) {
  XLSX.utils.sheet_add_aoa(workbook.Sheets.OSOBE, rows, { origin: "A6" });
  return workbook;
}

const validRow = [
  "Član",
  "Mila",
  "Milić",
  "Žensko",
  "15.04.2000",
  "MILA@EXAMPLE.COM",
  "+38160111222",
  "Glavna 1",
  "Novi Sad",
  "21000",
  "Srbija",
  "",
  "P123456",
  "15.04.2030",
  ""
];

test("aktuelni šablon prihvata ispravan red", () => {
  const rows = parseBulkImportFile(addRows(loadTemplate(), [validRow]), XLSX);

  assert.equal(rows.length, 1);
  assert.deepEqual(rows[0].errors, []);
  assert.equal(rows[0].email, "mila@example.com");
  assert.equal(rows[0].birthDate, "2000-04-15");
  assert.equal(rows[0].passportExpiryDate, "2030-04-15");
});

test("izmenjene kolone šablona se odbijaju", () => {
  const workbook = loadTemplate();
  workbook.Sheets.OSOBE.A5.v = "Pogrešna kolona";

  assert.throws(
    () => parseBulkImportFile(workbook, XLSX),
    /Kolone u listu „OSOBE“ nisu iste/
  );
});

test("duplirani email u fajlu označava oba reda", () => {
  const secondRow = [...validRow];
  secondRow[1] = "Ana";
  secondRow[5] = "mila@example.com";
  const rows = parseBulkImportFile(
    addRows(loadTemplate(), [validRow, secondRow]),
    XLSX
  );

  assert.equal(rows.length, 2);
  assert.ok(rows.every((row) => row.errors.includes("Email se ponavlja u fajlu.")));
});

test("maloletni član može biti unet bez sopstvenog emaila", () => {
  const minorRow = [...validRow];
  minorRow[4] = "15.04.2015";
  minorRow[5] = "";
  const [row] = parseBulkImportFile(addRows(loadTemplate(), [minorRow]), XLSX);

  assert.deepEqual(row.errors, []);
});

test("punoletnom članu email ostaje obavezan", () => {
  const adultRow = [...validRow];
  adultRow[5] = "";
  const [row] = parseBulkImportFile(addRows(loadTemplate(), [adultRow]), XLSX);

  assert.ok(row.errors.includes("Email je obavezan za punoletnog člana."));
});

test("roditelju ili staratelju email ostaje obavezan", () => {
  const guardianRow = [...validRow];
  guardianRow[0] = "Roditelj/staratelj";
  guardianRow[5] = "";
  const [row] = parseBulkImportFile(addRows(loadTemplate(), [guardianRow]), XLSX);

  assert.ok(row.errors.includes("Nedostaje email."));
});

test("neispravan datum se prijavljuje", () => {
  const invalidDateRow = [...validRow];
  invalidDateRow[4] = "31.02.2026";
  const [row] = parseBulkImportFile(
    addRows(loadTemplate(), [invalidDateRow]),
    XLSX
  );

  assert.equal(row.birthDate, "");
  assert.ok(row.errors.includes("Datum rođenja nije ispravan."));
});

test("broj pasoša bez datuma važenja se prijavljuje", () => {
  const incompletePassportRow = [...validRow];
  incompletePassportRow[13] = "";
  const [row] = parseBulkImportFile(
    addRows(loadTemplate(), [incompletePassportRow]),
    XLSX
  );

  assert.ok(
    row.errors.includes("Broj pasoša i datum važenja moraju biti uneti zajedno.")
  );
});
