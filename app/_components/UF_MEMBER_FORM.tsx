"use client";

import { useEffect, useState, type FormEvent } from "react";

import type { Person, Section, SocietyMemberFunction } from "../_lib/supabaseClient";
import { MembershipFeeFields, type MembershipFeeMode, type MembershipFeeTypeOption } from "./MembershipFeeFields";

export type UFMemberFormMode =
  | "create"
  | "edit"
  | "pending_approval"
  | "president_onboarding"
  | "person_create";

export type UFMemberGender = "Muško" | "Žensko" | "";

export type UFMemberStatus = "ACTIVE" | "INACTIVE";

export type UFMemberPersonField =
  | "first_name"
  | "last_name"
  | "gender"
  | "birth_date"
  | "address"
  | "city"
  | "postal_code"
  | "country"
  | "jmbg"
  | "passport_number"
  | "passport_expiry_date"
  | "parental_travel_consent"
  | "parental_travel_consent_valid_until"
  | "email"
  | "phone"
  | "shoe_size";

export type UFMemberMembershipField =
  | "status"
  | "start_date"
  | "membership_fee_required"
  | "membership_fee_amount"
  | "membership_fee_mode"
  | "membership_fee_reason";

export type UFMemberFormField = UFMemberPersonField | UFMemberMembershipField;

export type UFMemberGuardianField =
  | "first_name"
  | "last_name"
  | "email"
  | "phone";

export type UFMemberGuardianValues = Record<UFMemberGuardianField, string>;

export type UFMemberFormValues = {
  is_minor_member: boolean;
  first_name: string;
  last_name: string;
  gender: UFMemberGender;
  birth_date: string;
  address: string;
  city: string;
  postal_code: string;
  country: string;
  jmbg: string;
  passport_number: string;
  passport_expiry_date: string;
  parental_travel_consent: boolean;
  parental_travel_consent_valid_until: string;
  email: string;
  phone: string;
  shoe_size: string;
  status: UFMemberStatus;
  start_date: string;
  membership_fee_required: boolean;
  membership_fee_amount: string;
  membership_fee_mode?: MembershipFeeMode;
  membership_fee_reason?: string;
  guardian1: UFMemberGuardianValues;
  guardian2: UFMemberGuardianValues;
  showGuardian2: boolean;
  selectedFunctionIds: string[];
  selectedSectionIds: string[];
};

export type UFMemberFormErrors = Partial<
  Record<
    | UFMemberFormField
    | `guardian1.${UFMemberGuardianField}`
    | `guardian2.${UFMemberGuardianField}`,
    string
  >
>;

export type UFMemberLookupStatus =
  | "idle"
  | "checking"
  | "found"
  | "not_found"
  | "duplicate"
  | "invalid"
  | "error";

export type UFMemberLookupState = {
  status: UFMemberLookupStatus;
  message?: string;
  person?: Person | null;
  readOnlyFields?: Partial<Record<UFMemberPersonField, boolean>>;
};

export type UFMemberGuardianLookupState = {
  status: UFMemberLookupStatus;
  message?: string;
  person?: Person | null;
  readOnlyFields?: Partial<Record<UFMemberGuardianField, boolean>>;
};

export type UFMemberFormProps = {
  mode: UFMemberFormMode;
  societyId: string;
  existingPersonId?: string;
  existingMemberId?: string;
  values: UFMemberFormValues;
  errors?: UFMemberFormErrors;
  functionOptions?: SocietyMemberFunction[];
  allowFallbackFunctionOptions?: boolean;
  sectionOptions?: Section[];
  memberLookup?: UFMemberLookupState;
  guardianLookups?: Partial<
    Record<"guardian1" | "guardian2", UFMemberGuardianLookupState>
  >;
  guardianSuggestions?: Partial<
    Record<"guardian1" | "guardian2", Person[]>
  >;
  hiddenPersonFields?: Partial<Record<UFMemberPersonField, boolean>>;
  readOnlyPersonFields?: Partial<Record<UFMemberPersonField, boolean>>;
  readOnlyMembershipFields?: Partial<Record<UFMemberMembershipField, boolean>>;
  readOnlyGuardianFields?: Partial<
    Record<
      "guardian1" | "guardian2",
      Partial<Record<UFMemberGuardianField, boolean>>
    >
  >;
  readOnlyFunctions?: boolean;
  readOnlySections?: boolean;
  isSubmitting?: boolean;
  standardMembershipFeeAmount?: number | null;
  membershipFeeCurrency?: string;
  membershipFeeReasonRequired?: boolean;
  membershipFeeTypes?: MembershipFeeTypeOption[];
  selectedMembershipFeeTypeId?: string | null;
  onMembershipFeeTypeSelect?: (feeType: MembershipFeeTypeOption) => void;
  visibleStep?: 2 | 3;
  hideStepper?: boolean;
  hideActions?: boolean;
  onFieldChange: (
    field: UFMemberFormField | "showGuardian2" | "is_minor_member",
    value: string | boolean
  ) => void;
  onGuardianFieldChange: (
    guardian: "guardian1" | "guardian2",
    field: UFMemberGuardianField,
    value: string
  ) => void;
  onAddSecondGuardian: () => void;
  onRemoveSecondGuardian: () => void;
  onFunctionToggle: (functionId: string) => void;
  onSectionToggle?: (sectionId: string) => void;
  onMemberEmailBlur?: () => void;
  onGuardianEmailBlur?: (guardian: "guardian1" | "guardian2") => void;
  onGuardianSuggestionSelect?: (
    guardian: "guardian1" | "guardian2",
    person: Person
  ) => void;
  onIdentifierBlur?: (field: "jmbg" | "passport_number") => void;
  onSubmit: () => void;
  onCancel: () => void;
};

const fallbackFunctionOptions = [
  "Predsednik",
  "Sekretar",
  "Blagajnik",
  "Upravnik",
  "UR",
  "Korepetitor",
  "Član"
];

const protectedFunctionNames = new Set(["Predsednik"]);

const requiredMessage = "Ovo polje je obavezno.";
const adultRequiredMessage = "Punoletni član mora imati ovaj podatak.";
const presidentAdultMessage = "Predsednik tokom onboardinga mora biti punoletan.";
const minorBirthDateMessage =
  "Izabran je tok za maloletnog člana, ali datum rođenja ne odgovara maloletnoj osobi.";
const invalidEmailMessage = "Unesite ispravnu email adresu.";
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function isValidEmail(value: string) {
  return emailPattern.test(value.trim());
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

function hasGuardianValues(guardian: UFMemberGuardianValues) {
  return Object.values(guardian).some((value) => value.trim().length > 0);
}

function validateGuardian(
  errors: UFMemberFormErrors,
  guardian: "guardian1" | "guardian2",
  values: UFMemberGuardianValues
) {
  const fields: UFMemberGuardianField[] = [
    "first_name",
    "last_name",
    "email",
    "phone"
  ];

  fields.forEach((field) => {
    if (!values[field].trim()) {
      errors[`${guardian}.${field}`] = requiredMessage;
    }
  });

  if (values.email.trim() && !isValidEmail(values.email)) {
    errors[`${guardian}.email`] = invalidEmailMessage;
  }
}

function validateValues(
  mode: UFMemberFormMode,
  values: UFMemberFormValues,
  membershipFeeReasonRequired = true
) {
  const errors: UFMemberFormErrors = {};
  const minor = values.is_minor_member;
  const birthDateIsMinor = isUnder18(values.birth_date);
  const isPresidentOnboarding = mode === "president_onboarding";
  const isPersonCreate = mode === "person_create";
  const isEdit = mode === "edit";
  const isCreateWizard = mode === "create";
  const isAdult = !minor;
  const effectiveStatus = isPresidentOnboarding ?"ACTIVE" : values.status;

  if (!isEdit && !values.first_name.trim()) {
    errors.first_name = requiredMessage;
  }

  if (!isEdit && !values.last_name.trim()) {
    errors.last_name = requiredMessage;
  }

  if (!isEdit && !isPersonCreate && !isCreateWizard && !values.gender) {
    errors.gender = "Obavezno polje.";
  }

  if (!isEdit && !isPersonCreate && !isCreateWizard && !values.start_date) {
    errors.start_date = "Datum početka članstva je obavezan.";
  }

  if (isPresidentOnboarding && birthDateIsMinor) {
    errors.birth_date = presidentAdultMessage;
  }

  if (!isEdit && !isPersonCreate && !isCreateWizard && minor && !values.birth_date) {
    errors.birth_date = "Datum rođenja je obavezan za maloletnog člana.";
  }

  if (!isEdit && !isPersonCreate && !isCreateWizard && minor && values.birth_date && !birthDateIsMinor) {
    errors.birth_date = minorBirthDateMessage;
  }

  if (!isEdit && (isPersonCreate || isAdult || isPresidentOnboarding) && !values.email.trim()) {
    errors.email = adultRequiredMessage;
  }

  if (values.email.trim() && !isValidEmail(values.email)) {
    errors.email = invalidEmailMessage;
  }

  if (values.passport_number.trim() && !values.passport_expiry_date) {
    errors.passport_expiry_date =
      "Datum važenja je obavezan kada je unet broj pasoša.";
  }

  if (values.passport_expiry_date && !values.passport_number.trim()) {
    errors.passport_number =
      "Broj pasoša je obavezan kada je unet datum važenja.";
  }
  if (values.parental_travel_consent && !values.parental_travel_consent_valid_until) {
    errors.parental_travel_consent_valid_until = "Unesite datum važenja saglasnosti.";
  }

  if (!isEdit && (isAdult || isPresidentOnboarding) && !values.phone.trim()) {
    errors.phone = adultRequiredMessage;
  }

  if (!isPersonCreate && !["ACTIVE", "INACTIVE"].includes(effectiveStatus)) {
    errors.status = "Status mora biti ACTIVE ili INACTIVE.";
  }

  if (
    !isPersonCreate && !isCreateWizard && (values.membership_fee_mode ?? "STANDARD") === "CUSTOM" &&
    (!values.membership_fee_amount.trim() ||
      Number.isNaN(Number(values.membership_fee_amount)) ||
      Number(values.membership_fee_amount) <= 0)
  ) {
    errors.membership_fee_amount = "Poseban iznos članarine mora biti veći od nule.";
  }
  if (
    !isPersonCreate && !isCreateWizard &&
    membershipFeeReasonRequired &&
    (values.membership_fee_mode === "CUSTOM" || values.membership_fee_mode === "EXEMPT") &&
    !values.membership_fee_reason?.trim()
  ) {
    errors.membership_fee_reason = "Razlog odstupanja od standardne članarine je obavezan.";
  }

  if (!isEdit && !isPersonCreate && minor) {
    validateGuardian(errors, "guardian1", values.guardian1);
  }

  if (!isEdit && !isPersonCreate && (values.showGuardian2 || hasGuardianValues(values.guardian2))) {
    validateGuardian(errors, "guardian2", values.guardian2);
  }

  return errors;
}

function mergeErrors(
  componentErrors: UFMemberFormErrors,
  externalErrors: UFMemberFormErrors
) {
  return {
    ...externalErrors,
    ...componentErrors
  };
}

function getActiveFunctions(
  functionOptions: SocietyMemberFunction[] | undefined,
  allowFallbackFunctionOptions: boolean
) {
  const activeOptions =
    functionOptions
      ?.filter((option) => option.is_active)
      .filter((option) => !protectedFunctionNames.has(option.name))
      .sort((left, right) => left.sort_order - right.sort_order)
      .map((option) => ({
        id: option.id,
        name: option.name
      })) ?? [];

  return activeOptions.length > 0 || !allowFallbackFunctionOptions
    ?activeOptions
    : fallbackFunctionOptions
        .filter((name) => !protectedFunctionNames.has(name))
        .map((name) => ({
          id: `fallback-${name}`,
          name
        }));
}

function getActiveSections(sectionOptions: Section[] | undefined) {
  return sectionOptions?.filter((section) => section.status === "ACTIVE") ?? [];
}

function getError(
  errors: UFMemberFormErrors,
  field: UFMemberFormField | `guardian1.${UFMemberGuardianField}` | `guardian2.${UFMemberGuardianField}`
) {
  return errors[field];
}

type TextFieldProps = {
  label: string;
  value: string;
  error?: string;
  type?: string;
  required?: boolean;
  disabled?: boolean;
  readOnly?: boolean;
  hidden?: boolean;
  hint?: string;
  hintTone?: "default" | "warning";
  onChange: (value: string) => void;
  onBlur?: () => void;
};

function TextField({
  label,
  value,
  error,
  type = "text",
  required = false,
  disabled = false,
  readOnly = false,
  hidden = false,
  hint,
  hintTone = "default",
  onChange,
  onBlur
}: TextFieldProps) {
  if (hidden) {
    return null;
  }

  return (
    <label className="form-field">
      <span>
        {label}
        {required ?" *" : ""}
      </span>
      <input
        className="input"
        disabled={disabled}
        readOnly={readOnly}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onBlur={onBlur}
      />
      {error && <span>{error}</span>}
      {!error && hint && (
        <span className={hintTone === "warning" ? "field-warning" : undefined}>
          {hint}
        </span>
      )}
    </label>
  );
}

function CompactDateField({ label, value, required = false, readOnly = false, hidden = false, error, hint, hintTone = "default", onChange }: { label: string; value: string; required?: boolean; readOnly?: boolean; hidden?: boolean; error?: string; hint?: string; hintTone?: "default" | "warning"; onChange: (value: string) => void }) {
  if (hidden) return null;
  const displayValue = value ? value.split("-").reverse().join("/") : "dd/mm/yyyy";
  return <label className="form-field"><span>{label}{required ? " *" : ""}</span><div className={`uf-date-picker ${value ? "has-value" : ""}`}><span>{displayValue}</span><span aria-hidden="true">▣</span><input disabled={readOnly} type="date" value={value} onClick={(event) => event.currentTarget.showPicker()} onChange={(event) => onChange(event.target.value)} /></div>{error && <span>{error}</span>}{!error && hint && <span className={hintTone === "warning" ? "field-warning" : undefined}>{hint}</span>}</label>;
}

type GuardianSectionProps = {
  title: string;
  values: UFMemberGuardianValues;
  errors: UFMemberFormErrors;
  guardian: "guardian1" | "guardian2";
  labelSuffix?: string;
  onGuardianFieldChange: (
    guardian: "guardian1" | "guardian2",
    field: UFMemberGuardianField,
    value: string
  ) => void;
  lookup?: UFMemberGuardianLookupState;
  suggestions?: Person[];
  onSuggestionSelect?: (person: Person) => void;
  onEmailBlur?: () => void;
  hideEmail?: boolean;
  readOnlyFields?: Partial<Record<UFMemberGuardianField, boolean>>;
  onRemove?: () => void;
};

function GuardianSection({
  title,
  values,
  errors,
  guardian,
  labelSuffix = "",
  onGuardianFieldChange,
  lookup,
  suggestions = [],
  onSuggestionSelect,
  onEmailBlur,
  hideEmail = false,
  readOnlyFields,
  onRemove
}: GuardianSectionProps) {
  const emailChecked =
    lookup?.status === "found" || lookup?.status === "not_found";
  const detailsDisabled = lookup ?!emailChecked : false;

  return (
    <section className="form-stack" aria-labelledby={`${guardian}-section`}>
      <div className="header-actions">
        <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={`${guardian}-section`}>
            {title}
          </p>
        </div>
        {onRemove && (
          <button
            className="button button-secondary"
            type="button"
            onClick={onRemove}
          >
            UKLONI
          </button>
        )}
      </div>

      {!hideEmail && (
        <div className="guardian-email-lookup">
          <TextField
            required
            label={`Email roditelja / staratelja${labelSuffix}`}
            type="email"
            value={values.email}
            error={getError(errors, `${guardian}.email`)}
            readOnly={lookup?.readOnlyFields?.email || readOnlyFields?.email}
            onChange={(value) => onGuardianFieldChange(guardian, "email", value)}
            onBlur={onEmailBlur}
          />
          {suggestions.length > 0 && (
            <div className="guardian-email-suggestions" role="listbox" aria-label="Predlozi roditelja ili staratelja">
              {suggestions.map((person) => (
                <button
                  key={person.id}
                  type="button"
                  role="option"
                  onMouseDown={(event) => event.preventDefault()}
                  onClick={() => onSuggestionSelect?.(person)}
                >
                  <strong>{person.email}</strong>
                  <span>{person.first_name} {person.last_name}{person.phone ? ` · ${person.phone}` : ""}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      )}
      {lookup?.message && <p>{lookup.message}</p>}
      <TextField
        required
        disabled={detailsDisabled}
        readOnly={lookup?.readOnlyFields?.first_name || readOnlyFields?.first_name}
        label={`Ime roditelja${labelSuffix}`}
        value={values.first_name}
        error={getError(errors, `${guardian}.first_name`)}
        onChange={(value) =>
          onGuardianFieldChange(guardian, "first_name", value)
        }
      />
      <TextField
        required
        disabled={detailsDisabled}
        readOnly={lookup?.readOnlyFields?.last_name || readOnlyFields?.last_name}
        label={`Prezime roditelja${labelSuffix}`}
        value={values.last_name}
        error={getError(errors, `${guardian}.last_name`)}
        onChange={(value) =>
          onGuardianFieldChange(guardian, "last_name", value)
        }
      />
      <TextField
        required
        disabled={detailsDisabled}
        readOnly={lookup?.readOnlyFields?.phone || readOnlyFields?.phone}
        label={`Telefon roditelja${labelSuffix}`}
        value={values.phone}
        error={getError(errors, `${guardian}.phone`)}
        onChange={(value) => onGuardianFieldChange(guardian, "phone", value)}
      />
    </section>
  );
}

export function UF_MEMBER_FORM({
  mode,
  societyId,
  existingPersonId,
  existingMemberId,
  values,
  errors = {},
  functionOptions,
  allowFallbackFunctionOptions = true,
  sectionOptions,
  memberLookup,
  guardianLookups,
  guardianSuggestions,
  hiddenPersonFields,
  readOnlyPersonFields,
  readOnlyMembershipFields,
  readOnlyGuardianFields,
  readOnlyFunctions = false,
  readOnlySections = false,
  isSubmitting = false,
  standardMembershipFeeAmount = null,
  membershipFeeCurrency = "RSD",
  membershipFeeReasonRequired = true,
  membershipFeeTypes = [],
  selectedMembershipFeeTypeId = null,
  onMembershipFeeTypeSelect,
  visibleStep,
  hideStepper = false,
  hideActions = false,
  onFieldChange,
  onGuardianFieldChange,
  onAddSecondGuardian,
  onRemoveSecondGuardian,
  onFunctionToggle,
  onSectionToggle,
  onMemberEmailBlur,
  onGuardianEmailBlur,
  onGuardianSuggestionSelect,
  onIdentifierBlur,
  onSubmit,
  onCancel
}: UFMemberFormProps) {
  const [activeStep, setActiveStep] = useState<1 | 2 | 3>(mode === "create" ? 1 : 2);
  const [showTravelDocuments, setShowTravelDocuments] = useState(false);
  const [showCompactSubmitError, setShowCompactSubmitError] = useState(false);
  const [showWizardSubmitError, setShowWizardSubmitError] = useState(false);

  useEffect(() => {
    setActiveStep(mode === "create" ? 1 : 2);
    setShowTravelDocuments(false);
    setShowCompactSubmitError(false);
    setShowWizardSubmitError(false);
  }, [mode, existingMemberId, existingPersonId]);
  const activeFunctions = getActiveFunctions(
    functionOptions,
    allowFallbackFunctionOptions
  );
  const activeSections = getActiveSections(sectionOptions);
  const rawLocalErrors = validateValues(mode, values, membershipFeeReasonRequired);
  const minor = values.is_minor_member;
  const isPresidentOnboarding = mode === "president_onboarding";
  const isPersonCreate = mode === "person_create";
  const memberMinor = minor && !isPersonCreate;
  const showGuardian1 = memberMinor;
  const showGuardian2 = !isPersonCreate && (values.showGuardian2 || hasGuardianValues(values.guardian2));
  const sectionId = `${mode}-member-section`;
  const currentStatus = isPresidentOnboarding ?"ACTIVE" : values.status;
  const membershipFeeMode: MembershipFeeMode = values.membership_fee_mode ?? (
    !values.membership_fee_required
      ? "EXEMPT"
      : standardMembershipFeeAmount != null && Number(values.membership_fee_amount) === standardMembershipFeeAmount
        ? "STANDARD"
        : "CUSTOM"
  );
  const today = new Date();
  const todayValue = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;
  const passportIsExpired = Boolean(
    values.passport_expiry_date && values.passport_expiry_date < todayValue
  );
  const memberLookupStatus = memberLookup?.status ?? "idle";
  const primaryGuardianLookupStatus = guardianLookups?.guardian1?.status ?? "idle";
  const isCreateWizard = mode === "create";
  const isPendingApproval = mode === "pending_approval";
  const isMinorCreateWizard = isCreateWizard && values.is_minor_member;
  const memberEmailChecked =
    !isCreateWizard ||
    isMinorCreateWizard ||
    memberLookupStatus === "found" ||
    memberLookupStatus === "not_found";
  const primaryGuardianEmailChecked =
    !isMinorCreateWizard ||
    primaryGuardianLookupStatus === "found" ||
    primaryGuardianLookupStatus === "not_found";
  const memberSaveBlocked =
    isMinorCreateWizard
      ?primaryGuardianLookupStatus === "checking" ||
        primaryGuardianLookupStatus === "invalid" ||
        primaryGuardianLookupStatus === "error"
      : memberLookupStatus === "duplicate" ||
        memberLookupStatus === "checking" ||
        memberLookupStatus === "invalid" ||
        memberLookupStatus === "error";
  const isPersonFieldHidden = (field: UFMemberPersonField) =>
    Boolean(hiddenPersonFields?.[field]);
  const isPersonFieldReadOnly = (field: UFMemberPersonField) =>
    Boolean(memberLookup?.readOnlyFields?.[field] || readOnlyPersonFields?.[field]);
  const isMembershipFieldReadOnly = (field: UFMemberMembershipField) =>
    Boolean(readOnlyMembershipFields?.[field]);
  const localErrors = { ...rawLocalErrors };
  if (
    isPersonFieldReadOnly("passport_number") &&
    isPersonFieldReadOnly("passport_expiry_date")
  ) {
    delete localErrors.passport_number;
    delete localErrors.passport_expiry_date;
  }
  const visibleErrors = mergeErrors(localErrors, errors);
  if (
    isPendingApproval &&
    values.guardian1.email.trim() &&
    ["idle", "checking"].includes(primaryGuardianLookupStatus)
  ) {
    delete visibleErrors["guardian1.email"];
  }
  const displayedStep = visibleStep ?? activeStep;

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const errorFields = Object.keys(localErrors);
    if (
      memberSaveBlocked ||
      !memberEmailChecked ||
      !primaryGuardianEmailChecked ||
      errorFields.length > 0
    ) {
      if (isPersonCreate) setShowCompactSubmitError(true);
      if (!isPersonCreate) {
        setShowWizardSubmitError(true);
        const membershipErrorFields = new Set([
          "status",
          "start_date",
          "membership_fee_required",
          "membership_fee_amount",
          "membership_fee_mode",
          "membership_fee_reason"
        ]);
        if (errorFields.some((field) => !membershipErrorFields.has(field))) {
          setActiveStep(2);
        } else {
          setActiveStep(3);
        }
      }
      return;
    }

    setShowCompactSubmitError(false);
    setShowWizardSubmitError(false);
    onSubmit();
  }

  return (
    <form className={`uf-member-form ${isPersonCreate ? "uf-person-create-form" : ""}`} noValidate onSubmit={handleSubmit}>
      {!isPersonCreate && !hideStepper && <nav className="uf-stepper" aria-label="Koraci forme">
        <button className={displayedStep === 1 ? "active" : ""} disabled={!isCreateWizard} type="button" onClick={() => setActiveStep(1)}><span>1</span> Identifikacija</button>
        <button className={displayedStep === 2 ? "active" : ""} disabled={!memberEmailChecked || !primaryGuardianEmailChecked} type="button" onClick={() => setActiveStep(2)}><span>2</span> Lični podaci</button>
        <button className={displayedStep === 3 ? "active" : ""} disabled={!memberEmailChecked || !primaryGuardianEmailChecked} type="button" onClick={() => setActiveStep(3)}><span>3</span> Članstvo</button>
      </nav>}

      {displayedStep === 1 && <section className="uf-form-panel uf-identification-panel" aria-labelledby={sectionId}>
        <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={sectionId}>
            Podaci o članu
          </p>
        </div>

        <input type="hidden" value={societyId} readOnly />
        {existingPersonId && <input type="hidden" value={existingPersonId} readOnly />}
        {existingMemberId && <input type="hidden" value={existingMemberId} readOnly />}

        {isCreateWizard && (
          <label className="form-field">
            <span>Maloletan član</span>
            <input
              checked={values.is_minor_member}
              type="checkbox"
              onChange={(event) =>
                onFieldChange("is_minor_member", event.target.checked)
              }
            />
          </label>
        )}

        <TextField
          required
          label={
            isMinorCreateWizard
              ?"Email roditelja / staratelja"
              : isCreateWizard
                ?"Email novog člana"
                : "Email"
          }
          type="email"
          value={isMinorCreateWizard ?values.guardian1.email : values.email}
          error={
            isMinorCreateWizard
              ?getError(visibleErrors, "guardian1.email")
              : visibleErrors.email
          }
          readOnly={
            isMinorCreateWizard
              ?guardianLookups?.guardian1?.readOnlyFields?.email
              : isPersonFieldReadOnly("email")
          }
          onChange={(value) =>
            isMinorCreateWizard
              ?onGuardianFieldChange("guardian1", "email", value)
              : onFieldChange("email", value)
          }
          onBlur={() =>
            isMinorCreateWizard
              ?onGuardianEmailBlur?.("guardian1")
              : onMemberEmailBlur?.()
          }
        />
        {isMinorCreateWizard
          ?guardianLookups?.guardian1?.message && (
              <p>{guardianLookups.guardian1.message}</p>
            )
          : memberLookup?.message && <p>{memberLookup.message}</p>}
        {(isMinorCreateWizard
          ?primaryGuardianLookupStatus === "checking"
          : memberLookupStatus === "checking") && <p>Provera email adrese...</p>}
      </section>}

      {displayedStep === 2 && memberEmailChecked && primaryGuardianEmailChecked && (
      <>
      {showGuardian1 && (
        <GuardianSection
          title="Roditelj / staratelj"
          guardian="guardian1"
          values={values.guardian1}
          errors={visibleErrors}
          lookup={guardianLookups?.guardian1}
          suggestions={guardianSuggestions?.guardian1}
          onSuggestionSelect={(person) => onGuardianSuggestionSelect?.("guardian1", person)}
          readOnlyFields={readOnlyGuardianFields?.guardian1}
          hideEmail={isMinorCreateWizard}
          onGuardianFieldChange={onGuardianFieldChange}
          onEmailBlur={() => onGuardianEmailBlur?.("guardian1")}
        />
      )}
      <section className="uf-form-panel" aria-labelledby={`${sectionId}-details`}>
        {!isPersonCreate && <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={`${sectionId}-details`}>
            {isPersonCreate ? "Podaci o osobi" : minor ?"Podaci člana" : "Podaci o članu"}
          </p>
        </div>}

        {isPersonCreate && <label className="form-field uf-minor-passenger-toggle"><span>Maloletni putnik</span><input checked={values.is_minor_member} type="checkbox" onChange={(event) => onFieldChange("is_minor_member", event.target.checked)} /></label>}
        {isPersonCreate && <h3 className="uf-compact-group-title">Osnovni podaci</h3>}

        <TextField
          required
          label={memberMinor ?"Ime člana" : "Ime"}
          value={values.first_name}
          error={visibleErrors.first_name}
          readOnly={isPersonFieldReadOnly("first_name")}
          onChange={(value) => onFieldChange("first_name", value)}
        />
        {isPendingApproval && <TextField
          required={!minor}
          label={memberMinor ?"Email člana" : "Email"}
          type="email"
          value={values.email}
          error={visibleErrors.email}
          readOnly={isPersonFieldReadOnly("email")}
          onChange={(value) => onFieldChange("email", value)}
        />}
        {isPersonCreate && <TextField required label="Email" type="email" value={values.email} error={visibleErrors.email} readOnly={isPersonFieldReadOnly("email")} onChange={(value) => onFieldChange("email", value)} />}
        <TextField
          required
          label={memberMinor ?"Prezime člana" : "Prezime"}
          value={values.last_name}
          error={visibleErrors.last_name}
          readOnly={isPersonFieldReadOnly("last_name")}
          onChange={(value) => onFieldChange("last_name", value)}
        />

        <label className="form-field">
          <span>{memberMinor ?"Pol člana *" : "Pol *"}</span>
          <select
            className="input"
            disabled={isPersonFieldReadOnly("gender")}
            value={values.gender}
            onChange={(event) => onFieldChange("gender", event.target.value)}
          >
            <option value="">Izaberite pol</option>
            <option value="Muško">Muško</option>
            <option value="Žensko">Žensko</option>
          </select>
          {visibleErrors.gender && <span>{visibleErrors.gender}</span>}
        </label>

        <CompactDateField label={memberMinor ?"Datum rođenja člana" : "Datum rođenja"} value={values.birth_date} error={visibleErrors.birth_date} readOnly={isPersonFieldReadOnly("birth_date")} onChange={(value) => onFieldChange("birth_date", value)} />

        {isPersonCreate && <TextField required={!minor} label="Telefon" value={values.phone} error={visibleErrors.phone} readOnly={isPersonFieldReadOnly("phone")} onChange={(value) => onFieldChange("phone", value)} />}
        <TextField label="Broj obuće" type="number" value={values.shoe_size} error={visibleErrors.shoe_size} readOnly={isPersonFieldReadOnly("shoe_size")} onChange={(value) => onFieldChange("shoe_size", value)} />

        {showGuardian1 && !showGuardian2 && (
          <div className="header-actions">
            <button
              className="button button-secondary"
              type="button"
              onClick={onAddSecondGuardian}
            >
              DODAJ DRUGOG RODITELJA/STARATELJA
            </button>
          </div>
        )}

        {showGuardian2 && (
          <GuardianSection
            title="Roditelj / staratelj 2"
            guardian="guardian2"
            labelSuffix=" 2"
            values={values.guardian2}
            errors={visibleErrors}
            lookup={guardianLookups?.guardian2}
            suggestions={guardianSuggestions?.guardian2}
            onSuggestionSelect={(person) => onGuardianSuggestionSelect?.("guardian2", person)}
            readOnlyFields={readOnlyGuardianFields?.guardian2}
            onGuardianFieldChange={onGuardianFieldChange}
            onEmailBlur={() => onGuardianEmailBlur?.("guardian2")}
            onRemove={onRemoveSecondGuardian}
          />
        )}

        {isPersonCreate && <h3 className="uf-compact-group-title">Kontakt i adresa</h3>}
        <TextField
          label={memberMinor ?"Adresa člana" : "Adresa"}
          value={values.address}
          error={visibleErrors.address}
          readOnly={isPersonFieldReadOnly("address")}
          onChange={(value) => onFieldChange("address", value)}
        />
        <TextField
          label={memberMinor ?"Grad člana" : "Grad"}
          value={values.city}
          error={visibleErrors.city}
          readOnly={isPersonFieldReadOnly("city")}
          onChange={(value) => onFieldChange("city", value)}
        />
        <TextField
          label={memberMinor ?"Poštanski broj člana" : "Poštanski broj"}
          value={values.postal_code}
          error={visibleErrors.postal_code}
          readOnly={isPersonFieldReadOnly("postal_code")}
          onChange={(value) => onFieldChange("postal_code", value)}
        />
        <TextField
          label={memberMinor ?"Država člana" : "Država"}
          value={values.country}
          error={visibleErrors.country}
          readOnly={isPersonFieldReadOnly("country")}
          onChange={(value) => onFieldChange("country", value)}
        />
        {isPersonCreate && <button className="uf-documents-toggle" type="button" onClick={() => setShowTravelDocuments((current) => !current)}><span>Dokumenti za put u inostranstvo</span><strong>{showTravelDocuments ? "SAKRIJ" : "PRIKAŽI"}</strong></button>}
        <TextField
          label={memberMinor ?"JMBG člana" : "JMBG"}
          hidden={isPersonFieldHidden("jmbg") || (isPersonCreate && !showTravelDocuments)}
          value={values.jmbg}
          error={visibleErrors.jmbg}
          readOnly={isPersonFieldReadOnly("jmbg")}
          onChange={(value) => onFieldChange("jmbg", value)}
          onBlur={() => onIdentifierBlur?.("jmbg")}
        />
        <TextField
          label={memberMinor ?"Broj pasoša člana" : "Broj pasoša"}
          hidden={isPersonFieldHidden("passport_number") || (isPersonCreate && !showTravelDocuments)}
          value={values.passport_number}
          error={visibleErrors.passport_number}
          readOnly={isPersonFieldReadOnly("passport_number")}
          onChange={(value) => onFieldChange("passport_number", value)}
          onBlur={() => onIdentifierBlur?.("passport_number")}
        />
        {!isPersonCreate && <CompactDateField
          required={Boolean(values.passport_number.trim())}
          label={memberMinor ?"Datum važenja pasoša člana" : "Datum važenja pasoša"}
          hidden={isPersonFieldHidden("passport_expiry_date")}
          value={values.passport_expiry_date}
          error={visibleErrors.passport_expiry_date}
          hint={passportIsExpired ? "Pasoš je istekao." : undefined}
          hintTone={passportIsExpired ? "warning" : "default"}
          readOnly={isPersonFieldReadOnly("passport_expiry_date")}
          onChange={(value) => onFieldChange("passport_expiry_date", value)}
        />}
        {isPersonCreate && showTravelDocuments && <CompactDateField required={Boolean(values.passport_number.trim())} label="Datum važenja pasoša" value={values.passport_expiry_date} error={visibleErrors.passport_expiry_date} readOnly={isPersonFieldReadOnly("passport_expiry_date")} onChange={(value) => onFieldChange("passport_expiry_date", value)} />}
        {minor && (!isPersonCreate || showTravelDocuments) && <label className="form-field"><span>Saglasnost roditelja</span><select className="input" value={values.parental_travel_consent ? "true" : "false"} onChange={(event) => onFieldChange("parental_travel_consent", event.target.value === "true")}><option value="false">Nema</option><option value="true">Imamo saglasnost</option></select></label>}
        {minor && values.parental_travel_consent && (!isPersonCreate || showTravelDocuments) && <CompactDateField required label="Saglasnost važi do" value={values.parental_travel_consent_valid_until} error={visibleErrors.parental_travel_consent_valid_until} onChange={(value) => onFieldChange("parental_travel_consent_valid_until", value)} />}
        {!isPersonCreate && <TextField
          required={!minor || isPresidentOnboarding}
          label={memberMinor ?"Telefon člana" : "Telefon"}
          value={values.phone}
          error={visibleErrors.phone}
          readOnly={isPersonFieldReadOnly("phone")}
          onChange={(value) => onFieldChange("phone", value)}
        />}
      </section>

      </>
      )}

      {!isPersonCreate && displayedStep === 3 && memberEmailChecked && primaryGuardianEmailChecked && (
      <div className="uf-membership-layout">
      <section className="uf-form-panel" aria-labelledby={`${mode}-membership-section`}>
        <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={`${mode}-membership-section`}>
            Podaci o članstvu
          </p>
        </div>

        <label className="form-field">
          <span>Status *</span>
          <select
            className="input"
            disabled={isPresidentOnboarding || isMembershipFieldReadOnly("status")}
            value={currentStatus}
            onChange={(event) => onFieldChange("status", event.target.value)}
          >
            <option value="ACTIVE">ACTIVE</option>
            <option value="INACTIVE">INACTIVE</option>
          </select>
          {visibleErrors.status && <span>{visibleErrors.status}</span>}
        </label>

        <CompactDateField
          required
          label="Datum početka članstva"
          value={values.start_date}
          error={visibleErrors.start_date}
          readOnly={isMembershipFieldReadOnly("start_date")}
          onChange={(value) => onFieldChange("start_date", value)}
        />

        <MembershipFeeFields
          mode={membershipFeeMode}
          customAmount={values.membership_fee_amount}
          reason={values.membership_fee_reason ?? ""}
          standardAmount={standardMembershipFeeAmount}
          currency={membershipFeeCurrency}
          feeTypes={membershipFeeTypes}
          selectedFeeTypeId={selectedMembershipFeeTypeId}
          disabled={
            isMembershipFieldReadOnly("membership_fee_required") ||
            isMembershipFieldReadOnly("membership_fee_amount")
          }
          onModeChange={(feeMode) => {
            onFieldChange("membership_fee_required", feeMode !== "EXEMPT");
            onFieldChange("membership_fee_amount", feeMode === "STANDARD" ? String(standardMembershipFeeAmount ?? "") : feeMode === "EXEMPT" ? "" : values.membership_fee_amount);
            onFieldChange("membership_fee_mode", feeMode);
            if (feeMode === "STANDARD") onFieldChange("membership_fee_reason", "");
          }}
          onCustomAmountChange={(value) => onFieldChange("membership_fee_amount", value)}
          onReasonChange={(value) => onFieldChange("membership_fee_reason", value)}
          onFeeTypeSelect={onMembershipFeeTypeSelect}
        />
      </section>

      {!isPresidentOnboarding && <section className="uf-form-panel" aria-labelledby={`${mode}-functions-section`}>
        <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={`${mode}-functions-section`}>
            Funkcije
          </p>
        </div>

        {activeFunctions.length === 0 && (
          <p>Nema aktivnih funkcija za ručnu dodelu.</p>
        )}

        {activeFunctions.map((memberFunction) => (
          <label className="form-field" key={memberFunction.id}>
            <span>{memberFunction.name === "UR" ? "Umetnički rukovodilac" : memberFunction.name}</span>
            <input
              checked={values.selectedFunctionIds.includes(memberFunction.id)}
              disabled={readOnlyFunctions}
              type="checkbox"
              onChange={() => onFunctionToggle(memberFunction.id)}
            />
          </label>
        ))}
      </section>}

      {!isPresidentOnboarding && <section className="uf-form-panel" aria-labelledby={`${mode}-sections-section`}>
        <div className="page-heading" style={{ marginBottom: 0 }}>
          <p className="eyebrow" id={`${mode}-sections-section`}>
            Sekcije
          </p>
        </div>

        {activeSections.length === 0 && (
          <p>Nema aktivnih sekcija za izbor.</p>
        )}

        {activeSections.map((section) => (
          <label className="form-field" key={section.id}>
            <span>{section.name}</span>
            <input
              checked={values.selectedSectionIds.includes(section.id)}
              disabled={!onSectionToggle || readOnlySections}
              type="checkbox"
              onChange={() => onSectionToggle?.(section.id)}
            />
          </label>
        ))}
      </section>}

      </div>
      )}

      {isPersonCreate && showCompactSubmitError && <p className="uf-compact-submit-error">Proverite obavezna polja označena zvezdicom i format emaila.</p>}
      {!isPersonCreate && showWizardSubmitError && <p className="uf-compact-submit-error">Pregled nije moguće otvoriti. Proverite označena polja na prikazanom koraku.</p>}
      {!hideActions && <div className="uf-form-actions">
        <button
          className="button button-secondary"
          disabled={isSubmitting}
          type="button"
          onClick={onCancel}
        >
          OTKAŽI
        </button>
        <div className="header-actions">
          {!isPersonCreate && activeStep > (isCreateWizard ? 1 : 2) && <button className="button button-secondary" disabled={isSubmitting} type="button" onClick={() => setActiveStep((activeStep - 1) as 1 | 2)}>Nazad</button>}
          {isPersonCreate ? <button className="button button-primary" disabled={isSubmitting} type="submit">Sačuvaj osobu i dodaj putnika</button> : activeStep < 3 ? (
            <button className="button button-primary" disabled={isSubmitting || memberSaveBlocked || !memberEmailChecked || !primaryGuardianEmailChecked} type="button" onClick={() => setActiveStep((activeStep + 1) as 2 | 3)}>Nastavi</button>
          ) : (
            <button className="button button-primary" disabled={isSubmitting || memberSaveBlocked || !memberEmailChecked || !primaryGuardianEmailChecked} type="submit">{isPresidentOnboarding ? "Pregled i potvrda" : isCreateWizard ? "Sačuvaj u čekanju" : "Sačuvaj"}</button>
          )}
        </div>
      </div>}
    </form>
  );
}
