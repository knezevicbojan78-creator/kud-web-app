"use client";

export type SocietyDataFormMode = "registration" | "president" | "master";

export type SocietyDataField =
  | "societyName"
  | "address"
  | "city"
  | "postalCode"
  | "country"
  | "pib"
  | "registrationNumber"
  | "bankAccount"
  | "licenseType";

export type LicenseType = "Free" | "Basic" | "Pro" | "Premium";

export type SocietyDataFormValues = Record<SocietyDataField, string>;

type SocietyDataFormProps = {
  mode: SocietyDataFormMode;
  values: SocietyDataFormValues;
  errors?: Partial<Record<SocietyDataField, string>>;
  onFieldChange: (field: SocietyDataField, value: string) => void;
};

const countries = [
  "Srbija",
  "Hrvatska",
  "Bosna i Hercegovina",
  "Crna Gora",
  "Severna Makedonija",
  "Slovenija",
  "Rumunija",
  "Bugarska",
  "Mađarska"
];

const licenseTypes: LicenseType[] = ["Free", "Basic", "Pro", "Premium"];

export function getLicensePrice(licenseType: LicenseType | string) {
  switch (licenseType) {
    case "Free":
    case "Basic":
    case "Pro":
    case "Premium":
      return 0;
    default:
      return 0;
  }
}

export function SocietyDataForm({
  mode,
  values,
  errors = {},
  onFieldChange
}: SocietyDataFormProps) {
  const sectionId = `${mode}-society-section`;
  const isLicenseEditable = mode !== "president";

  return (
    <section
      className={`form-stack society-data-form society-data-form-${mode}`}
      aria-labelledby={sectionId}
    >
      <div className="page-heading" style={{ marginBottom: 0 }}>
        <p className="eyebrow" id={sectionId}>
          Podaci o društvu
        </p>
      </div>

      <label className="form-field">
        <span>Naziv društva *</span>
        <input
          className="input"
          value={values.societyName}
          onChange={(event) =>
            onFieldChange("societyName", event.target.value)
          }
        />
        {errors.societyName && <span>{errors.societyName}</span>}
      </label>

      <label className="form-field">
        <span>Adresa *</span>
        <input
          className="input"
          value={values.address}
          onChange={(event) => onFieldChange("address", event.target.value)}
        />
        {errors.address && <span>{errors.address}</span>}
      </label>

      <label className="form-field">
        <span>Grad *</span>
        <input
          className="input"
          value={values.city}
          onChange={(event) => onFieldChange("city", event.target.value)}
        />
        {errors.city && <span>{errors.city}</span>}
      </label>

      <label className="form-field">
        <span>Poštanski broj</span>
        <input
          className="input"
          value={values.postalCode}
          onChange={(event) => onFieldChange("postalCode", event.target.value)}
        />
      </label>

      <label className="form-field">
        <span>Država *</span>
        <select
          className="input"
          value={values.country}
          onChange={(event) => onFieldChange("country", event.target.value)}
        >
          {countries.map((country) => (
            <option key={country} value={country}>
              {country}
            </option>
          ))}
        </select>
        {errors.country && <span>{errors.country}</span>}
      </label>

      <label className="form-field">
        <span>PIB *</span>
        <input
          className="input"
          value={values.pib}
          onChange={(event) => onFieldChange("pib", event.target.value)}
        />
        {errors.pib && <span>{errors.pib}</span>}
      </label>

      <label className="form-field">
        <span>Matični broj *</span>
        <input
          className="input"
          value={values.registrationNumber}
          onChange={(event) =>
            onFieldChange("registrationNumber", event.target.value)
          }
        />
        {errors.registrationNumber && <span>{errors.registrationNumber}</span>}
      </label>

      <label className="form-field">
        <span>Broj računa</span>
        <input
          className="input"
          value={values.bankAccount}
          onChange={(event) => onFieldChange("bankAccount", event.target.value)}
        />
      </label>
      {mode === "president" ? (
        <label className="form-field">
          <span>Dodeljena licenca</span>
          <input className="input" readOnly value={values.licenseType} />
        </label>
      ) : mode !== "master" && (
        <label className="form-field">
          <span>Tip licence *</span>
          <select
            className="input"
            disabled={!isLicenseEditable}
            value={values.licenseType}
            onChange={(event) =>
              onFieldChange("licenseType", event.target.value)
            }
          >
            {licenseTypes.map((licenseType) => (
              <option key={licenseType} value={licenseType}>
                {licenseType}
              </option>
            ))}
          </select>
          {errors.licenseType && <span>{errors.licenseType}</span>}
        </label>
      )}
    </section>
  );
}
