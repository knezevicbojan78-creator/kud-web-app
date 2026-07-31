"use client";

export type MembershipFeeMode = "STANDARD" | "CUSTOM" | "EXEMPT";

type MembershipFeeFieldsProps = {
  mode: MembershipFeeMode;
  customAmount: string;
  reason: string;
  standardAmount: number | null;
  currency?: string;
  disabled?: boolean;
  onModeChange: (mode: MembershipFeeMode) => void;
  onCustomAmountChange: (amount: string) => void;
  onReasonChange: (reason: string) => void;
};

function moneyLabel(amount: number | null, currency: string) {
  if (amount == null) return "iznos nije podešen";
  return `${new Intl.NumberFormat("sr-Latn-RS", { maximumFractionDigits: 2 }).format(amount)} ${currency}`;
}

export function MembershipFeeFields({
  mode,
  customAmount,
  reason,
  standardAmount,
  currency = "RSD",
  disabled = false,
  onModeChange,
  onCustomAmountChange,
  onReasonChange
}: MembershipFeeFieldsProps) {
  const isException = mode !== "STANDARD";

  return (
    <div className="membership-fee-fields">
      <label className="form-field">
        <span>Režim članarine *</span>
        <select
          className="input"
          disabled={disabled}
          value={mode}
          onChange={(event) => onModeChange(event.target.value as MembershipFeeMode)}
        >
          <option value="STANDARD">Standardna članarina — {moneyLabel(standardAmount, currency)}</option>
          <option value="CUSTOM">Posebna članarina</option>
          <option value="EXEMPT">Oslobođen članarine</option>
        </select>
      </label>

      {mode === "STANDARD" && (
        <label className="form-field">
          <span>Standardni mesečni iznos</span>
          <input className="input" readOnly value={moneyLabel(standardAmount, currency)} />
        </label>
      )}

      {mode === "CUSTOM" && (
        <label className="form-field">
          <span>Poseban mesečni iznos ({currency}) *</span>
          <input
            className="input"
            disabled={disabled}
            min="0.01"
            step="0.01"
            type="number"
            value={customAmount}
            onChange={(event) => onCustomAmountChange(event.target.value)}
          />
        </label>
      )}

      {isException && (
        <label className="form-field membership-fee-reason">
          <span>{mode === "CUSTOM" ? "Razlog posebnog iznosa *" : "Razlog oslobođenja *"}</span>
          <textarea
            className="input"
            disabled={disabled}
            rows={2}
            value={reason}
            onChange={(event) => onReasonChange(event.target.value)}
          />
        </label>
      )}
    </div>
  );
}
