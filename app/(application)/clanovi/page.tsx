"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import * as XLSX from "xlsx";

import {
  UF_MEMBER_FORM,
  type UFMemberFormField,
  type UFMemberFormValues,
  type UFMemberGuardianField,
  type UFMemberGuardianLookupState,
  type UFMemberGuardianValues,
  type UFMemberLookupState,
  type UFMemberMembershipField,
  type UFMemberPersonField
} from "../../_components/UF_MEMBER_FORM";
import {
  getSupabaseClient,
  type Person,
  type Section,
  type Society,
  type SocietyMemberFunction
} from "../../_lib/supabaseClient";

type MemberListItem = {
  id: string;
  personId: string;
  firstName: string;
  lastName: string;
  email: string | null;
  phone: string | null;
  birthDate: string | null;
  status: string;
  startDate: string | null;
};

type FormMode = "create" | "edit";
type MembersView = "members" | "bulk-import" | "pending";

type BulkImportRow = {
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

type PendingImportCandidate = {
  id: string;
  profile: {
    first_name: string;
    last_name: string;
    email?: string | null;
    phone?: string | null;
  };
  source_row: number;
  source_file_name: string;
  created_at: string;
  member_invitation_status: string | null;
  guardian_invitation_status: string | null;
  invitation_last_saved_at: string | null;
  draft: Record<string, unknown>;
  missing_fields: string[];
};

type MemberAccessRole = "president" | "ur";

type MemberEditAccess = {
  role: MemberAccessRole;
  hiddenPersonFields: Partial<Record<UFMemberPersonField, boolean>>;
  readOnlyPersonFields: Partial<Record<UFMemberPersonField, boolean>>;
  readOnlyMembershipFields: Partial<Record<UFMemberMembershipField, boolean>>;
  readOnlyFunctions: boolean;
  readOnlySections: boolean;
};

type GuardianLookupMap = Record<
  "guardian1" | "guardian2",
  UFMemberGuardianLookupState
>;

const protectedFunctionNames = new Set(["Predsednik"]);
const unknownSaveErrorMessage =
  "Član trenutno nije sačuvan. Proverite podatke i pokušajte ponovo.";
const invalidEmailMessage = "Unesite ispravnu email adresu.";
const duplicateMemberMessage = "Ova osoba je već član ovog društva.";
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const pendingPersonalFields = [
  ["first_name", "Ime", "text"],
  ["last_name", "Prezime", "text"],
  ["gender", "Pol", "text"],
  ["birth_date", "Datum rođenja", "date"],
  ["email", "Email", "email"],
  ["phone", "Telefon", "tel"],
  ["shoe_size", "Broj obuće", "number"],
  ["address", "Adresa", "text"],
  ["city", "Mesto", "text"],
  ["postal_code", "Poštanski broj", "text"],
  ["country", "Država", "text"],
  ["jmbg", "JMBG", "text"],
  ["passport_number", "Broj pasoša", "text"],
  ["passport_expiry_date", "Važenje pasoša", "date"]
] as const;

function createInitialValues(): UFMemberFormValues {
  return {
    is_minor_member: false,
    first_name: "",
    last_name: "",
    gender: "",
    birth_date: "",
    address: "",
    city: "",
    postal_code: "",
    country: "Srbija",
    jmbg: "",
    passport_number: "",
    passport_expiry_date: "",
    parental_travel_consent: false,
    parental_travel_consent_valid_until: "",
    email: "",
    phone: "",
    shoe_size: "",
    status: "ACTIVE",
    start_date: "",
    membership_fee_required: true,
    membership_fee_amount: "0",
    guardian1: {
      first_name: "",
      last_name: "",
      email: "",
      phone: ""
    },
    guardian2: {
      first_name: "",
      last_name: "",
      email: "",
      phone: ""
    },
    showGuardian2: false,
    selectedFunctionIds: [],
    selectedSectionIds: []
  };
}

function normalizeOptional(value: string) {
  const trimmedValue = value.trim();

  return trimmedValue.length > 0 ?trimmedValue : null;
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase();
}

function parseSerbianDate(value: string) {
  const normalized = value.trim();
  const match =
    normalized.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})\.?$/) ??
    normalized.match(/^(\d{2})(\d{2})(\d{4})$/);
  if (!match) return null;
  const day = Number(match[1]);
  const month = Number(match[2]);
  const year = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return null;
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function normalizeSearch(value: string) {
  return value.trim().toLowerCase();
}

function isValidEmail(value: string) {
  return emailPattern.test(value.trim());
}

function excelValueToText(value: unknown) {
  return value == null ? "" : String(value).trim();
}

function excelValueToIsoDate(value: unknown) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return [
      value.getFullYear(),
      String(value.getMonth() + 1).padStart(2, "0"),
      String(value.getDate()).padStart(2, "0")
    ].join("-");
  }

  if (typeof value === "number") {
    const parsed = XLSX.SSF.parse_date_code(value);
    if (parsed) {
      return `${parsed.y}-${String(parsed.m).padStart(2, "0")}-${String(parsed.d).padStart(2, "0")}`;
    }
  }

  const text = excelValueToText(value);
  if (!text) return "";
  const localMatch = text.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$/);
  if (localMatch) {
    return `${localMatch[3]}-${localMatch[2].padStart(2, "0")}-${localMatch[1].padStart(2, "0")}`;
  }
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : "";
}

function parseBulkImportFile(workbook: XLSX.WorkBook) {
  const sheet = workbook.Sheets.OSOBE;
  if (!sheet) {
    throw new Error("Excel fajl nema obavezni list „OSOBE“.");
  }

  const rows = XLSX.utils.sheet_to_json<unknown[]>(sheet, {
    header: 1,
    defval: "",
    raw: true
  });
  const headers = (rows[4] ?? []).map((value) =>
    excelValueToText(value).replace(/\s*\*$/, "")
  );
  const expected = [
    "Vrsta osobe", "Ime", "Prezime", "Pol", "Datum rođenja", "Email",
    "Telefon", "Adresa", "Mesto", "Poštanski broj", "Država", "JMBG",
    "Broj pasoša", "Datum važenja pasoša", "PROVERA"
  ];
  if (expected.some((header, index) => headers[index] !== header)) {
    throw new Error(
      "Kolone u listu „OSOBE“ nisu iste kao u preuzetom šablonu."
    );
  }

  const parsedRows: BulkImportRow[] = [];
  for (let index = 5; index < rows.length; index += 1) {
    const row = rows[index] ?? [];
    if (row.slice(0, 14).every((value) => excelValueToText(value) === "")) continue;

    const item: BulkImportRow = {
      rowNumber: index + 1,
      kind: excelValueToText(row[0]),
      firstName: excelValueToText(row[1]),
      lastName: excelValueToText(row[2]),
      gender: excelValueToText(row[3]),
      birthDate: excelValueToIsoDate(row[4]),
      email: normalizeEmail(excelValueToText(row[5])),
      phone: excelValueToText(row[6]),
      address: excelValueToText(row[7]),
      city: excelValueToText(row[8]),
      postalCode: excelValueToText(row[9]),
      country: excelValueToText(row[10]) || "Srbija",
      jmbg: excelValueToText(row[11]),
      passportNumber: excelValueToText(row[12]),
      passportExpiryDate: excelValueToIsoDate(row[13]),
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

function getInvitationStatusLabel(status: string | null) {
  switch (status) {
    case "INVITED": return "Link poslat";
    case "OPENED": return "Link otvoren";
    case "IN_PROGRESS": return "Dopuna u toku";
    case "SUBMITTED": return "Podaci poslati";
    case "EXPIRED": return "Link istekao";
    case "CANCELLED": return "Link otkazan";
    default: return "Link nije poslat";
  }
}

function createIdleMemberLookup(): UFMemberLookupState {
  return {
    status: "idle"
  };
}

function createIdleGuardianLookup(): UFMemberGuardianLookupState {
  return {
    status: "idle"
  };
}

function createGuardianLookups(): GuardianLookupMap {
  return {
    guardian1: createIdleGuardianLookup(),
    guardian2: createIdleGuardianLookup()
  };
}

function getReadOnlyPersonFields(person: Person) {
  return {
    first_name: Boolean(person.first_name),
    last_name: Boolean(person.last_name),
    gender: Boolean(person.gender),
    birth_date: Boolean(person.birth_date),
    address: Boolean(person.address),
    city: Boolean(person.city),
    postal_code: Boolean(person.postal_code),
    country: Boolean(person.country),
    jmbg: Boolean(person.jmbg),
    passport_number: Boolean(person.passport_number),
    passport_expiry_date: Boolean(person.passport_expiry_date),
    parental_travel_consent: person.parental_travel_consent,
    parental_travel_consent_valid_until: Boolean(person.parental_travel_consent_valid_until),
    email: false,
    phone: Boolean(person.phone),
    shoe_size: Boolean(person.shoe_size)
  };
}

function getReadOnlyGuardianFields(person: Person) {
  return {
    first_name: Boolean(person.first_name),
    last_name: Boolean(person.last_name),
    email: false,
    phone: Boolean(person.phone)
  };
}

function getValueForInput(value: string | null) {
  return value ?? "";
}

function applyPersonToValues(
  currentValues: UFMemberFormValues,
  person: Person
): UFMemberFormValues {
  return {
    ...currentValues,
    first_name: getValueForInput(person.first_name),
    last_name: getValueForInput(person.last_name),
    gender:
      person.gender === "Muško" || person.gender === "Žensko"
        ?person.gender
        : currentValues.gender,
    birth_date: getValueForInput(person.birth_date),
    address: getValueForInput(person.address),
    city: getValueForInput(person.city),
    postal_code: getValueForInput(person.postal_code),
    country: getValueForInput(person.country) || "Srbija",
    jmbg: getValueForInput(person.jmbg),
    passport_number: getValueForInput(person.passport_number),
    passport_expiry_date: getValueForInput(person.passport_expiry_date),
    parental_travel_consent: person.parental_travel_consent,
    parental_travel_consent_valid_until: getValueForInput(person.parental_travel_consent_valid_until),
    email: getValueForInput(person.email),
    phone: getValueForInput(person.phone),
    shoe_size: person.shoe_size ? String(person.shoe_size) : ""
  };
}

function applyPersonToGuardian(
  guardian: UFMemberGuardianValues,
  person: Person
): UFMemberGuardianValues {
  return {
    ...guardian,
    first_name: getValueForInput(person.first_name),
    last_name: getValueForInput(person.last_name),
    email: getValueForInput(person.email),
    phone: getValueForInput(person.phone)
  };
}

function isSupabaseLikeError(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    ("code" in error || "details" in error || "hint" in error)
  );
}

function isUnder18(birthDate: string) {
  if (!birthDate) {
    return false;
  }

  const parsedDate = new Date(`${birthDate}T00:00:00`);

  if (Number.isNaN(parsedDate.getTime())) {
    return false;
  }

  const today = new Date();
  let age = today.getFullYear() - parsedDate.getFullYear();
  const monthDifference = today.getMonth() - parsedDate.getMonth();

  if (
    monthDifference < 0 ||
    (monthDifference === 0 && today.getDate() < parsedDate.getDate())
  ) {
    age -= 1;
  }

  return age < 18;
}

function getMinorBirthDateError(birthDate: string) {
  if (!birthDate) {
    return "Datum rođenja je obavezan za maloletnog člana.";
  }

  if (!isUnder18(birthDate)) {
    return "Izabran je tok za maloletnog člana, ali datum rođenja ne odgovara maloletnoj osobi.";
  }

  return null;
}

function hasGuardianValues(guardian: UFMemberGuardianValues) {
  return Object.values(guardian).some((value) => value.trim().length > 0);
}

function getErrorMessage(error: unknown) {
  if (isSupabaseLikeError(error)) {
    const message =
      "message" in error && typeof error.message === "string"
        ?error.message.toLowerCase()
        : "";

    if (message.includes("row-level security")) {
      return "Nemate dozvolu za ovu izmenu.";
    }

    if (
      message.includes("duplicate key") ||
      message.includes("unique constraint")
    ) {
      return "Već postoji zapis sa istim jedinstvenim podatkom.";
    }

    return unknownSaveErrorMessage;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return unknownSaveErrorMessage;
}

function getDetailedErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (isSupabaseLikeError(error)) {
    const parts: string[] = [];

    if ("message" in error && typeof error.message === "string") {
      parts.push(error.message);
    }

    if ("details" in error && typeof error.details === "string") {
      parts.push(error.details);
    }

    if ("hint" in error && typeof error.hint === "string") {
      parts.push(error.hint);
    }

    if ("code" in error && typeof error.code === "string") {
      parts.push(`Kod: ${error.code}`);
    }

    return parts.filter(Boolean).join(" ");
  }

  return "Nepoznata greška.";
}

function withStepError(message: string, error: unknown) {
  return new Error(`${message} ${getDetailedErrorMessage(error)}`);
}


function validateGuardianInputForSave(
  guardian: UFMemberGuardianValues,
  label: "Roditelj/staratelj 1" | "Roditelj/staratelj 2"
) {
  if (!guardian.email.trim()) {
    throw new Error(`${label}: email je obavezan.`);
  }

  if (!isValidEmail(guardian.email)) {
    throw new Error(`${label}: unesite ispravnu email adresu.`);
  }

  if (!guardian.first_name.trim()) {
    throw new Error(`${label}: ime je obavezno.`);
  }

  if (!guardian.last_name.trim()) {
    throw new Error(`${label}: prezime je obavezno.`);
  }

  if (!guardian.phone.trim()) {
    throw new Error(`${label}: telefon je obavezan.`);
  }
}

function getMembershipFeeAmount(values: UFMemberFormValues) {
  if (!values.membership_fee_required) {
    return null;
  }

  const parsedAmount = Number(values.membership_fee_amount);

  return Number.isNaN(parsedAmount) ? null : parsedAmount;
}

function buildPersonUpdateFromValues(values: UFMemberFormValues) {
  return {
    first_name: values.first_name.trim(),
    last_name: values.last_name.trim(),
    gender: normalizeOptional(values.gender),
    address: normalizeOptional(values.address),
    city: normalizeOptional(values.city),
    postal_code: normalizeOptional(values.postal_code),
    country: normalizeOptional(values.country) ?? "Srbija",
    jmbg: normalizeOptional(values.jmbg),
    passport_number: normalizeOptional(values.passport_number),
    passport_expiry_date: normalizeOptional(values.passport_expiry_date),
    parental_travel_consent: values.parental_travel_consent,
    parental_travel_consent_valid_until: values.parental_travel_consent ? normalizeOptional(values.parental_travel_consent_valid_until) : null,
    email: values.email.trim() ?normalizeEmail(values.email) : null,
    phone: normalizeOptional(values.phone),
    shoe_size: values.shoe_size ? Number(values.shoe_size) : null,
    birth_date: normalizeOptional(values.birth_date)
  };
}

function getMemberEditAccess(role: MemberAccessRole): MemberEditAccess {
  if (role === "president") {
    return {
      role,
      hiddenPersonFields: {},
      readOnlyPersonFields: {},
      readOnlyMembershipFields: {},
      readOnlyFunctions: false,
      readOnlySections: false
    };
  }

  return {
    role,
    hiddenPersonFields: {
      gender: true,
      birth_date: true,
      address: true,
      city: true,
      postal_code: true,
      country: true,
      jmbg: true,
      passport_number: true,
      passport_expiry_date: true,
      parental_travel_consent: true,
      parental_travel_consent_valid_until: true
    },
    readOnlyPersonFields: {
      first_name: true,
      last_name: true,
      email: true,
      phone: true
    },
    readOnlyMembershipFields: {
      status: true,
      start_date: true,
      membership_fee_required: true,
      membership_fee_amount: true
    },
    readOnlyFunctions: true,
    readOnlySections: true
  };
}

export default function ClanoviPage() {
  const [society, setSociety] = useState<Society | null>(null);
  const [members, setMembers] = useState<MemberListItem[]>([]);
  const [functionOptions, setFunctionOptions] = useState<
    SocietyMemberFunction[]
  >([]);
  const [sectionOptions, setSectionOptions] = useState<Section[]>([]);
  const [values, setValues] = useState<UFMemberFormValues>(() =>
    createInitialValues()
  );
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [activeView, setActiveView] = useState<MembersView>("members");
  const [selectedImportFile, setSelectedImportFile] = useState<File | null>(null);
  const [importRows, setImportRows] = useState<BulkImportRow[]>([]);
  const [isReadingImport, setIsReadingImport] = useState(false);
  const [isImporting, setIsImporting] = useState(false);
  const [importError, setImportError] = useState("");
  const [pendingImports, setPendingImports] = useState<PendingImportCandidate[]>([]);
  const [pendingStartDates, setPendingStartDates] = useState<Record<string, string>>({});
  const [pendingPhones, setPendingPhones] = useState<Record<string, string>>({});
  const [approvingImportId, setApprovingImportId] = useState<string | null>(null);
  const [rejectingImportId, setRejectingImportId] = useState<string | null>(null);
  const [sendingInvitationId, setSendingInvitationId] = useState<string | null>(null);
  const [editingPendingId, setEditingPendingId] = useState<string | null>(null);
  const [presidentDrafts, setPresidentDrafts] = useState<Record<string, Record<string, unknown>>>({});
  const [pendingGuardianLookups, setPendingGuardianLookups] = useState<
    Record<string, UFMemberGuardianLookupState>
  >({});
  const [savingPendingId, setSavingPendingId] = useState<string | null>(null);
  const [creatingTestLinkId, setCreatingTestLinkId] = useState<string | null>(null);
  const [localTestLinks, setLocalTestLinks] = useState<Record<string, string>>({});
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [memberSearch, setMemberSearch] = useState("");
  const [selectedSearchMemberId, setSelectedSearchMemberId] = useState<
    string | null
  >(null);
  const [formMode, setFormMode] = useState<FormMode>("create");
  const [editingMemberId, setEditingMemberId] = useState<string | null>(null);
  const [editingPersonId, setEditingPersonId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [pageAccess, setPageAccess] = useState({
    can_create: false,
    can_manage_functions: false,
    can_manage_sections: false,
    can_bulk_import: false
  });
  const [memberLookup, setMemberLookup] = useState<UFMemberLookupState>(() =>
    createIdleMemberLookup()
  );
  const [guardianLookups, setGuardianLookups] = useState<GuardianLookupMap>(() =>
    createGuardianLookups()
  );

  const assignableFunctionIds = useMemo(
    () =>
      new Set(
        functionOptions
          .filter((memberFunction) => memberFunction.is_active)
          .filter((memberFunction) => !protectedFunctionNames.has(memberFunction.name))
          .map((memberFunction) => memberFunction.id)
      ),
    [functionOptions]
  );
  const [currentAccess, setCurrentAccess] = useState<MemberEditAccess>(() =>
    getMemberEditAccess("ur")
  );
  const memberSearchResults = useMemo(() => {
    const normalizedQuery = normalizeSearch(memberSearch);

    if (normalizedQuery.length < 2) {
      return [];
    }

    return members
      .filter((member) => {
        const searchable = [
          member.firstName,
          member.lastName,
          member.phone ?? "",
          member.email ?? ""
        ]
          .join(" ")
          .toLowerCase();

        return searchable.includes(normalizedQuery);
      })
      .slice(0, 20);
  }, [memberSearch, members]);
  const displayedMembers = useMemo(
    () => {
      if (selectedSearchMemberId) {
        return members.filter((member) => member.id === selectedSearchMemberId);
      }

      const normalizedQuery = normalizeSearch(memberSearch);
      if (!normalizedQuery) return members;

      return members.filter((member) =>
        [member.firstName, member.lastName, member.email ?? "", member.phone ?? ""]
          .join(" ")
          .toLowerCase()
          .includes(normalizedQuery)
      );
    },
    [memberSearch, members, selectedSearchMemberId]
  );

  const loadPageData = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();

      const { data: pageData, error: pageError } =
        await supabase.rpc("auth_get_members_page");
      if (pageError) throw pageError;

      const activeSociety = pageData?.society ?? null;
      setSociety(activeSociety);

      if (!activeSociety) {
        setMembers([]);
        setFunctionOptions([]);
        setSectionOptions([]);
        setErrorMessage("Nema aktivnog društva za unos članova.");
        return;
      }

      setFunctionOptions(pageData?.functions ?? []);
      setSectionOptions(pageData?.sections ?? []);
      const access = pageData?.access ?? {
        can_create: false,
        can_manage_functions: false,
        can_manage_sections: false
      };
      const {
        data: canBulkImport,
        error: canBulkImportError
      } = await supabase.rpc("auth_can_bulk_import_members", {
        p_society_id: activeSociety.id
      });
      setPageAccess({
        ...access,
        can_bulk_import: canBulkImportError ? false : Boolean(canBulkImport)
      });
      setMembers(
        (pageData?.members ?? []).map((member) => ({
          id: member.id,
          personId: member.person_id,
          firstName: member.first_name,
          lastName: member.last_name,
          email: member.email,
          phone: member.phone,
          birthDate: member.birth_date,
          status: member.status,
          startDate: member.start_date
        }))
      );
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadPageData();
  }, [loadPageData]);

  function handleOpenForm() {
    setActiveView("members");
    setCurrentAccess({
      ...getMemberEditAccess("president"),
      readOnlyFunctions: !pageAccess.can_manage_functions,
      readOnlySections: !pageAccess.can_manage_sections
    });
    setValues(createInitialValues());
    setMemberLookup(createIdleMemberLookup());
    setGuardianLookups(createGuardianLookups());
    setFormMode("create");
    setEditingMemberId(null);
    setEditingPersonId(null);
    setIsFormOpen(true);
    setMessage("");
    setErrorMessage("");
  }

  function handleOpenSearch() {
    setIsSearchOpen(true);
    setMemberSearch("");
    setMessage("");
    setErrorMessage("");
  }

  function handleCloseSearch() {
    setIsSearchOpen(false);
    setMemberSearch("");
  }

  function handleSelectSearchMember(memberId: string) {
    setSelectedSearchMemberId(memberId);
    setIsSearchOpen(false);
    setMemberSearch("");
  }

  function handleClearSearchSelection() {
    setSelectedSearchMemberId(null);
  }

  function handleCancel() {
    setValues(createInitialValues());
    setMemberLookup(createIdleMemberLookup());
    setGuardianLookups(createGuardianLookups());
    setFormMode("create");
    setEditingMemberId(null);
    setEditingPersonId(null);
    setIsFormOpen(false);
    setMessage("");
    setErrorMessage("");
  }

  function handleFieldChange(
    field: UFMemberFormField | "showGuardian2" | "is_minor_member",
    value: string | boolean
  ) {
    if (field === "is_minor_member" && formMode === "create") {
      setValues({
        ...createInitialValues(),
        is_minor_member: Boolean(value)
      });
      setMemberLookup(createIdleMemberLookup());
      setGuardianLookups(createGuardianLookups());
      setMessage("");
      setErrorMessage("");
      return;
    }

    if (field === "email" && formMode === "create") {
      setValues({
        ...createInitialValues(),
        is_minor_member: values.is_minor_member,
        email: typeof value === "string" ?value : ""
      });
      setMemberLookup(createIdleMemberLookup());
      setGuardianLookups(createGuardianLookups());
      setMessage("");
      setErrorMessage("");
      return;
    }

    setValues((currentValues) => ({
      ...currentValues,
      [field]: value
    }));
    setMessage("");
    setErrorMessage("");
  }

  function handleGuardianFieldChange(
    guardian: "guardian1" | "guardian2",
    field: UFMemberGuardianField,
    value: string
  ) {
    if (field === "email") {
      setValues((currentValues) => ({
        ...currentValues,
        [guardian]: {
          first_name: "",
          last_name: "",
          email: value,
          phone: ""
        }
      }));
      setGuardianLookups((currentLookups) => ({
        ...currentLookups,
        [guardian]: createIdleGuardianLookup()
      }));
      setMessage("");
      setErrorMessage("");
      return;
    }

    setValues((currentValues) => ({
      ...currentValues,
      [guardian]: {
        ...currentValues[guardian],
        [field]: value
      }
    }));
    setMessage("");
    setErrorMessage("");
  }

  function handleAddSecondGuardian() {
    setValues((currentValues) => ({
      ...currentValues,
      showGuardian2: true
    }));
    setMessage("");
    setErrorMessage("");
  }

  function handleRemoveSecondGuardian() {
    setValues((currentValues) => ({
      ...currentValues,
      guardian2: {
        first_name: "",
        last_name: "",
        email: "",
        phone: ""
      },
      showGuardian2: false
    }));
    setGuardianLookups((currentLookups) => ({
      ...currentLookups,
      guardian2: createIdleGuardianLookup()
    }));
    setMessage("");
    setErrorMessage("");
  }

  function handleFunctionToggle(functionId: string) {
    setValues((currentValues) => {
      const selectedFunctionIds = currentValues.selectedFunctionIds.includes(
        functionId
      )
        ?currentValues.selectedFunctionIds.filter((id) => id !== functionId)
        : [...currentValues.selectedFunctionIds, functionId];

      return {
        ...currentValues,
        selectedFunctionIds
      };
    });
    setMessage("");
    setErrorMessage("");
  }

  function handleSectionToggle(sectionId: string) {
    setValues((currentValues) => {
      const selectedSectionIds = currentValues.selectedSectionIds.includes(sectionId)
        ?currentValues.selectedSectionIds.filter((id) => id !== sectionId)
        : [...currentValues.selectedSectionIds, sectionId];

      return {
        ...currentValues,
        selectedSectionIds
      };
    });
    setMessage("");
    setErrorMessage("");
  }

  async function lookupPerson(identifiers: {
    email?: string;
    jmbg?: string;
    passportNumber?: string;
  }) {
    if (!society) {
      throw new Error("Aktivno društvo nije dostupno.");
    }
    const { data, error } = await getSupabaseClient().rpc(
      "auth_lookup_person_for_member",
      {
        p_society_id: society.id,
        p_email: identifiers.email ? normalizeEmail(identifiers.email) : null,
        p_jmbg: identifiers.jmbg ?? null,
        p_passport_number: identifiers.passportNumber ?? null
      }
    );
    if (error || !data) {
      throw error ?? new Error("Provera osobe trenutno nije dostupna.");
    }
    return data;
  }

  async function handleMemberEmailBlur() {
    if (!society) {
      return;
    }

    const email = values.email.trim();

    if (!email || !isValidEmail(email)) {
      setMemberLookup({
        status: "invalid",
        message: invalidEmailMessage
      });
      return;
    }

    setMemberLookup({ status: "checking" });
    setMessage("");
    setErrorMessage("");

    try {
      const lookup = await lookupPerson({ email });
      const existingPerson = lookup.person;

      if (!existingPerson) {
        setMemberLookup({
          status: "not_found",
          message: "Osoba nije pronadjena. Unesite podatke za novu osobu."
        });
        return;
      }

      setValues((currentValues) => applyPersonToValues(currentValues, existingPerson));

      if (lookup.already_member) {
        setMemberLookup({
          status: "duplicate",
          message: duplicateMemberMessage,
          person: existingPerson,
          readOnlyFields: getReadOnlyPersonFields(existingPerson)
        });
        return;
      }

      setMemberLookup({
        status: "found",
        message: "Osoba je pronadjena i moze biti dodata kao clan ovog drustva.",
        person: existingPerson,
        readOnlyFields: getReadOnlyPersonFields(existingPerson)
      });
    } catch (error) {
      setMemberLookup({
        status: "error",
        message: getErrorMessage(error)
      });
    }
  }

  async function handleGuardianEmailBlur(guardian: "guardian1" | "guardian2") {
    const email = values[guardian].email.trim();

    if (!email || !isValidEmail(email)) {
      setGuardianLookups((currentLookups) => ({
        ...currentLookups,
        [guardian]: {
          status: "invalid",
          message: invalidEmailMessage
        }
      }));
      return;
    }

    setGuardianLookups((currentLookups) => ({
      ...currentLookups,
      [guardian]: { status: "checking" }
    }));
    setMessage("");
    setErrorMessage("");

    try {
      const existingPerson = (await lookupPerson({ email })).person;

      if (!existingPerson) {
        setGuardianLookups((currentLookups) => ({
          ...currentLookups,
          [guardian]: {
            status: "not_found",
            message: "Roditelj/staratelj nije pronadjen. Unesite podatke."
          }
        }));
        return;
      }

      setValues((currentValues) => ({
        ...currentValues,
        [guardian]: applyPersonToGuardian(currentValues[guardian], existingPerson)
      }));
      setGuardianLookups((currentLookups) => ({
        ...currentLookups,
        [guardian]: {
          status: "found",
          message: "Roditelj/staratelj je pronadjen i bice povezan sa clanom.",
          person: existingPerson,
          readOnlyFields: getReadOnlyGuardianFields(existingPerson)
        }
      }));
    } catch (error) {
      setGuardianLookups((currentLookups) => ({
        ...currentLookups,
        [guardian]: {
          status: "error",
          message: getErrorMessage(error)
        }
      }));
    }
  }

  async function handleIdentifierBlur(field: "jmbg" | "passport_number") {
    const value = values[field].trim();

    if (!value) {
      return;
    }

    try {
      const data = (
        await lookupPerson(
          field === "jmbg" ? { jmbg: value } : { passportNumber: value }
        )
      ).person;

      if (data && data.id !== memberLookup.person?.id) {
        setErrorMessage(
          field === "jmbg"
            ?"Osoba sa ovim JMBG vec postoji u sistemu."
            : "Osoba sa ovim brojem pasosa vec postoji u sistemu."
        );
      }
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    }
  }

  async function handleOpenEditMember(memberId: string) {
    setIsSubmitting(true);
    setMessage("");
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();
      const { data: detail, error: detailError } = await supabase.rpc(
        "auth_get_member_detail",
        { p_society_member_id: memberId }
      );
      if (detailError || !detail) {
        throw detailError ?? new Error("Detalj člana nije dostupan.");
      }

      setCurrentAccess({
        role: detail.access.can_edit_basic ? "president" : "ur",
        hiddenPersonFields: detail.access.can_view_sensitive ? {} : {
          gender: true,
          birth_date: true,
          address: true,
          city: true,
          postal_code: true,
          country: true,
          jmbg: true,
          passport_number: true,
          passport_expiry_date: true,
          parental_travel_consent: true,
          parental_travel_consent_valid_until: true
        },
        readOnlyPersonFields: detail.access.can_edit_basic ? {} : {
          first_name: true,
          last_name: true,
          email: true,
          phone: true
        },
        readOnlyMembershipFields: {
          status: !detail.access.can_change_status,
          start_date: !detail.access.can_edit_basic,
          membership_fee_required: true,
          membership_fee_amount: true
        },
        readOnlyFunctions: !detail.access.can_manage_functions,
        readOnlySections: !detail.access.can_manage_sections
      });

      const memberRow = detail.member;
      const personRow = detail.person;
      const primaryGuardianPerson =
        detail.guardians.find((guardian) => guardian.link.is_primary)?.person ?? null;
      const secondaryGuardianPerson =
        detail.guardians.find((guardian) => !guardian.link.is_primary)?.person ?? null;
      const nextValues = applyPersonToValues(createInitialValues(), personRow);

      setValues({
        ...nextValues,
        is_minor_member: Boolean(primaryGuardianPerson) || isUnder18(nextValues.birth_date),
        status: memberRow.status === "INACTIVE" ?"INACTIVE" : "ACTIVE",
        start_date: getValueForInput(memberRow.start_date),
        membership_fee_required: memberRow.membership_fee_required,
        membership_fee_amount:
          memberRow.membership_fee_amount === null
            ?"0"
            : String(memberRow.membership_fee_amount),
        guardian1: primaryGuardianPerson
          ?applyPersonToGuardian(createInitialValues().guardian1, primaryGuardianPerson)
          : createInitialValues().guardian1,
        guardian2: secondaryGuardianPerson
          ?applyPersonToGuardian(createInitialValues().guardian2, secondaryGuardianPerson)
          : createInitialValues().guardian2,
        showGuardian2: Boolean(secondaryGuardianPerson),
        selectedFunctionIds: detail.function_ids,
        selectedSectionIds: detail.section_ids
      });
      setMemberLookup({
        status: "found",
        person: personRow,
        message: "Podaci člana su učitani za izmenu."
      });
      setGuardianLookups({
        guardian1: primaryGuardianPerson
          ?{
              status: "found",
              person: primaryGuardianPerson,
              message: "Roditelj/staratelj je učitan."
            }
          : createIdleGuardianLookup(),
        guardian2: secondaryGuardianPerson
          ?{
              status: "found",
              person: secondaryGuardianPerson,
              message: "Roditelj/staratelj 2 je učitan."
            }
          : createIdleGuardianLookup()
      });
      setEditingMemberId(memberRow.id);
      setEditingPersonId(memberRow.person_id);
      setFormMode("edit");
      setIsFormOpen(true);
    } catch (error) {
      setErrorMessage(
        `Podaci člana nisu učitani. ${getDetailedErrorMessage(error)}`
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSubmitEditMember() {
    if (!society || !editingMemberId || !editingPersonId) {
      setErrorMessage("Član nije učitan za izmenu.");
      return;
    }

    setIsSubmitting(true);
    setMessage("");
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();
      const minor = values.is_minor_member;

      if (minor) {
        const minorBirthDateError = getMinorBirthDateError(values.birth_date);

        if (minorBirthDateError) {
          throw new Error(minorBirthDateError);
        }

        validateGuardianInputForSave(values.guardian1, "Roditelj/staratelj 1");

        if (values.showGuardian2 || hasGuardianValues(values.guardian2)) {
          validateGuardianInputForSave(values.guardian2, "Roditelj/staratelj 2");

          if (normalizeEmail(values.guardian1.email) === normalizeEmail(values.guardian2.email)) {
            throw new Error("Roditelji/staratelji moraju imati različite email adrese.");
          }
        }
      }

      const profile = {
        ...buildPersonUpdateFromValues(values),
        status: values.status,
        start_date: values.start_date,
        membership_fee_required: values.membership_fee_required,
        membership_fee_amount: getMembershipFeeAmount(values)
      };
      const guardians = minor
        ? [
            {
              first_name: values.guardian1.first_name.trim(),
              last_name: values.guardian1.last_name.trim(),
              email: normalizeEmail(values.guardian1.email),
              phone: values.guardian1.phone.trim(),
              is_primary: true
            },
            ...(values.showGuardian2 || hasGuardianValues(values.guardian2)
              ? [{
                  first_name: values.guardian2.first_name.trim(),
                  last_name: values.guardian2.last_name.trim(),
                  email: normalizeEmail(values.guardian2.email),
                  phone: values.guardian2.phone.trim(),
                  is_primary: false
                }]
              : [])
          ]
        : [];
      const { error: updateError } = await supabase.rpc(
        "auth_update_society_member",
        {
          p_society_member_id: editingMemberId,
          p_profile: profile,
          p_guardians: guardians,
          p_function_ids: values.selectedFunctionIds,
          p_section_ids: values.selectedSectionIds
        }
      );

      if (updateError) {
        throw withStepError("Izmene člana nisu sačuvane.", updateError);
      }

      await loadPageData();
      setIsFormOpen(false);
      setFormMode("create");
      setEditingMemberId(null);
      setEditingPersonId(null);
      setValues(createInitialValues());
      setMemberLookup(createIdleMemberLookup());
      setGuardianLookups(createGuardianLookups());
      setMessage("Izmene člana su sačuvane.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSubmitMember() {
    if (!society) {
      setErrorMessage("Nema aktivnog društva za unos članova.");
      return;
    }

    setIsSubmitting(true);
    setMessage("");
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();
      const minor = values.is_minor_member;

      if (minor) {
        const minorBirthDateError = getMinorBirthDateError(values.birth_date);
        if (minorBirthDateError) throw new Error(minorBirthDateError);
        validateGuardianInputForSave(
          values.guardian1,
          "Roditelj/staratelj 1"
        );
        if (values.showGuardian2 || hasGuardianValues(values.guardian2)) {
          validateGuardianInputForSave(
            values.guardian2,
            "Roditelj/staratelj 2"
          );
          if (
            normalizeEmail(values.guardian1.email) ===
            normalizeEmail(values.guardian2.email)
          ) {
            throw new Error(
              "Roditelji/staratelji moraju imati različite email adrese."
            );
          }
        }
      }

      const profile = {
        ...buildPersonUpdateFromValues(values),
        status: values.status,
        start_date: values.start_date,
        membership_fee_required: values.membership_fee_required,
        membership_fee_amount: getMembershipFeeAmount(values)
      };
      const guardians = minor
        ? [
            {
              first_name: values.guardian1.first_name.trim(),
              last_name: values.guardian1.last_name.trim(),
              email: normalizeEmail(values.guardian1.email),
              phone: values.guardian1.phone.trim(),
              is_primary: true
            },
            ...(values.showGuardian2 || hasGuardianValues(values.guardian2)
              ? [{
                  first_name: values.guardian2.first_name.trim(),
                  last_name: values.guardian2.last_name.trim(),
                  email: normalizeEmail(values.guardian2.email),
                  phone: values.guardian2.phone.trim(),
                  is_primary: false
                }]
              : [])
          ]
        : [];
      const { data: createdMember, error: createError } = await supabase.rpc(
        "auth_create_society_member",
        {
          p_society_id: society.id,
          p_profile: profile,
          p_guardians: guardians,
          p_function_ids: values.selectedFunctionIds,
          p_section_ids: values.selectedSectionIds
        }
      );
      if (createError) {
        throw withStepError("Član nije kreiran.", createError);
      }

      await loadPageData();
      setValues(createInitialValues());
      setIsFormOpen(false);
      setMessage(
        createdMember?.reused_person
          ? "Postojeća osoba je uspešno dodata u ovo društvo."
          : "Član je uspešno dodat."
      );
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleImportFile(file: File | null) {
    setSelectedImportFile(file);
    setImportRows([]);
    setImportError("");
    if (!file) return;

    setIsReadingImport(true);
    try {
      const workbook = XLSX.read(await file.arrayBuffer(), {
        type: "array",
        cellDates: true
      });
      const parsedRows = parseBulkImportFile(workbook);
      if (parsedRows.length === 0) {
        throw new Error("U listu „OSOBE“ nema popunjenih redova.");
      }

      let currentPendingImports = pendingImports;
      if (society) {
        const { data, error } = await (getSupabaseClient().rpc as any)(
          "auth_get_pending_member_imports",
          { p_society_id: society.id }
        );
        if (error) throw error;
        currentPendingImports = (data ?? []) as PendingImportCandidate[];
        setPendingImports(currentPendingImports);
      }
      const pendingEmails = new Set(
        currentPendingImports
          .map((candidate) => normalizeEmail(candidate.profile.email ?? ""))
          .filter(Boolean)
      );

      for (let start = 0; start < parsedRows.length; start += 10) {
        const batch = parsedRows.slice(start, start + 10);
        await Promise.all(batch.map(async (row) => {
          if (!row.email || !isValidEmail(row.email)) return;
          if (pendingEmails.has(row.email)) {
            row.skipReason =
              "Email već postoji među članovima koji čekaju odobrenje.";
            return;
          }
          const lookup = await lookupPerson({ email: row.email });
          if (lookup.person) {
            row.skipReason = lookup.already_member
              ? "Email već pripada članu ovog društva."
              : "Email već postoji u bazi osoba.";
          }
        }));
      }
      setImportRows([...parsedRows]);
    } catch (error) {
      setImportError(getErrorMessage(error));
    } finally {
      setIsReadingImport(false);
    }
  }

  async function handleConfirmBulkImport() {
    const rowsForImport = importRows.filter((row) => !row.skipReason);
    if (
      !society ||
      !selectedImportFile ||
      rowsForImport.length === 0 ||
      rowsForImport.some((row) => row.errors.length > 0)
    ) {
      return;
    }

    setIsImporting(true);
    setImportError("");
    setMessage("");
    try {
      const supabase = getSupabaseClient();
      const { data: preparedCount, error } = await (supabase.rpc as any)(
        "auth_prepare_bulk_member_import",
        {
          p_society_id: society.id,
          p_file_name: selectedImportFile.name,
          p_rows: rowsForImport.map((row) => ({
            row_number: row.rowNumber,
            person_kind: row.kind,
            first_name: row.firstName,
            last_name: row.lastName,
            gender: row.gender || null,
            birth_date: row.birthDate || null,
            email: row.email || null,
            phone: row.phone || null,
            address: row.address || null,
            city: row.city || null,
            postal_code: row.postalCode || null,
            country: row.country,
            jmbg: row.jmbg || null,
            passport_number: row.passportNumber || null,
            passport_expiry_date: row.passportExpiryDate || null,
            parental_travel_consent: false,
            parental_travel_consent_valid_until: null
          }))
        }
      );
      if (error) throw error;

      setSelectedImportFile(null);
      setImportRows([]);
      setActiveView("pending");
      await loadPendingImports();
      const numericPreparedCount = Number(preparedCount);
      const processedCount = Number.isFinite(numericPreparedCount)
        ? numericPreparedCount
        : rowsForImport.length;
      setMessage(
        `Obrađeno je ${processedCount} novih osoba. Preskočeno je ${importRows.length - processedCount} postojećih email adresa.`
      );
    } catch (error) {
      setImportError(getErrorMessage(error));
    } finally {
      setIsImporting(false);
    }
  }

  async function loadPendingImports() {
    if (!society) return;
    try {
      const { data, error } = await (getSupabaseClient().rpc as any)(
        "auth_get_pending_member_imports",
        { p_society_id: society.id }
      );
      if (error) throw error;
      setPendingImports((data ?? []) as PendingImportCandidate[]);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    }
  }

  async function handleApprovePendingImport(candidateId: string) {
    const candidate = pendingImports.find((item) => item.id === candidateId);
    const phone = pendingPhones[candidateId] ?? candidate?.profile.phone ?? "";
    const startDate = parseSerbianDate(pendingStartDates[candidateId] ?? "");
    if (!society || !startDate || !phone.trim()) return;
    setApprovingImportId(candidateId);
    setErrorMessage("");
    try {
      const { error } = await (getSupabaseClient().rpc as any)(
        "auth_approve_pending_member_import",
        {
          p_society_id: society.id,
          p_candidate_id: candidateId,
          p_start_date: startDate,
          p_profile_updates: { phone: phone.trim() }
        }
      );
      if (error) throw error;
      await Promise.all([loadPendingImports(), loadPageData()]);
      setMessage("Član je potvrđen i dodat u spisak članova.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setApprovingImportId(null);
    }
  }

  function handleCancelBulkImport() {
    setSelectedImportFile(null);
    setImportRows([]);
    setImportError("");
  }

  async function handleRejectPendingImport(candidateId: string) {
    if (!society) return;
    setRejectingImportId(candidateId);
    setErrorMessage("");
    try {
      const { error } = await (getSupabaseClient().rpc as any)(
        "auth_reject_pending_member_import",
        {
          p_society_id: society.id,
          p_candidate_id: candidateId
        }
      );
      if (error) throw error;
      await loadPendingImports();
      setMessage("Pripremljeni unos je odbačen.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setRejectingImportId(null);
    }
  }

  async function handleSendDataInvitation(
    candidateId: string,
    recipientRole: "MEMBER" | "GUARDIAN"
  ) {
    if (!society) return;
    const sendingKey = `${candidateId}:${recipientRole}`;
    const candidate = pendingImports.find((item) => item.id === candidateId);
    const candidateDraft = (candidate?.draft ?? candidate?.profile ?? {}) as Record<
      string,
      unknown
    >;
    const guardian = candidateDraft.guardian1 as Record<string, unknown> | undefined;
    const recipientEmail = recipientRole === "GUARDIAN"
      ? String(guardian?.email ?? "").trim()
      : undefined;
    if (recipientRole === "GUARDIAN" && (!recipientEmail || !isValidEmail(recipientEmail))) {
      setErrorMessage("Unesite ispravnu email adresu roditelja/staratelja.");
      return;
    }
    setSendingInvitationId(sendingKey);
    setErrorMessage("");
    try {
      const { data: sessionData } = await getSupabaseClient().auth.getSession();
      const accessToken = sessionData.session?.access_token;
      if (!accessToken) throw new Error("Prijava je istekla.");
      const response = await fetch("/api/member-data-invitations/send", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          societyId: society.id,
          candidateId,
          recipientRole,
          recipientEmail
        })
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || "Email nije poslat.");
      await loadPendingImports();
      setMessage(`Link za dopunu podataka poslat je na ${result.email}.`);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setSendingInvitationId(null);
    }
  }

  async function handleCreateLocalTestLink(
    candidateId: string,
    recipientRole: "MEMBER" | "GUARDIAN"
  ) {
    if (!society) return;
    const actionKey = `${candidateId}:${recipientRole}`;
    const candidate = pendingImports.find((item) => item.id === candidateId);
    const candidateDraft = (candidate?.draft ?? candidate?.profile ?? {}) as Record<
      string,
      unknown
    >;
    const guardian = candidateDraft.guardian1 as Record<string, unknown> | undefined;
    const recipientEmail = recipientRole === "GUARDIAN"
      ? String(guardian?.email ?? "").trim()
      : undefined;
    if (recipientRole === "GUARDIAN" && (!recipientEmail || !isValidEmail(recipientEmail))) {
      setErrorMessage("Unesite ispravnu email adresu roditelja/staratelja.");
      return;
    }
    setCreatingTestLinkId(actionKey);
    setErrorMessage("");
    try {
      const { data, error } = await (getSupabaseClient().rpc as any)(
        "auth_create_member_data_invitation",
        {
          p_society_id: society.id,
          p_candidate_id: candidateId,
          p_recipient_role: recipientRole,
          p_recipient_email: recipientEmail ?? null
        }
      );
      if (error || !data?.token) throw error ?? new Error("Test link nije napravljen.");
      const testLink = `${window.location.origin}/dopuna-podataka/${data.token}`;
      setLocalTestLinks((links) => ({ ...links, [actionKey]: testLink }));
      try {
        await navigator.clipboard.writeText(testLink);
        setMessage("Lokalni test link je kopiran. Otvorite privatni prozor pregledača i nalepite link.");
      } catch {
        setMessage("Lokalni test link je napravljen. Kopirajte ga iz prikaza kandidata.");
      }
      await loadPendingImports();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setCreatingTestLinkId(null);
    }
  }

  function handleOpenPendingEditor(candidate: PendingImportCandidate) {
    setPresidentDrafts((drafts) => ({
      ...drafts,
      [candidate.id]: { ...candidate.profile, ...(candidate.draft ?? {}) }
    }));
    setEditingPendingId(candidate.id);
  }

  function handlePendingDraftChange(candidateId: string, field: string, value: unknown) {
    setPresidentDrafts((drafts) => ({
      ...drafts,
      [candidateId]: { ...(drafts[candidateId] ?? {}), [field]: value }
    }));
  }

  function handlePendingGuardianChange(candidateId: string, field: string, value: string) {
    setPresidentDrafts((drafts) => ({
      ...drafts,
      [candidateId]: {
        ...(drafts[candidateId] ?? {}),
        guardian1: {
          ...((drafts[candidateId]?.guardian1 as Record<string, unknown> | undefined) ?? {}),
          [field]: value
        }
      }
    }));
  }

  async function handlePendingGuardianEmailBlur(candidateId: string) {
    const guardian = presidentDrafts[candidateId]?.guardian1 as
      | Record<string, unknown>
      | undefined;
    const email = String(guardian?.email ?? "").trim();

    if (!email || !isValidEmail(email)) {
      setPendingGuardianLookups((lookups) => ({
        ...lookups,
        [candidateId]: {
          status: "invalid",
          message: "Unesite ispravnu email adresu roditelja/staratelja."
        }
      }));
      return;
    }

    setPendingGuardianLookups((lookups) => ({
      ...lookups,
      [candidateId]: { status: "checking" }
    }));
    setErrorMessage("");

    try {
      const existingPerson = (await lookupPerson({ email })).person;
      if (!existingPerson) {
        setPendingGuardianLookups((lookups) => ({
          ...lookups,
          [candidateId]: {
            status: "not_found",
            message: "Roditelj/staratelj nije pronađen među unetim osobama."
          }
        }));
        return;
      }

      setPresidentDrafts((drafts) => ({
        ...drafts,
        [candidateId]: {
          ...(drafts[candidateId] ?? {}),
          guardian1: applyPersonToGuardian(
            (drafts[candidateId]?.guardian1 as UFMemberFormValues["guardian1"] | undefined) ?? {
              first_name: "",
              last_name: "",
              email,
              phone: ""
            },
            existingPerson
          )
        }
      }));
      setPendingGuardianLookups((lookups) => ({
        ...lookups,
        [candidateId]: {
          status: "found",
          message: "Roditelj/staratelj je pronađen. Sačuvajte vezu pre slanja poziva.",
          person: existingPerson,
          readOnlyFields: getReadOnlyGuardianFields(existingPerson)
        }
      }));
    } catch (error) {
      setPendingGuardianLookups((lookups) => ({
        ...lookups,
        [candidateId]: {
          status: "error",
          message: getErrorMessage(error)
        }
      }));
    }
  }

  async function handleSavePendingDraft(candidateId: string) {
    if (!society) return;
    setSavingPendingId(candidateId);
    setErrorMessage("");
    try {
      let draft = presidentDrafts[candidateId] ?? {};
      if (Boolean(draft.is_minor_member)) {
        const guardian = draft.guardian1 as UFMemberFormValues["guardian1"] | undefined;
        const guardianEmail = guardian?.email?.trim() ?? "";
        if (!guardianEmail || !isValidEmail(guardianEmail)) {
          throw new Error("Za maloletnog člana prvo unesite email roditelja/staratelja.");
        }
        const existingPerson = (await lookupPerson({ email: guardianEmail })).person;
        if (!existingPerson) {
          throw new Error(
            "Roditelj/staratelj nije pronađen. Prvo ga unesite kao osobu u masovnom unosu."
          );
        }
        draft = {
          ...draft,
          guardian1: applyPersonToGuardian(
            guardian ?? {
              first_name: "",
              last_name: "",
              email: guardianEmail,
              phone: ""
            },
            existingPerson
          )
        };
        setPresidentDrafts((drafts) => ({ ...drafts, [candidateId]: draft }));
      }
      const { error } = await (getSupabaseClient().rpc as any)(
        "auth_update_pending_member_draft",
        {
          p_society_id: society.id,
          p_candidate_id: candidateId,
          p_draft: draft
        }
      );
      if (error) throw error;
      await loadPendingImports();
      setEditingPendingId(null);
      setMessage("Podaci kandidata su sačuvani.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setSavingPendingId(null);
    }
  }


  return (
    <>
      <section className="page-heading">
        <div className="members-page-title">
          <div>
            <h1>Članovi</h1>
          </div>
          <div className="members-heading-actions">
            {pageAccess.can_create && <button
              className="button button-primary"
              disabled={!society || isLoading || (isFormOpen && formMode === "create")}
              type="button"
              onClick={handleOpenForm}
            >
              + Dodaj člana
            </button>}
          </div>
        </div>
      </section>

      {pageAccess.can_bulk_import && (
        <nav className="members-view-tabs" aria-label="Prikaz članova">
          <button
            className={activeView === "members" ? "active" : ""}
            type="button"
            onClick={() => setActiveView("members")}
          >
            Članovi <span>{members.length}</span>
          </button>
          <button
            className={activeView === "bulk-import" ? "active" : ""}
            type="button"
            onClick={() => {
              setActiveView("bulk-import");
              setIsFormOpen(false);
            }}
          >
            Masovni unos
          </button>
          <button
            className={activeView === "pending" ? "active" : ""}
            type="button"
            onClick={() => {
              setActiveView("pending");
              setIsFormOpen(false);
              void loadPendingImports();
            }}
          >
            Čekaju odobrenje{" "}
            <span>{pendingImports.filter((item) => item.missing_fields.length === 0).length}/{pendingImports.length}</span>
          </button>
        </nav>
      )}

      {message && (
        <section
          className="card dashboard-card"
          role="status"
          style={{ marginBottom: 22 }}
        >
          <p>{message}</p>
        </section>
      )}

      {errorMessage && (
        <section
          className="card dashboard-card"
          role="alert"
          style={{ marginBottom: 22 }}
        >
          <p>{errorMessage}</p>
        </section>
      )}

      {activeView === "members" && isFormOpen && society && (
        <section className="card dashboard-card" style={{ marginBottom: 22 }}>
          <UF_MEMBER_FORM
            mode={formMode}
            societyId={society.id}
            existingPersonId={editingPersonId ?? undefined}
            existingMemberId={editingMemberId ?? undefined}
            values={values}
            functionOptions={functionOptions}
            allowFallbackFunctionOptions={false}
            sectionOptions={sectionOptions}
            memberLookup={memberLookup}
            guardianLookups={guardianLookups}
            hiddenPersonFields={currentAccess.hiddenPersonFields}
            readOnlyPersonFields={currentAccess.readOnlyPersonFields}
            readOnlyMembershipFields={currentAccess.readOnlyMembershipFields}
            readOnlyFunctions={currentAccess.readOnlyFunctions}
            readOnlySections={currentAccess.readOnlySections}
            isSubmitting={isSubmitting}
            onFieldChange={handleFieldChange}
            onGuardianFieldChange={handleGuardianFieldChange}
            onAddSecondGuardian={handleAddSecondGuardian}
            onRemoveSecondGuardian={handleRemoveSecondGuardian}
            onFunctionToggle={handleFunctionToggle}
            onSectionToggle={handleSectionToggle}
            onMemberEmailBlur={
              formMode === "create" ?handleMemberEmailBlur : undefined
            }
            onGuardianEmailBlur={handleGuardianEmailBlur}
            onIdentifierBlur={handleIdentifierBlur}
            onSubmit={formMode === "edit" ?handleSubmitEditMember : handleSubmitMember}
            onCancel={handleCancel}
          />
        </section>
      )}

      {activeView === "members" && <section className="card members-table-card">
        <div className="members-toolbar">
          <label className="members-search">
            <span className="visually-hidden">Pretraga članova</span>
            <input
              className="input"
              value={memberSearch}
              onChange={(event) => {
                setSelectedSearchMemberId(null);
                setMemberSearch(event.target.value);
              }}
              placeholder="Pretraži po imenu, email-u ili telefonu..."
            />
          </label>
          <span>{displayedMembers.length} rezultata</span>
        </div>

        {isLoading && <p className="members-empty-state">Učitavanje članova...</p>}
        {!isLoading && members.length === 0 && <p className="members-empty-state">Još nema unetih članova za aktivno društvo.</p>}
        {!isLoading && members.length > 0 && displayedMembers.length === 0 && <p className="members-empty-state">Nema članova za izabranu pretragu.</p>}

        {!isLoading && displayedMembers.length > 0 && (
          <div className="members-table-scroll">
            <div className="members-table-head">
              <span>Ime i prezime</span><span>Kontakt</span><span>Član od</span><span>Status</span><span />
            </div>
            {displayedMembers.map((member) => (
              <div
                className="members-table-row"
                key={member.id}
                role="button"
                tabIndex={0}
                onClick={() => void handleOpenEditMember(member.id)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    void handleOpenEditMember(member.id);
                  }
                }}
              >
                <strong>{member.firstName} {member.lastName}</strong>
                <span className="member-contact"><span>{member.email ?? "Bez email-a"}</span><small>{member.phone ?? "Bez telefona"}</small></span>
                <span>{member.startDate ? member.startDate.split("-").reverse().join("/") : "Nije uneto"}</span>
                <span className={`member-status ${member.status === "ACTIVE" ? "active" : "inactive"}`}><i />{member.status === "ACTIVE" ? "Aktivan" : "Neaktivan"}</span>
                <span className="member-row-action" aria-hidden="true">›</span>
              </div>
            ))}
          </div>
        )}
      </section>}

      {activeView === "bulk-import" && pageAccess.can_bulk_import && (
        <section className="members-import-layout">
          <div className="members-import-steps">
            <article className="card members-import-step">
              <span>1</span>
              <div>
                <h2>Preuzmite šablon</h2>
                <p>Popunite podatke bez menjanja naziva i redosleda kolona.</p>
              </div>
              <a
                className="button button-secondary"
                download
                href="/templates/Sablon-za-masovni-unos-osoba-v2.xlsx"
              >
                Preuzmi Excel šablon
              </a>
            </article>

            <article className="card members-import-step">
              <span>2</span>
              <div>
                <h2>Izaberite popunjen fajl</h2>
                <p>Dozvoljen je Excel fajl napravljen iz preuzetog šablona.</p>
              </div>
              <label className="button button-primary members-file-button">
                Izaberi Excel fajl
                <input
                  accept=".xlsx"
                  type="file"
                  onChange={(event) =>
                    void handleImportFile(event.target.files?.[0] ?? null)
                  }
                />
              </label>
            </article>
          </div>

          <section className="card members-import-preview">
            <header>
              <div>
                <span className="members-import-eyebrow">Rezultat čitanja</span>
                <h2>Provera podataka pre unosa</h2>
              </div>
              {selectedImportFile && <strong>{selectedImportFile.name}</strong>}
            </header>
            {importError && <p className="members-import-error" role="alert">{importError}</p>}
            {!selectedImportFile ? (
              <p className="members-empty-state">
                Izaberite popunjen Excel da biste ovde videli ispravne redove i greške.
              </p>
            ) : isReadingImport ? (
              <p className="members-empty-state">Čitanje i provera Excel fajla...</p>
            ) : (
              <div className="members-import-selected">
                {importRows.length > 0 && <>
                  <div className="members-import-summary">
                    <strong>{importRows.filter((row) => !row.skipReason && row.errors.length === 0).length} spremno</strong>
                    <span>{importRows.filter((row) => !row.skipReason && row.errors.length > 0).length} sa greškom</span>
                    <span>{importRows.filter((row) => row.skipReason).length} preskočeno</span>
                    <span>{importRows.filter((row) => row.kind === "Član").length} članova</span>
                    <span>{importRows.filter((row) => row.kind === "Roditelj/staratelj").length} roditelja/staratelja</span>
                  </div>
                  <div className="members-import-table-scroll">
                    <table className="members-import-table">
                      <thead><tr><th>Red</th><th>Osoba</th><th>Email / telefon</th><th>Rezultat provere</th></tr></thead>
                      <tbody>{importRows.map((row) => (
                        <tr key={row.rowNumber} className={row.skipReason ? "is-skipped" : row.errors.length ? "has-error" : ""}>
                          <td>{row.rowNumber}</td>
                          <td><strong>{row.firstName} {row.lastName}</strong><small>{row.kind}</small></td>
                          <td><span>{row.email || "Bez email-a"}</span><small>{row.phone || "Bez telefona"}</small></td>
                          <td>{row.skipReason
                            ? <span className="members-import-skipped">Preskočeno — {row.skipReason}</span>
                            : row.errors.length
                            ? <ul>{row.errors.map((error) => <li key={error}>{error}</li>)}</ul>
                            : <span className="members-import-ok">Spremno za unos</span>}
                          </td>
                        </tr>
                      ))}</tbody>
                    </table>
                  </div>
                  <p className="members-import-hint">Roditelji/staratelji se odmah čuvaju kao osobe. Članovi čekaju da predsednik dopuni obavezne podatke i potvrdi članstvo.</p>
                  <div className="members-import-actions">
                    <button
                      className="button button-secondary"
                      disabled={isImporting}
                      type="button"
                      onClick={handleCancelBulkImport}
                    >
                      Otkaži unos
                    </button>
                    <button className="button button-primary"
                      disabled={
                        isImporting ||
                        importRows.filter((row) => !row.skipReason).length === 0 ||
                        importRows.some((row) => !row.skipReason && row.errors.length > 0)
                      }
                      type="button" onClick={() => void handleConfirmBulkImport()}>
                      {isImporting
                        ? "Priprema u toku..."
                        : `Pošalji na potvrdu (${importRows.filter((row) => !row.skipReason).length})`}
                    </button>
                  </div>
                </>}
              </div>
            )}
          </section>
        </section>
      )}

      {activeView === "pending" && pageAccess.can_bulk_import && (
        <section className="card members-table-card">
          <div className="members-pending-heading">
            <div>
              <h2>Čekaju konačno odobrenje</h2>
              <p>Predsednik dopunjava obavezne podatke i potvrđuje svakog člana posebno.</p>
            </div>
            <span>
              {pendingImports.filter((item) => item.missing_fields.length === 0).length} spremno · {pendingImports.length} ukupno
            </span>
          </div>
          <div className="members-local-mode-note">
            <strong>Lokalno testiranje:</strong> napravite probni link i otvorite ga u privatnom
            prozoru pregledača. Slanje pravog emaila uključićemo tek kada aplikacija bude na internetu.
          </div>
          {pendingImports.length === 0 ? (
            <p className="members-empty-state">
              Trenutno nema uvezenih članova koji čekaju obradu.
            </p>
          ) : (
            <div className="members-pending-list">
              {pendingImports.map((candidate) => {
                const savedDraft = candidate.draft ?? candidate.profile;
                const isMinorCandidate = Boolean(savedDraft.is_minor_member);
                const savedGuardian = savedDraft.guardian1 as
                  | Record<string, unknown>
                  | undefined;
                const savedGuardianEmail = String(savedGuardian?.email ?? "").trim();
                const guardianLinked = isMinorCandidate && isValidEmail(savedGuardianEmail);
                const memberInvitationBlocked = isMinorCandidate && !guardianLinked;

                return (
                <article key={candidate.id} className="members-pending-row">
                  <div>
                    <strong>{candidate.profile.first_name} {candidate.profile.last_name}</strong>
                    <small>
                      {candidate.profile.email || candidate.profile.phone || "Bez kontakta"} · red {candidate.source_row}
                    </small>
                    <div className="members-invitation-controls">
                      <span className={`members-invitation-status ${candidate.member_invitation_status?.toLowerCase() ?? "not-sent"}`}>
                        Član: {getInvitationStatusLabel(candidate.member_invitation_status)}
                      </span>
                      <button
                        className="button button-secondary members-send-invitation"
                        disabled={
                          memberInvitationBlocked ||
                          sendingInvitationId === `${candidate.id}:MEMBER`
                        }
                        type="button"
                        onClick={() => void handleSendDataInvitation(candidate.id, "MEMBER")}
                      >
                        {sendingInvitationId === `${candidate.id}:MEMBER`
                          ? "Slanje..."
                          : candidate.member_invitation_status ? "Novi link članu" : "Pošalji članu"}
                      </button>
                      <button
                        className="button button-secondary members-send-invitation members-test-link-button"
                        disabled={
                          memberInvitationBlocked ||
                          creatingTestLinkId === `${candidate.id}:MEMBER`
                        }
                        type="button"
                        onClick={() => void handleCreateLocalTestLink(candidate.id, "MEMBER")}
                      >
                        {creatingTestLinkId === `${candidate.id}:MEMBER`
                          ? "Pravljenje..."
                          : "Kopiraj test link člana"}
                      </button>
                      {isMinorCandidate ? (
                        <>
                          <span className={`members-invitation-status ${guardianLinked ? "submitted" : "not-sent"}`}>
                            {guardianLinked
                              ? `Povezan roditelj: ${savedGuardianEmail}`
                              : "Roditelj nije povezan"}
                          </span>
                          <button
                            className="button button-secondary members-send-invitation"
                            type="button"
                            onClick={() => handleOpenPendingEditor(candidate)}
                          >
                            {guardianLinked ? "Izmeni vezu" : "Poveži roditelja"}
                          </button>
                          <span className={`members-invitation-status ${candidate.guardian_invitation_status?.toLowerCase() ?? "not-sent"}`}>
                            Roditelj: {getInvitationStatusLabel(candidate.guardian_invitation_status)}
                          </span>
                          <button
                            className="button button-secondary members-send-invitation"
                            disabled={
                              !guardianLinked ||
                              sendingInvitationId === `${candidate.id}:GUARDIAN`
                            }
                            type="button"
                            onClick={() => void handleSendDataInvitation(candidate.id, "GUARDIAN")}
                          >
                            {sendingInvitationId === `${candidate.id}:GUARDIAN`
                              ? "Slanje..."
                              : candidate.guardian_invitation_status ? "Novi link roditelju" : "Pošalji roditelju"}
                          </button>
                          <button
                            className="button button-secondary members-send-invitation members-test-link-button"
                            disabled={
                              !guardianLinked ||
                              creatingTestLinkId === `${candidate.id}:GUARDIAN`
                            }
                            type="button"
                            onClick={() => void handleCreateLocalTestLink(candidate.id, "GUARDIAN")}
                          >
                            {creatingTestLinkId === `${candidate.id}:GUARDIAN`
                              ? "Pravljenje..."
                              : "Kopiraj test link roditelja"}
                          </button>
                        </>
                      ) : (
                        <small>
                          Za roditeljski poziv prvo označite kandidata kao maloletnog i
                          povežite roditelja kroz „Dopuni podatke“.
                        </small>
                      )}
                    </div>
                    {localTestLinks[`${candidate.id}:MEMBER`] && (
                      <label className="members-local-test-link">
                        Poslednji test link člana
                        <input
                          className="input"
                          readOnly
                          value={localTestLinks[`${candidate.id}:MEMBER`]}
                          onFocus={(event) => event.currentTarget.select()}
                        />
                      </label>
                    )}
                    {localTestLinks[`${candidate.id}:GUARDIAN`] && (
                      <label className="members-local-test-link">
                        Poslednji test link roditelja
                        <input
                          className="input"
                          readOnly
                          value={localTestLinks[`${candidate.id}:GUARDIAN`]}
                          onFocus={(event) => event.currentTarget.select()}
                        />
                      </label>
                    )}
                    {candidate.missing_fields.length > 0
                      ? <small>Nedostaje: {candidate.missing_fields.join(", ")}</small>
                      : <span className="members-import-ok">Lični podaci su kompletni</span>}
                  </div>
                  <label>
                    Telefon
                    <input
                      className="input"
                      type="tel"
                      value={pendingPhones[candidate.id] ?? candidate.profile.phone ?? ""}
                      onChange={(event) => setPendingPhones((phones) => ({
                        ...phones,
                        [candidate.id]: event.target.value
                      }))}
                    />
                  </label>
                  <label>
                    Datum početka članstva
                    <input
                      className="input"
                      inputMode="numeric"
                      placeholder="dd.mm.gggg"
                      type="text"
                      value={pendingStartDates[candidate.id] ?? ""}
                      onChange={(event) => setPendingStartDates((dates) => ({
                        ...dates,
                        [candidate.id]: event.target.value
                      }))}
                    />
                  </label>
                  <div className="members-pending-actions">
                    <button
                      className="button button-secondary"
                      type="button"
                      onClick={() => handleOpenPendingEditor(candidate)}
                    >
                      Dopuni podatke
                    </button>
                    <button
                      className="button button-secondary"
                      disabled={rejectingImportId === candidate.id || approvingImportId === candidate.id}
                      type="button"
                      onClick={() => void handleRejectPendingImport(candidate.id)}
                    >
                      {rejectingImportId === candidate.id ? "Odbacivanje..." : "Odbaci"}
                    </button>
                    <button
                      className="button button-primary"
                      disabled={
                        !parseSerbianDate(pendingStartDates[candidate.id] ?? "") ||
                        !(pendingPhones[candidate.id] ?? candidate.profile.phone ?? "").trim() ||
                        candidate.missing_fields.some((field) => field !== "phone") ||
                        approvingImportId === candidate.id ||
                        rejectingImportId === candidate.id
                      }
                      type="button"
                      onClick={() => void handleApprovePendingImport(candidate.id)}
                    >
                      {approvingImportId === candidate.id ? "Potvrđivanje..." : "Potvrdi člana"}
                    </button>
                  </div>
                  {editingPendingId === candidate.id && (
                    <section className="members-pending-editor">
                      <h3>Lični podaci člana</h3>
                      <div className="member-data-grid">
                        {pendingPersonalFields.map(([field, label, type]) => (
                          <label className="form-field" key={field}>
                            <span>{label}</span>
                            <input
                              className="input"
                              type={type}
                              value={String(presidentDrafts[candidate.id]?.[field] ?? "")}
                              onChange={(event) => handlePendingDraftChange(
                                candidate.id, field, event.target.value
                              )}
                            />
                          </label>
                        ))}
                      </div>
                      <label className="member-data-minor-toggle">
                        <input
                          type="checkbox"
                          checked={Boolean(presidentDrafts[candidate.id]?.is_minor_member)}
                          onChange={(event) => handlePendingDraftChange(
                            candidate.id, "is_minor_member", event.target.checked
                          )}
                        />
                        Maloletan član
                      </label>
                      {Boolean(presidentDrafts[candidate.id]?.is_minor_member) && (
                        <>
                          <h3>Roditelj/staratelj 1</h3>
                          <div className="member-data-grid">
                            {[
                              ["first_name", "Ime roditelja"],
                              ["last_name", "Prezime roditelja"],
                              ["email", "Email roditelja"],
                              ["phone", "Telefon roditelja"]
                            ].map(([field, label]) => (
                              <label className="form-field" key={field}>
                                <span>{label}</span>
                                <input
                                  className="input"
                                  type={field === "email" ? "email" : field === "phone" ? "tel" : "text"}
                                  readOnly={
                                    field !== "email" &&
                                    pendingGuardianLookups[candidate.id]?.status === "found"
                                  }
                                  value={String(
                                    (presidentDrafts[candidate.id]?.guardian1 as Record<string, unknown> | undefined)?.[field] ?? ""
                                  )}
                                  onChange={(event) => handlePendingGuardianChange(
                                    candidate.id, field, event.target.value
                                  )}
                                  onBlur={
                                    field === "email"
                                      ? () => void handlePendingGuardianEmailBlur(candidate.id)
                                      : undefined
                                  }
                                />
                              </label>
                            ))}
                          </div>
                          {pendingGuardianLookups[candidate.id]?.message && (
                            <p>{pendingGuardianLookups[candidate.id]?.message}</p>
                          )}
                        </>
                      )}
                      <div className="members-consent-fields">
                        <label className="member-data-minor-toggle">
                          <input
                            type="checkbox"
                            checked={Boolean(presidentDrafts[candidate.id]?.parental_travel_consent)}
                            onChange={(event) => handlePendingDraftChange(
                              candidate.id, "parental_travel_consent", event.target.checked
                            )}
                          />
                          Fizička saglasnost za putovanje je dostavljena
                        </label>
                        {Boolean(presidentDrafts[candidate.id]?.parental_travel_consent) && (
                          <label className="form-field">
                            <span>Saglasnost važi do</span>
                            <input
                              className="input"
                              type="date"
                              value={String(presidentDrafts[candidate.id]?.parental_travel_consent_valid_until ?? "")}
                              onChange={(event) => handlePendingDraftChange(
                                candidate.id,
                                "parental_travel_consent_valid_until",
                                event.target.value
                              )}
                            />
                          </label>
                        )}
                      </div>
                      <div className="members-pending-editor-actions">
                        <button className="button button-secondary" type="button" onClick={() => setEditingPendingId(null)}>
                          Otkaži
                        </button>
                        <button
                          className="button button-primary"
                          disabled={savingPendingId === candidate.id}
                          type="button"
                          onClick={() => void handleSavePendingDraft(candidate.id)}
                        >
                          {savingPendingId === candidate.id ? "Čuvanje..." : "Sačuvaj podatke"}
                        </button>
                      </div>
                    </section>
                  )}
                </article>
                );
              })}
            </div>
          )}
        </section>
      )}
    </>
  );
}
