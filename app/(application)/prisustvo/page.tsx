"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import AttendanceHistory from "../../_components/AttendanceHistory";
import {
  getSupabaseClient,
  type AttendanceRecord,
  type AttendanceSession,
  type AttendanceStatus,
  type Person,
  type Section,
  type Society
} from "../../_lib/supabaseClient";
import type { ApplicationRole } from "../../_lib/roles";

type AttendanceMember = AttendanceRecord & {
  name: string;
  gender: Person["gender"];
  participantType: "MEMBER" | "ACCOMPANIST";
  roleLabel: string | null;
};

type AttendanceSection = Section & {
  access: {
    can_open: boolean;
    can_record_open: boolean;
    can_close: boolean;
    can_cancel: boolean;
    can_edit_closed: boolean;
  };
};

type PendingCorrection = {
  member: AttendanceMember;
  nextStatus: AttendanceStatus;
} | null;

function getErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) {
    return String(error.message);
  }
  return "Akcija trenutno nije uspela. Pokušajte ponovo.";
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

export default function PrisustvoPage() {
  const [activeView, setActiveView] = useState<"CURRENT" | "HISTORY">("CURRENT");
  const [role, setRole] = useState<ApplicationRole | null>(null);
  const [isGuardian, setIsGuardian] = useState(false);
  const [actorSocietyMemberId, setActorSocietyMemberId] = useState<string | null>(
    null
  );
  const [society, setSociety] = useState<Society | null>(null);
  const [sections, setSections] = useState<AttendanceSection[]>([]);
  const [selectedSectionId, setSelectedSectionId] = useState("");
  const [session, setSession] = useState<AttendanceSession | null>(null);
  const [members, setMembers] = useState<AttendanceMember[]>([]);
  const [search, setSearch] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isOpening, setIsOpening] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const [isCancelling, setIsCancelling] = useState(false);
  const [savingRecordIds, setSavingRecordIds] = useState<string[]>([]);
  const [message, setMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [showCloseConfirmation, setShowCloseConfirmation] = useState(false);
  const [showCancelConfirmation, setShowCancelConfirmation] = useState(false);
  const [cancelErrorMessage, setCancelErrorMessage] = useState("");
  const [pendingCorrection, setPendingCorrection] =
    useState<PendingCorrection>(null);
  const [correctionReason, setCorrectionReason] = useState("");

  useEffect(() => {
    if (isGuardian) setActiveView("HISTORY");
  }, [isGuardian]);

  const selectedSection = useMemo(
    () => sections.find((item) => item.id === selectedSectionId) ?? null,
    [sections, selectedSectionId]
  );
  const sectionMembers = members.filter(
    (member) => member.participantType !== "ACCOMPANIST"
  );
  const accompanists = members.filter(
    (member) => member.participantType === "ACCOMPANIST"
  );
  const presentCount = sectionMembers.filter(
    (member) => member.status === "PRESENT"
  ).length;
  const absentCount = sectionMembers.length - presentCount;
  const presentAccompanistCount = accompanists.filter(
    (member) => member.status === "PRESENT"
  ).length;
  const visibleMembers = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("sr-Latn");
    if (!query) return members;
    return members.filter((member) =>
      member.name.toLocaleLowerCase("sr-Latn").includes(query)
    );
  }, [members, search]);
  const visibleAccompanists = visibleMembers.filter(
    (member) => member.participantType === "ACCOMPANIST"
  );
  const femaleMembers = visibleMembers.filter(
    (member) =>
      member.participantType !== "ACCOMPANIST" && member.gender === "Žensko"
  );
  const maleMembers = visibleMembers.filter(
    (member) =>
      member.participantType !== "ACCOMPANIST" && member.gender === "Muško"
  );
  const membersWithoutGender = visibleMembers.filter(
    (member) =>
      member.participantType !== "ACCOMPANIST" &&
      member.gender !== "Žensko" &&
      member.gender !== "Muško"
  );

  const canEdit = Boolean(session && (
    session.status === "OPEN"
      ? selectedSection?.access.can_record_open
      : selectedSection?.access.can_edit_closed
  ));

  const loadSessionForSection = useCallback(
    async (sectionId: string, silent = false) => {
      if (!society) return;
      if (!silent) setIsLoading(true);
      setErrorMessage("");
      setMessage("");
      try {
        const supabase = getSupabaseClient();
        const { data: workspace, error: workspaceError } = await supabase.rpc(
          isGuardian
            ? "auth_get_guardian_attendance_workspace"
            : "auth_get_attendance_workspace",
          { p_society_id: society.id, p_section_id: sectionId }
        );
        if (workspaceError) throw workspaceError;
        setSession(workspace.session ?? null);
        setMembers(workspace.members ?? []);
      } catch (error) {
        setSession(null);
        setMembers([]);
        setErrorMessage(
          `${getErrorMessage(error)} Proverite da li je primenjen supabase/attendance-setup.sql.`
        );
      } finally {
        if (!silent) setIsLoading(false);
      }
    },
    [isGuardian, society]
  );

  useEffect(() => {
    async function loadPage() {
      setIsLoading(true);
      try {
        const supabase = getSupabaseClient();
        const { data: context, error: contextError } =
          await supabase.rpc("auth_get_application_context");
        if (contextError || !context) throw contextError ?? new Error("Korisnički kontekst nije dostupan.");
        const membership = context.memberships[0];
        if (!membership) throw new Error("Korisnik nema aktivno društvo.");
        const guardianContext = Boolean(membership.is_guardian);
        setIsGuardian(guardianContext);
        const actualRole: ApplicationRole = guardianContext
          ? "Roditelj"
          : membership.functions.includes("Predsednik")
          ? "Predsednik"
          : membership.functions.includes("UR")
            ? "UR"
            : "Član";
        setRole(actualRole);

        const { data: workspace, error: workspaceError } =
          await supabase.rpc(guardianContext
            ? "auth_get_guardian_attendance_workspace"
            : "auth_get_attendance_workspace", {
            p_society_id: membership.society_id,
            p_section_id: null
          });
        if (workspaceError || !workspace) throw workspaceError ?? new Error("Društvo nije dostupno.");
        const activeSociety = workspace.society;
        setActorSocietyMemberId(workspace.actor_society_member_id ?? null);
        setSociety(activeSociety);
        if (!activeSociety) {
          setSections([]);
          return;
        }
        setSections(workspace.sections);
      } catch (error) {
        setErrorMessage(getErrorMessage(error));
      } finally {
        setIsLoading(false);
      }
    }
    void loadPage();
  }, []);

  useEffect(() => {
    if (selectedSectionId && role) {
      void loadSessionForSection(selectedSectionId);
    } else {
      setSession(null);
      setMembers([]);
    }
  }, [loadSessionForSection, role, selectedSectionId]);

  useEffect(() => {
    if (!selectedSectionId || !role || session?.status !== "OPEN") return;
    const intervalId = window.setInterval(() => {
      void loadSessionForSection(selectedSectionId, true);
    }, 60_000);
    return () => window.clearInterval(intervalId);
  }, [loadSessionForSection, role, selectedSectionId, session?.status]);

  async function handleOpenSession() {
    if (!society || !selectedSection || !role || !selectedSection.access.can_open) return;
    setIsOpening(true);
    setErrorMessage("");
    setMessage("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: sessionId, error } = await supabase.rpc(
        "open_attendance_session",
        {
          p_society_id: society.id,
          p_section_id: selectedSection.id,
          p_actor_role: role,
          p_actor_user_id: authData.user?.id ?? null
        }
      );
      if (error) throw error;
      await loadSessionForSection(selectedSection.id);
      setMessage(sessionId ? "Proba je otvorena. Promene se čuvaju automatski." : "Proba je otvorena.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsOpening(false);
    }
  }

  async function saveStatus(
    member: AttendanceMember,
    nextStatus: AttendanceStatus,
    reason: string | null
  ) {
    if (!session || !role) return;
    setSavingRecordIds((current) => [...current, member.id]);
    setErrorMessage("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: updated, error } = await supabase.rpc("set_attendance_status", {
        p_record_id: member.id,
        p_new_status: nextStatus,
        p_actor_role: role,
        p_reason: reason,
        p_actor_user_id: authData.user?.id ?? null
      });
      if (error) throw error;
      setMembers((current) =>
        current.map((item) =>
          item.id === member.id ? { ...item, ...(updated as AttendanceRecord) } : item
        )
      );
      setMessage("Sve promene su sačuvane.");
    } catch (error) {
      setErrorMessage(`Promena za člana ${member.name} nije sačuvana. ${getErrorMessage(error)}`);
    } finally {
      setSavingRecordIds((current) => current.filter((id) => id !== member.id));
    }
  }

  function handleMemberClick(member: AttendanceMember) {
    if (!canEdit || savingRecordIds.includes(member.id) || !session) return;
    const nextStatus: AttendanceStatus = member.status === "PRESENT" ? "ABSENT" : "PRESENT";
    if (session.status === "CLOSED") {
      setPendingCorrection({ member, nextStatus });
      setCorrectionReason("");
      return;
    }
    void saveStatus(member, nextStatus, null);
  }

  async function handleCloseSession() {
    if (!session || !role) return;
    setIsClosing(true);
    setErrorMessage("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: closedSession, error } = await supabase.rpc(
        "close_attendance_session",
        {
          p_session_id: session.id,
          p_actor_role: role,
          p_actor_user_id: authData.user?.id ?? null
        }
      );
      if (error) throw error;
      const confirmedSession = closedSession as AttendanceSession;
      if (!confirmedSession || confirmedSession.status !== "CLOSED") {
        throw new Error("Baza nije potvrdila zatvaranje probe.");
      }
      setSession(null);
      setMembers([]);
      setShowCloseConfirmation(false);
      setMessage("Proba je zatvorena. Samo predsednik može izvršiti naknadnu ispravku.");
      window.setTimeout(() => {
        setMessage("");
        setSelectedSectionId("");
      }, 3000);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsClosing(false);
    }
  }

  async function handleCancelSession() {
    if (!session || !role) return;
    setIsCancelling(true);
    setErrorMessage("");
    setCancelErrorMessage("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: cancelledSession, error } = await supabase.rpc("cancel_attendance_session", {
        p_session_id: session.id,
        p_actor_role: role,
        p_actor_user_id: authData.user?.id ?? null
      });
      if (error) throw error;
      if (
        !cancelledSession ||
        (cancelledSession as AttendanceSession).status !== "CANCELLED"
      ) {
        throw new Error(
          "Baza nije potvrdila otkazivanje probe. Ponovo primenite supabase/attendance-setup.sql."
        );
      }
      setSession(null);
      setMembers([]);
      setShowCancelConfirmation(false);
      setMessage("Proba je otkazana. Možete otvoriti novu probu za ovu sekciju.");
    } catch (error) {
      setCancelErrorMessage(
        `${getErrorMessage(error)} Ako SQL za otkazivanje još nije primenjen u aktivnoj bazi, ponovo pokrenite supabase/attendance-setup.sql.`
      );
    } finally {
      setIsCancelling(false);
    }
  }

  return (
    <>
      {!isGuardian && <div className="attendance-view-tabs" role="tablist" aria-label="Prikaz prisustva">
        <button
          className={activeView === "CURRENT" ? "active" : ""}
          type="button"
          role="tab"
          aria-selected={activeView === "CURRENT"}
          onClick={() => setActiveView("CURRENT")}
        >
          EVIDENCIJA PROBE
        </button>
        <button
          className={activeView === "HISTORY" ? "active" : ""}
          type="button"
          role="tab"
          aria-selected={activeView === "HISTORY"}
          onClick={() => setActiveView("HISTORY")}
        >
          PREGLED PROBA
        </button>
      </div>}

      {activeView === "CURRENT" ? (
        <>
      {errorMessage && <section className="card attendance-alert error" role="alert">{errorMessage}</section>}
      {message && <section className="card attendance-alert" role="status">{message}</section>}

      <section className="card attendance-control-card">
        <label className="form-field">
          <span>Sekcija</span>
          <select
            className="input"
            value={selectedSectionId}
            onChange={(event) => setSelectedSectionId(event.target.value)}
            disabled={Boolean(session?.status === "OPEN") || isLoading || isOpening}
          >
            <option value="">Izaberite sekciju</option>
            {sections.map((section) => <option value={section.id} key={section.id}>{section.name}</option>)}
          </select>
        </label>

        {(!session || session.status === "CLOSED") && (
          <button
            className="button button-primary attendance-open-button"
            type="button"
            disabled={!selectedSectionId || !selectedSection?.access.can_open || isLoading || isOpening}
            onClick={() => void handleOpenSession()}
          >
            {isOpening
              ? "OTVARANJE..."
              : session?.status === "CLOSED"
                ? "OTVORI NOVU PROBU"
                : "OTVORI PROBU"}
          </button>
        )}

        {selectedSection && !selectedSection.access.can_open && (
          <p className="attendance-permission-note">Nemate dozvolu za otvaranje probe u ovoj sekciji.</p>
        )}
      </section>

      {isLoading && <section className="card attendance-empty">Učitavanje evidencije...</section>}

      {!isLoading && session && (
        <section className="attendance-workspace">
          <div className="attendance-session-heading">
            <div>
              <p className="eyebrow">{selectedSection?.name}</p>
              <h2>{session.status === "OPEN" ? "Otvorena" : "Zatvorena"} {formatDateTime(session.opened_at)}</h2>
              {session.status === "OPEN" && (
                <p>
                  Planirani kraj {formatDateTime(session.planned_end_at)} · automatsko
                  zatvaranje {formatDateTime(session.auto_close_at)}
                </p>
              )}
              {session.closed_at && <p>Zatvorena {formatDateTime(session.closed_at)}</p>}
            </div>
            <div className="attendance-counters" aria-label="Broj prisutnih i odsutnih">
              <span><strong>{presentCount}</strong> prisutnih</span>
              <span><strong>{absentCount}</strong> odsutnih</span>
              <span><strong>{sectionMembers.length}</strong> članova</span>
              {accompanists.length > 0 && (
                <span>
                  <strong>{presentAccompanistCount}/{accompanists.length}</strong>{" "}
                  korepetitora
                </span>
              )}
            </div>
          </div>

          <div className="attendance-toolbar">
            <input
              className="input"
              type="search"
              placeholder="Pretraga članova i korepetitora..."
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            {savingRecordIds.length > 0 ? <span>Čuvanje...</span> : <span>✓ Sve promene su sačuvane</span>}
          </div>

          {visibleAccompanists.length > 0 && (
            <section className="attendance-accompanists">
              <header>
                <h3>Korepetitori</h3>
                <span>{visibleAccompanists.length}</span>
              </header>
              <div className="attendance-accompanist-list">
                {visibleAccompanists.map((member) => (
                  <AttendanceMemberButton
                    key={member.id}
                    member={member}
                    canEdit={canEdit}
                    isSaving={savingRecordIds.includes(member.id)}
                    onClick={handleMemberClick}
                  />
                ))}
              </div>
            </section>
          )}

          <div className="attendance-gender-grid">
            <AttendanceColumn
              title="Devojke"
              members={femaleMembers}
              canEdit={canEdit}
              savingRecordIds={savingRecordIds}
              onMemberClick={handleMemberClick}
            />
            <AttendanceColumn
              title="Momci"
              members={maleMembers}
              canEdit={canEdit}
              savingRecordIds={savingRecordIds}
              onMemberClick={handleMemberClick}
            />
          </div>

          {membersWithoutGender.length > 0 && (
            <section className="attendance-gender-missing">
              <h3>Pol nije unet</h3>
              <div className="attendance-member-list">
                {membersWithoutGender.map((member) => (
                  <AttendanceMemberButton
                    key={member.id}
                    member={member}
                    canEdit={canEdit}
                    isSaving={savingRecordIds.includes(member.id)}
                    onClick={handleMemberClick}
                  />
                ))}
              </div>
            </section>
          )}

          {members.length === 0 && <p className="attendance-empty">Sekcija nema osoba za evidenciju ove probe.</p>}
          {members.length > 0 && visibleMembers.length === 0 && <p className="attendance-empty">Nema članova koji odgovaraju pretrazi.</p>}

          {session.status === "OPEN" && (selectedSection?.access.can_cancel || selectedSection?.access.can_close) && (
            <div className="attendance-footer">
              {selectedSection?.access.can_cancel && <button
                className="button button-secondary"
                type="button"
                onClick={() => {
                  setCancelErrorMessage("");
                  setShowCancelConfirmation(true);
                }}
              >
                OTKAŽI PROBU
              </button>}
              {selectedSection?.access.can_close && <button className="button button-primary" type="button" onClick={() => setShowCloseConfirmation(true)}>
                ZATVORI PROBU
              </button>}
            </div>
          )}
          {session.status === "CLOSED" && selectedSection?.access.can_edit_closed && (
            <p className="attendance-closed-note">Dodirom na člana možete izvršiti ispravku. Razlog izmene je obavezan.</p>
          )}
        </section>
      )}

      {showCloseConfirmation && session && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="close-attendance-title">
          <section className="card modal-card attendance-modal">
            <p className="eyebrow">Potvrda</p>
            <h2 id="close-attendance-title">Zatvoriti probu?</h2>
            <p>
              Članovi: {presentCount} prisutnih · {absentCount} odsutnih
              {accompanists.length > 0
                ? ` · Korepetitori: ${presentAccompanistCount}/${accompanists.length}`
                : ""}
            </p>
            <div className="header-actions">
              <button className="button button-secondary" type="button" disabled={isClosing} onClick={() => setShowCloseConfirmation(false)}>OTKAŽI</button>
              <button className="button button-primary" type="button" disabled={isClosing} onClick={() => void handleCloseSession()}>{isClosing ? "ZATVARANJE..." : "ZATVORI PROBU"}</button>
            </div>
          </section>
        </div>
      )}

      {showCancelConfirmation && session && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="cancel-attendance-title">
          <section className="card modal-card attendance-modal">
            <p className="eyebrow">Otkazivanje</p>
            <h2 id="cancel-attendance-title">Otkazati ovu probu?</h2>
            <p>Proba neće biti obrisana, već označena kao otkazana. Evidentirani podaci neće se računati kao održana proba.</p>
            {cancelErrorMessage && (
              <p className="attendance-modal-error" role="alert">
                {cancelErrorMessage}
              </p>
            )}
            <div className="header-actions">
              <button
                className="button button-secondary"
                type="button"
                disabled={isCancelling}
                onClick={() => {
                  setCancelErrorMessage("");
                  setShowCancelConfirmation(false);
                }}
              >
                NE, NASTAVI PROBU
              </button>
              <button className="button button-primary" type="button" disabled={isCancelling} onClick={() => void handleCancelSession()}>{isCancelling ? "OTKAZIVANJE..." : "DA, OTKAŽI PROBU"}</button>
            </div>
          </section>
        </div>
      )}

      {pendingCorrection && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="correction-title">
          <section className="card modal-card attendance-modal">
            <p className="eyebrow">Predsednička ispravka</p>
            <h2 id="correction-title">{pendingCorrection.member.name}</h2>
            <p>{pendingCorrection.member.status === "PRESENT" ? "PRISUTAN" : "ODSUTAN"} → {pendingCorrection.nextStatus === "PRESENT" ? "PRISUTAN" : "ODSUTAN"}</p>
            <label className="form-field">
              <span>Razlog izmene</span>
              <textarea className="input" rows={4} value={correctionReason} onChange={(event) => setCorrectionReason(event.target.value)} autoFocus />
            </label>
            <div className="header-actions">
              <button className="button button-secondary" type="button" onClick={() => setPendingCorrection(null)}>OTKAŽI</button>
              <button
                className="button button-primary"
                type="button"
                disabled={!correctionReason.trim() || savingRecordIds.includes(pendingCorrection.member.id)}
                onClick={() => {
                  const correction = pendingCorrection;
                  setPendingCorrection(null);
                  void saveStatus(correction.member, correction.nextStatus, correctionReason.trim());
                }}
              >POTVRDI IZMENU</button>
            </div>
          </section>
        </div>
      )}
        </>
      ) : (
        <AttendanceHistory
          isGuardian={isGuardian}
          society={society}
        />
      )}
    </>
  );
}

function AttendanceColumn({
  title,
  members,
  canEdit,
  savingRecordIds,
  onMemberClick
}: {
  title: string;
  members: AttendanceMember[];
  canEdit: boolean;
  savingRecordIds: string[];
  onMemberClick: (member: AttendanceMember) => void;
}) {
  return (
    <section className="attendance-gender-column">
      <header>
        <h3>{title}</h3>
        <span>{members.length}</span>
      </header>
      <div className="attendance-member-list">
        {members.map((member) => (
          <AttendanceMemberButton
            key={member.id}
            member={member}
            canEdit={canEdit}
            isSaving={savingRecordIds.includes(member.id)}
            onClick={onMemberClick}
          />
        ))}
        {members.length === 0 && (
          <p className="attendance-column-empty">Nema članova u ovoj grupi.</p>
        )}
      </div>
    </section>
  );
}

function AttendanceMemberButton({
  member,
  canEdit,
  isSaving,
  onClick
}: {
  member: AttendanceMember;
  canEdit: boolean;
  isSaving: boolean;
  onClick: (member: AttendanceMember) => void;
}) {
  const isPresent = member.status === "PRESENT";
  return (
    <button
      className={`attendance-member ${isPresent ? "present" : "absent"}`}
      type="button"
      disabled={!canEdit || isSaving}
      onClick={() => onClick(member)}
    >
      <span className="attendance-member-icon">{isPresent ? "✓" : "×"}</span>
      <span className="attendance-member-name">
        <strong>{member.name}</strong>
        {member.roleLabel && <small>{member.roleLabel}</small>}
      </span>
      <span>{isSaving ? "ČUVANJE..." : isPresent ? "PRISUTAN" : "ODSUTAN"}</span>
    </button>
  );
}
