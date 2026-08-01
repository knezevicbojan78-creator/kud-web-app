"use client";

export type MembershipFeeMode = "STANDARD" | "CUSTOM" | "EXEMPT";
export type MembershipFeeTypeOption = {
  id: string;
  name: string;
  amount: number;
  currency: string;
};

type MembershipFeeFieldsProps = {
  mode: MembershipFeeMode;
  customAmount: string;
  reason: string;
  standardAmount: number | null;
  currency?: string;
  disabled?: boolean;
  feeTypes?: MembershipFeeTypeOption[];
  selectedFeeTypeId?: string | null;
  onModeChange: (mode: MembershipFeeMode) => void;
  onFeeTypeSelect?: (feeType: MembershipFeeTypeOption) => void;
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
  feeTypes = [],
  selectedFeeTypeId = null,
  onModeChange,
  onFeeTypeSelect,
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
          value={selectedFeeTypeId ? `FEE_TYPE:${selectedFeeTypeId}` : mode}
          onChange={(event) => {
            const nextValue = event.target.value;
            if (nextValue.startsWith("FEE_TYPE:")) {
              const feeType = feeTypes.find((item) => item.id === nextValue.slice(9));
              if (feeType) onFeeTypeSelect?.(feeType);
              return;
            }
            onModeChange(nextValue as MembershipFeeMode);
          }}
        >
          <option value="STANDARD">Standardna članarina — {moneyLabel(standardAmount, currency)}</option>
          {feeTypes.map((feeType) => (
            <option key={feeType.id} value={`FEE_TYPE:${feeType.id}`}>
              {feeType.name} — {moneyLabel(feeType.amount, feeType.currency || currency)}
            </option>
          ))}
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
