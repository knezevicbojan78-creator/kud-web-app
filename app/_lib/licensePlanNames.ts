const planNames: Record<string, string> = {
  SMALL: "Folkloraš Start",
  "Malo društvo": "Folkloraš Start",
  STANDARD: "Folkloraš Plus",
  Standard: "Folkloraš Plus",
  LARGE: "Folkloraš Pro",
  "Veliko društvo": "Folkloraš Pro"
};

export function licensePlanDisplayName(value: string | null | undefined) {
  if (!value) return "Nije dodeljena";
  return planNames[value] ?? value;
}
