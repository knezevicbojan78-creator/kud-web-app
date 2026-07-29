"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import {
  getSupabaseClient,
  type AttendanceRecord,
  type AttendanceSession,
  type AttendanceStatus,
  type Section,
  type Society
} from "../_lib/supabaseClient";

type HistorySession = AttendanceSession & {
  sectionName: string;
  presentCount: number;
  absentCount: number;
  accompanistPresentCount: number;
  accompanistAbsentCount: number;
};

type HistoryMember = AttendanceRecord & {
  name: string;
  participantType: "MEMBER" | "ACCOMPANIST";
  roleLabel: string | null;
};

type PendingCorrection = {
  member: HistoryMember;
  nextStatus: AttendanceStatus;
} | null;

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) {
    return String(error.message);
  }
  return "Podaci trenutno nisu dostupni.";
}

function dateTime(value: string | null) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  }).format(new Date(value));
}

function duration(session: AttendanceSession) {
  const end = session.closed_at ?? session.cancelled_at;
  if (!end) return "U toku";
  const minutes = Math.max(
    0,
    Math.round((new Date(end).getTime() - new Date(session.opened_at).getTime()) / 60000)
  );
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return hours ? `${hours} h ${rest} min` : `${rest} min`;
}

function AttendanceDateField({
  label,
  value,
  onChange
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  const displayValue = value
    ? value.split("-").reverse().join("/")
    : "dd/mm/yyyy";

  return (
    <label className="form-field">
      <span>{label}</span>
      <div className={`uf-date-picker ${value ? "has-value" : ""}`}>
        <span>{displayValue}</span>
        <span aria-hidden="true">▣</span>
        <input
          aria-label={label}
          type="date"
          value={value}
          onChange={(event) => onChange(event.target.value)}
        />
      </div>
    </label>
  );
}

export default function AttendanceHistory({
  society,
  isGuardian = false
}: {
  society: Society | null;
  isGuardian?: boolean;
}) {
  const [allowedSections, setAllowedSections] = useState<Section[]>([]);
  const [sectionId, setSectionId] = useState("");
  const [status, setStatus] = useState<"ALL" | "CLOSED" | "CANCELLED">("ALL");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [sessions, setSessions] = useState<HistorySession[]>([]);
  const [detail, setDetail] = useState<HistorySession | null>(null);
  const [members, setMembers] = useState<HistoryMember[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isDetailLoading, setIsDetailLoading] = useState(false);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [detailError, setDetailError] = useState("");
  const [pendingCorrection, setPendingCorrection] = useState<PendingCorrection>(null);
  const [correctionReason, setCorrectionReason] = useState("");
  const [canEditDetail, setCanEditDetail] = useState(false);

  const loadHistory = useCallback(async () => {
    if (!society) return;
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data, error: historyError } = await supabase.rpc(
        isGuardian
          ? "auth_get_guardian_attendance_history"
          : "auth_get_attendance_history",
        {
          p_society_id: society.id,
          p_section_id: sectionId || null,
          p_status: status,
          p_date_from: dateFrom || null,
          p_date_to: dateTo || null,
          p_session_id: null
        }
      );
      if (historyError) throw historyError;
      setAllowedSections(data.sections ?? []);
      setSessions(data.sessions ?? []);
    } catch (loadError) {
      setAllowedSections([]);
      setSessions([]);
      setError(errorMessage(loadError));
    } finally {
      setIsLoading(false);
    }
  }, [dateFrom, dateTo, isGuardian, sectionId, society, status]);

  useEffect(() => {
    void loadHistory();
  }, [loadHistory]);

  async function openDetail(item: HistorySession) {
    setDetail(item);
    setMembers([]);
    setCanEditDetail(false);
    setDetailError("");
    setIsDetailLoading(true);
    try {
      if (!society) throw new Error("Društvo nije dostupno.");
      const supabase = getSupabaseClient();
      const { data, error: historyError } = await supabase.rpc(
        isGuardian
          ? "auth_get_guardian_attendance_history"
          : "auth_get_attendance_history",
        {
          p_society_id: society.id,
          p_section_id: sectionId || null,
          p_status: status,
          p_date_from: dateFrom || null,
          p_date_to: dateTo || null,
          p_session_id: item.id
        }
      );
      if (historyError) throw historyError;
      setMembers(data.detail_members ?? []);
      setCanEditDetail(Boolean(data.can_edit_detail));
    } catch (loadError) {
      setDetailError(errorMessage(loadError));
    } finally {
      setIsDetailLoading(false);
    }
  }

  async function saveCorrection() {
    if (!pendingCorrection || !correctionReason.trim()) return;
    setSavingId(pendingCorrection.member.id);
    setDetailError("");
    try {
      const supabase = getSupabaseClient();
      const { data: authData } = await supabase.auth.getUser();
      const { data: updated, error: updateError } = await supabase.rpc(
        "set_attendance_status",
        {
          p_record_id: pendingCorrection.member.id,
          p_new_status: pendingCorrection.nextStatus,
          p_actor_role: "Predsednik",
          p_reason: correctionReason.trim(),
          p_actor_user_id: authData.user?.id ?? null
        }
      );
      if (updateError) throw updateError;
      setMembers((current) =>
        current.map((item) =>
          item.id === pendingCorrection.member.id
            ? { ...item, ...(updated as AttendanceRecord) }
            : item
        )
      );
      setPendingCorrection(null);
      setCorrectionReason("");
      await loadHistory();
    } catch (saveError) {
      setDetailError(errorMessage(saveError));
    } finally {
      setSavingId(null);
    }
  }

  const total = useMemo(
    () =>
      sessions.reduce(
        (sum, item) =>
          sum +
          item.presentCount +
          item.absentCount +
          item.accompanistPresentCount +
          item.accompanistAbsentCount,
        0
      ),
    [sessions]
  );

  return (
    <>
      <section className="card attendance-history-filters">
        <label className="form-field">
          <span>Sekcija</span>
          <select className="input" value={sectionId} onChange={(event) => setSectionId(event.target.value)}>
            <option value="">Sve dostupne sekcije</option>
            {allowedSections.map((section) => <option key={section.id} value={section.id}>{section.name}</option>)}
          </select>
        </label>
        <AttendanceDateField label="Od datuma" value={dateFrom} onChange={setDateFrom} />
        <AttendanceDateField label="Do datuma" value={dateTo} onChange={setDateTo} />
        <label className="form-field">
          <span>Status</span>
          <select className="input" value={status} onChange={(event) => setStatus(event.target.value as typeof status)}>
            <option value="ALL">Sve probe</option>
            <option value="CLOSED">Održane</option>
            <option value="CANCELLED">Otkazane</option>
          </select>
        </label>
      </section>

      {error && <section className="card attendance-alert error" role="alert">{error}</section>}
      <section className="card attendance-history-card">
        <header className="attendance-history-heading">
          <div>
            <p className="eyebrow">Operativna istorija</p>
            <h2>Pregled proba</h2>
          </div>
          <span>{sessions.length} proba · {total} evidencija</span>
        </header>
        {isLoading ? (
          <p className="attendance-empty">Učitavanje proba...</p>
        ) : sessions.length === 0 ? (
          <p className="attendance-empty">Nema proba za izabrane filtere.</p>
        ) : (
          <div className="attendance-history-list">
            {sessions.map((item) => (
              <article className="attendance-history-row" key={item.id}>
                <div>
                  <strong>{item.sectionName}</strong>
                  <span>{dateTime(item.opened_at)}</span>
                </div>
                <span className={`attendance-status-badge ${item.status.toLowerCase()}`}>
                  {item.status === "CLOSED" ? "ODRŽANA" : "OTKAZANA"}
                </span>
                <span>
                  {duration(item)}
                  {item.status === "CLOSED" && (
                    <> · {item.close_type === "AUTOMATIC" ? "automatski" : "ručno"}</>
                  )}
                </span>
                <span>
                  <strong>{item.presentCount}</strong> prisutnih ·{" "}
                  <strong>{item.absentCount}</strong> odsutnih
                  {item.accompanistPresentCount + item.accompanistAbsentCount > 0 && (
                    <>
                      {" "}· Korepetitori{" "}
                      <strong>{item.accompanistPresentCount}</strong>/
                      {item.accompanistPresentCount + item.accompanistAbsentCount}
                    </>
                  )}
                </span>
                <button className="button button-secondary" type="button" onClick={() => void openDetail(item)}>POGLEDAJ</button>
              </article>
            ))}
          </div>
        )}
      </section>

      {detail && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="attendance-history-detail-title">
          <section className="card modal-card attendance-history-modal">
            <header className="attendance-history-heading">
              <div>
                <p className="eyebrow">{detail.status === "CLOSED" ? "Održana proba" : "Otkazana proba"}</p>
                <h2 id="attendance-history-detail-title">{detail.sectionName}</h2>
                <p>
                  {dateTime(detail.opened_at)} · {duration(detail)}
                  {detail.status === "CLOSED" && (
                    <> · {detail.close_type === "AUTOMATIC" ? "automatski zatvorena" : "ručno zatvorena"}</>
                  )}
                </p>
              </div>
              <button className="button button-secondary" type="button" onClick={() => setDetail(null)}>ZATVORI</button>
            </header>
            {detailError && <p className="attendance-modal-error" role="alert">{detailError}</p>}
            {isDetailLoading ? (
              <p className="attendance-empty">Učitavanje evidencije...</p>
            ) : (
              <div className="attendance-history-members">
                {members.map((member) => (
                  <button
                    className={`attendance-history-member ${member.status === "PRESENT" ? "present" : "absent"}`}
                    disabled={!canEditDetail || detail.status !== "CLOSED" || savingId === member.id}
                    key={member.id}
                    type="button"
                    onClick={() => {
                      setPendingCorrection({
                        member,
                        nextStatus: member.status === "PRESENT" ? "ABSENT" : "PRESENT"
                      });
                      setCorrectionReason("");
                    }}
                  >
                    <span className="attendance-history-member-name">
                      {member.name}
                      {member.roleLabel && <small>{member.roleLabel}</small>}
                    </span>
                    <span className="attendance-history-member-status">
                      <span aria-hidden="true">{member.status === "PRESENT" ? "✓" : "×"}</span>
                      {member.status === "PRESENT" ? "PRISUTAN" : "ODSUTAN"}
                    </span>
                  </button>
                ))}
                {members.length === 0 && (
                  <p className="attendance-empty">Za ovu probu nema evidentiranih članova.</p>
                )}
              </div>
            )}
            {canEditDetail && detail.status === "CLOSED" && <p className="attendance-closed-note">Izaberite člana za kontrolisanu ispravku. Razlog je obavezan.</p>}
          </section>
        </div>
      )}

      {pendingCorrection && (
        <div className="modal-backdrop attendance-nested-modal" role="dialog" aria-modal="true" aria-labelledby="history-correction-title">
          <section className="card modal-card attendance-modal">
            <p className="eyebrow">Predsednička ispravka</p>
            <h2 id="history-correction-title">{pendingCorrection.member.name}</h2>
            <p>{pendingCorrection.member.status === "PRESENT" ? "PRISUTAN" : "ODSUTAN"} → {pendingCorrection.nextStatus === "PRESENT" ? "PRISUTAN" : "ODSUTAN"}</p>
            <label className="form-field">
              <span>Razlog izmene</span>
              <textarea className="input" rows={4} value={correctionReason} onChange={(event) => setCorrectionReason(event.target.value)} autoFocus />
            </label>
            <div className="header-actions">
              <button className="button button-secondary" disabled={Boolean(savingId)} type="button" onClick={() => setPendingCorrection(null)}>OTKAŽI</button>
              <button className="button button-primary" disabled={!correctionReason.trim() || Boolean(savingId)} type="button" onClick={() => void saveCorrection()}>
                {savingId ? "ČUVANJE..." : "POTVRDI IZMENU"}
              </button>
            </div>
          </section>
        </div>
      )}
    </>
  );
}
