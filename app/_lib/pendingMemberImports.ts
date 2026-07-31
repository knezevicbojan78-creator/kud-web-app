export type PendingImportCandidate = {
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
  society_member_id?: string | null;
  draft: Record<string, unknown>;
  missing_fields: string[];
};

export type PendingMembershipSetup = {
  feeMode: "STANDARD" | "CUSTOM" | "EXEMPT";
  customFeeAmount: string;
  feeReason: string;
  functionIds: string[];
  sectionIds: string[];
};

export function getInvitationStatusLabel(status: string | null) {
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

export function getPendingCandidateStage(candidate: PendingImportCandidate) {
  const draft = candidate.draft ?? candidate.profile;
  const isMinor = Boolean(draft.is_minor_member);
  const missingFields = candidate.missing_fields.filter(
    (field) => field !== "phone" || !isMinor
  );
  const invitationStatuses = [
    candidate.member_invitation_status,
    candidate.guardian_invitation_status
  ].filter(Boolean);
  const dataSubmitted = invitationStatuses.includes("SUBMITTED");

  if (invitationStatuses.length === 0) {
    return {
      label: "Čeka slanje linka",
      detail: "Kandidat još nije prihvaćen za dopunu podataka.",
      tone: "not-sent"
    };
  }
  if (dataSubmitted && missingFields.length === 0) {
    return {
      label: "Spreman za potvrdu",
      detail: "Lični podaci su poslati i kompletni.",
      tone: "submitted"
    };
  }
  if (missingFields.length > 0) {
    return {
      label: "Čeka dopunu",
      detail: `Nedostaje još ${missingFields.length} ${
        missingFields.length === 1 ? "podatak" : "podataka"
      }.`,
      tone: "in_progress"
    };
  }
  return {
    label: "Čeka slanje podataka",
    detail: "Link je otvoren, ali podaci još nisu poslati.",
    tone: "opened"
  };
}

export function getMissingPendingPersonalFields(draft: Record<string, unknown>) {
  const missing: string[] = [];
  const required = [
    ["first_name", "ime člana"],
    ["last_name", "prezime člana"],
    ["gender", "pol člana"],
    ["birth_date", "datum rođenja člana"],
    ["email", "email člana"],
    ["address", "adresa člana"],
    ["city", "mesto člana"],
    ["postal_code", "poštanski broj"],
    ["country", "država"]
  ] as const;

  required.forEach(([field, label]) => {
    if (!String(draft[field] ?? "").trim()) missing.push(label);
  });

  const isMinor = Boolean(draft.is_minor_member);
  if (!isMinor && !String(draft.phone ?? "").trim()) {
    missing.push("telefon člana");
  }

  if (isMinor) {
    const guardian = (draft.guardian1 ?? {}) as Record<string, unknown>;
    const guardianRequired = [
      ["first_name", "ime roditelja/staratelja"],
      ["last_name", "prezime roditelja/staratelja"],
      ["email", "email roditelja/staratelja"],
      ["phone", "telefon roditelja/staratelja"]
    ] as const;
    guardianRequired.forEach(([field, label]) => {
      if (!String(guardian[field] ?? "").trim()) missing.push(label);
    });
  }

  return missing;
}
