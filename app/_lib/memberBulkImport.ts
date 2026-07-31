export type BulkImportRow = {
  rowNumber: number;
  kind: string;
  firstName: string;
  lastName: string;
  gender: string;
  birthDate: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  postalCode: string;
  country: string;
  jmbg: string;
  passportNumber: string;
  passportExpiryDate: string;
  errors: string[];
  skipReason: string | null;
};

type XlsxModule = typeof import("xlsx");

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(value: string) {
  return emailPattern.test(value.trim());
}

function valueToText(value: unknown) {
  return value == null ? "" : String(value).trim();
}

function isValidIsoDate(value: string) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

function valueToIsoDate(value: unknown, xlsx: XlsxModule) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return [
      value.getFullYear(),
      String(value.getMonth() + 1).padStart(2, "0"),
      String(value.getDate()).padStart(2, "0")
    ].join("-");
  }

  if (typeof value === "number") {
    const parsed = xlsx.SSF.parse_date_code(value);
    if (parsed) {
      return `${parsed.y}-${String(parsed.m).padStart(2, "0")}-${String(parsed.d).padStart(2, "0")}`;
    }
  }

  const text = valueToText(value);
  if (!text) return "";
  const localMatch = text.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$/);
  if (localMatch) {
    const isoDate = `${localMatch[3]}-${localMatch[2].padStart(2, "0")}-${localMatch[1].padStart(2, "0")}`;
    return isValidIsoDate(isoDate) ? isoDate : "";
  }
  return isValidIsoDate(text) ? text : "";
}

export function parseBulkImportFile(
  workbook: import("xlsx").WorkBook,
  xlsx: XlsxModule
) {
  const sheet = workbook.Sheets.OSOBE;
  if (!sheet) {
    throw new Error("Excel fajl nema obavezni list „OSOBE“.");
  }

  const rows = xlsx.utils.sheet_to_json<unknown[]>(sheet, {
    header: 1,
    defval: "",
    raw: true
  });
  const headers = (rows[4] ?? []).map((value) =>
    valueToText(value).replace(/\s*\*$/, "")
  );
  const expected = [
    "Vrsta osobe", "Ime", "Prezime", "Pol", "Datum rođenja", "Email",
    "Telefon", "Adresa", "Mesto", "Poštanski broj", "Država", "JMBG",
    "Broj pasoša", "Datum važenja pasoša", "PROVERA"
  ];
  if (expected.some((header, index) => headers[index] !== header)) {
    throw new Error("Kolone u listu „OSOBE“ nisu iste kao u preuzetom šablonu.");
  }

  const parsedRows: BulkImportRow[] = [];
  for (let index = 5; index < rows.length; index += 1) {
    const row = rows[index] ?? [];
    if (row.slice(0, 14).every((value) => valueToText(value) === "")) continue;

    const item: BulkImportRow = {
      rowNumber: index + 1,
      kind: valueToText(row[0]),
      firstName: valueToText(row[1]),
      lastName: valueToText(row[2]),
      gender: valueToText(row[3]),
      birthDate: valueToIsoDate(row[4], xlsx),
      email: valueToText(row[5]).toLowerCase(),
      phone: valueToText(row[6]),
      address: valueToText(row[7]),
      city: valueToText(row[8]),
      postalCode: valueToText(row[9]),
      country: valueToText(row[10]) || "Srbija",
      jmbg: valueToText(row[11]),
      passportNumber: valueToText(row[12]),
      passportExpiryDate: valueToIsoDate(row[13], xlsx),
      errors: [],
      skipReason: null
    };

    if (!["Član", "Roditelj/staratelj"].includes(item.kind)) {
      item.errors.push("Vrsta osobe mora biti „Član“ ili „Roditelj/staratelj“.");
    }
    if (!item.firstName) item.errors.push("Nedostaje ime.");
    if (!item.lastName) item.errors.push("Nedostaje prezime.");
    if (!item.email) item.errors.push("Nedostaje email.");
    if (item.gender && !["Muško", "Žensko"].includes(item.gender)) {
      item.errors.push("Pol mora biti „Muško“ ili „Žensko“.");
    }
    if (row[4] && !item.birthDate) item.errors.push("Datum rođenja nije ispravan.");
    if (item.email && !isValidEmail(item.email)) item.errors.push("Email nije ispravan.");
    if (item.jmbg && !/^\d{13}$/.test(item.jmbg)) item.errors.push("JMBG mora imati 13 cifara.");
    if (Boolean(item.passportNumber) !== Boolean(item.passportExpiryDate)) {
      item.errors.push("Broj pasoša i datum važenja moraju biti uneti zajedno.");
    }
    if (row[13] && !item.passportExpiryDate) {
      item.errors.push("Datum važenja pasoša nije ispravan.");
    }
    parsedRows.push(item);
  }

  const emailCounts = new Map<string, number>();
  parsedRows.forEach((row) => {
    if (row.email) emailCounts.set(row.email, (emailCounts.get(row.email) ?? 0) + 1);
  });
  parsedRows.forEach((row) => {
    if (row.email && (emailCounts.get(row.email) ?? 0) > 1) {
      row.errors.push("Email se ponavlja u fajlu.");
    }
  });
  return parsedRows;
}
