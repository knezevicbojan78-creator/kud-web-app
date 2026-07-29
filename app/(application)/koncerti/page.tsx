"use client";

import { useCallback, useEffect, useState } from "react";
import { UF_MEMBER_FORM, type UFMemberFormField, type UFMemberFormValues, type UFMemberGuardianField } from "../../_components/UF_MEMBER_FORM";

import {
  getSupabaseClient,
  type EventAppearance,
  type EventAppearanceRepertoire,
  type EventParticipant,
  type EventParticipantSection,
  type EventRepertoireParticipant,
  type EventSection,
  type Person,
  type RepertoireItem,
  type RepertoireItemSection,
  type Section,
  type Society,
  type SocietyEvent,
  type SocietyMember
} from "../../_lib/supabaseClient";

type EventParticipantView = EventParticipant & { name: string; person: Person };
type EventWorkspaceItem = SocietyEvent & {
  access: {
    can_view_fees: boolean;
    can_edit_draft: boolean;
    can_submit: boolean;
    can_review: boolean;
    can_edit_approved: boolean;
    can_cancel_approved: boolean;
    can_manage_sections: boolean;
    can_manage_participants: boolean;
    can_change_participant_status: boolean;
    can_manage_fee: boolean;
    can_manage_program: boolean;
  };
};
type DetailTab = "overview" | "participants" | "program";
type EventRole = "Predsednik" | "UR" | "Član";
const PARTICIPANT_STATUSES: Array<{
  value: EventParticipant["participation_status"];
  label: string;
  icon: string;
}> = [
  { value: "PLANNED", label: "Planiran", icon: "○" },
  { value: "CONFIRMED", label: "Potvrđen", icon: "✓" },
  { value: "DECLINED", label: "Odbio", icon: "!" },
  { value: "CANCELLED", label: "Otkazan", icon: "×" },
  { value: "ATTENDED", label: "Prisustvovao", icon: "●" },
  { value: "ABSENT", label: "Odsutan", icon: "—" }
];

function canSetParticipantStatus(
  currentStatus: EventParticipant["participation_status"],
  nextStatus: EventParticipant["participation_status"]
) {
  if (currentStatus === nextStatus) return false;
  const transitions: Record<
    EventParticipant["participation_status"],
    EventParticipant["participation_status"][]
  > = {
    PLANNED: ["CONFIRMED", "DECLINED"],
    DECLINED: ["PLANNED", "CONFIRMED"],
    CONFIRMED: ["CANCELLED", "ATTENDED", "ABSENT"],
    CANCELLED: [],
    ATTENDED: ["ABSENT"],
    ABSENT: ["ATTENDED"]
  };
  return transitions[currentStatus].includes(nextStatus);
}

const emptyEvent = {
  event_type: "CONCERT" as SocietyEvent["event_type"],
  title: "",
  description: "",
  country: "Srbija",
  city: "",
  venue_name: "",
  address: "",
  departure_at: "",
  return_at: "",
  meeting_point: "",
  meeting_at: "",
  organizer_name: "",
  organizer_contact: "",
  transport_type: "",
  transport_company: "",
  accommodation: "",
  has_participation_fee: false,
  default_participation_fee_amount: "",
  currency: "RSD",
  payment_due_date: "",
  fee_note: "",
  section_ids: [] as string[]
};
function emptyPassengerPerson(email = ""): UFMemberFormValues {
  return {
    is_minor_member: false, first_name: "", last_name: "", gender: "", birth_date: "",
    address: "", city: "", postal_code: "", country: "Srbija", jmbg: "",
    passport_number: "", passport_expiry_date: "", email, phone: "", shoe_size: "", status: "ACTIVE",
    parental_travel_consent: false, parental_travel_consent_valid_until: "",
    start_date: "", membership_fee_required: false, membership_fee_amount: "",
    guardian1: { first_name: "", last_name: "", email: "", phone: "" },
    guardian2: { first_name: "", last_name: "", email: "", phone: "" },
    showGuardian2: false, selectedFunctionIds: [], selectedSectionIds: []
  };
}

function messageOf(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) return String(error.message);
  return "Akcija nije uspela.";
}
function dateTime(value: string | null) {
  if (!value) return "Nije određeno";
  return new Intl.DateTimeFormat("sr-Latn-RS", {
    day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit"
  }).format(new Date(value));
}
function toDbDateTime(value: string) {
  return value ? new Date(value).toISOString() : null;
}
function toLocalDateTimeInput(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hour = String(date.getHours()).padStart(2, "0");
  const minute = String(date.getMinutes()).padStart(2, "0");
  return `${year}-${month}-${day}T${hour}:${minute}`;
}
const EVENT_HOURS = Array.from({ length: 24 }, (_, index) => String(index).padStart(2, "0"));
const EVENT_MINUTES = ["00", "15", "30", "45"];
function displayCalendarDate(value: string) {
  if (!value) return "dd.mm.yyyy";
  const [year, month, day] = value.split("-");
  return `${day}.${month}.${year}`;
}
function combineDateAndTime(date: string, hour: string, minute: string) {
  if (!date || !hour || !minute) return "";
  const [year, month, day] = date.split("-");
  const time = `${hour}:${minute}`;
  const candidate = new Date(`${date}T${time}:00`);
  if (
    Number.isNaN(candidate.getTime()) ||
    candidate.getFullYear() !== Number(year) ||
    candidate.getMonth() + 1 !== Number(month) ||
    candidate.getDate() !== Number(day)
  ) return "";
  return `${year}-${month}-${day}T${time}`;
}
function DateTimeField({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) {
  const initialTime = value.includes("T") ? value.split("T")[1]?.slice(0, 5).split(":") : [];
  const [date, setDate] = useState(value.includes("T") ? value.split("T")[0] : "");
  const [hour, setHour] = useState(initialTime[0] ?? "");
  const [minute, setMinute] = useState(initialTime[1] ?? "");

  function commit(nextDate: string, nextHour: string, nextMinute: string) {
    const combined = combineDateAndTime(nextDate, nextHour, nextMinute);
    if (combined) onChange(combined);
    else onChange("");
  }

  return <label className="form-field"><span>{label}</span><div className="datetime-parts">
    <div className={`date-picker-control ${date ? "has-value" : ""}`}>
      <span>{displayCalendarDate(date)}</span><span aria-hidden="true">▣</span>
      <input aria-label={`${label} datum`} type="date" value={date} onChange={(event) => { setDate(event.target.value); commit(event.target.value, hour, minute); }} />
    </div>
    <div className="time-selects">
      <select className="input" aria-label={`${label} sat`} value={hour} onChange={(event) => { setHour(event.target.value); commit(date, event.target.value, minute); }}><option value="">Sat</option>{EVENT_HOURS.map((option) => <option key={option}>{option}</option>)}</select>
      <span>:</span>
      <select className="input" aria-label={`${label} minuti`} value={minute} onChange={(event) => { setMinute(event.target.value); commit(date, hour, event.target.value); }}><option value="">Min</option>{EVENT_MINUTES.map((option) => <option key={option}>{option}</option>)}</select>
    </div>
  </div></label>;
}
function personName(person: Person) {
  return `${person.first_name} ${person.last_name}`.trim();
}
function statusLabel(status: SocietyEvent["status"]) {
  return {
    DRAFT: "NACRT", PENDING: "ČEKA ODOBRENJE", APPROVED: "ODOBREN",
    REJECTED: "ODBIJEN", CANCELLED: "OTKAZAN", COMPLETED: "ZAVRŠEN"
  }[status];
}

export default function DogadjajiPage() {
  const [role, setRole] = useState<EventRole | null>(null);
  const [society, setSociety] = useState<Society | null>(null);
  const [actorMemberId, setActorMemberId] = useState<string | null>(null);
  const [sections, setSections] = useState<Section[]>([]);
  const [events, setEvents] = useState<EventWorkspaceItem[]>([]);
  const [canCreateEvent, setCanCreateEvent] = useState(false);
  const [canManageNewEventFee, setCanManageNewEventFee] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [eventSections, setEventSections] = useState<EventSection[]>([]);
  const [participants, setParticipants] = useState<EventParticipantView[]>([]);
  const [participantSectionLinks, setParticipantSectionLinks] = useState<EventParticipantSection[]>([]);
  const [appearances, setAppearances] = useState<EventAppearance[]>([]);
  const [program, setProgram] = useState<EventAppearanceRepertoire[]>([]);
  const [performerLinks, setPerformerLinks] = useState<EventRepertoireParticipant[]>([]);
  const [repertoire, setRepertoire] = useState<RepertoireItem[]>([]);
  const [repertoireSectionLinks, setRepertoireSectionLinks] = useState<RepertoireItemSection[]>([]);
  const [activeTab, setActiveTab] = useState<DetailTab>("overview");
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [eventForm, setEventForm] = useState(emptyEvent);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [editForm, setEditForm] = useState(emptyEvent);
  const [isSaving, setIsSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [reason, setReason] = useState("");

  const [memberCandidates, setMemberCandidates] = useState<Array<{ member: SocietyMember; person: Person }>>([]);
  const [guest, setGuest] = useState({ first_name: "", last_name: "", email: "", phone: "" });
  const [showGuestForm, setShowGuestForm] = useState(false);
  const [passengerLookup, setPassengerLookup] = useState<"idle" | "checking" | "existing" | "new">("idle");
  const [existingPassenger, setExistingPassenger] = useState<Person | null>(null);
  const [passengerSuggestions, setPassengerSuggestions] = useState<Person[]>([]);
  const [passengerSearchComplete, setPassengerSearchComplete] = useState(false);
  const [participantStatusFilters, setParticipantStatusFilters] = useState<EventParticipant["participation_status"][]>([]);
  const [isNewPassengerFormOpen, setIsNewPassengerFormOpen] = useState(false);
  const [passengerPersonValues, setPassengerPersonValues] = useState<UFMemberFormValues>(() => emptyPassengerPerson());
  const [appearanceForm, setAppearanceForm] = useState({ title: "", starts_at: "", ends_at: "", city: "", venue_name: "" });
  const [programForm, setProgramForm] = useState({ appearanceId: "", eventSectionId: "", repertoireId: "" });
  const [showAppearanceForm, setShowAppearanceForm] = useState(false);
  const [showProgramForm, setShowProgramForm] = useState(false);
  const [performerPickerItem, setPerformerPickerItem] = useState<EventAppearanceRepertoire | null>(null);

  const selectedEvent = events.find((item) => item.id === selectedId) ?? null;
  const loadDetail = useCallback(async (eventId: string) => {
    const supabase = getSupabaseClient();
    if (!society) return;
    const { data: workspace, error: workspaceError } = await supabase.rpc(
      "auth_get_events_workspace",
      { p_society_id: society.id, p_event_id: eventId }
    );
    if (workspaceError) throw workspaceError;
    const detail = workspace.detail;
    setEventSections(detail?.event_sections ?? []);
    setParticipants(detail?.participants ?? []);
    setParticipantSectionLinks(detail?.participant_section_links ?? []);
    setAppearances(detail?.appearances ?? []);
    setProgram(detail?.program ?? []);
    setPerformerLinks(detail?.performer_links ?? []);
  }, [society?.id]);

  const loadPage = useCallback(async () => {
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: context, error: contextError } =
        await supabase.rpc("auth_get_application_context");
      if (contextError) throw contextError;
      const membership = context?.memberships?.[0] ?? null;
      if (!membership) throw new Error("Aktivno članstvo nije pronađeno.");
      const actualRole: EventRole = membership.functions.includes("Predsednik")
        ? "Predsednik"
        : membership.functions.includes("UR")
          ? "UR"
          : "Član";
      setRole(actualRole);
      const { data: workspace, error: workspaceError } =
        await supabase.rpc("auth_get_society_workspace", {
          p_society_id: membership.society_id
        });
      if (workspaceError) throw workspaceError;
      const activeSociety = workspace?.society ?? null;
      setSociety(activeSociety);
      if (!activeSociety) return;
      setActorMemberId(membership.society_member_id);
      const { data: eventsWorkspace, error: eventsWorkspaceError } =
        await supabase.rpc("auth_get_events_workspace", {
          p_society_id: activeSociety.id,
          p_event_id: null
        });
      if (eventsWorkspaceError) throw eventsWorkspaceError;
      setSections(eventsWorkspace.sections ?? []);
      setEvents(eventsWorkspace.events ?? []);
      setCanCreateEvent(Boolean(eventsWorkspace.access?.can_create));
      setCanManageNewEventFee(Boolean(eventsWorkspace.access?.can_manage_fee));
      setRepertoire(eventsWorkspace.repertoire ?? []);
      setRepertoireSectionLinks(eventsWorkspace.repertoire_section_links ?? []);
      const nextId = selectedId && (eventsWorkspace.events ?? []).some((item) => item.id === selectedId)
        ? selectedId : eventsWorkspace.events?.[0]?.id ?? null;
      setSelectedId(nextId);
      if (nextId) await loadDetail(nextId);
    } catch (loadError) {
      setError(messageOf(loadError));
    } finally {
      setIsLoading(false);
    }
  }, [loadDetail, selectedId]);
  useEffect(() => { void loadPage(); }, [loadPage]);
  useEffect(() => { if (selectedId) void loadDetail(selectedId).catch((e) => setError(messageOf(e))); }, [loadDetail, selectedId]);
  useEffect(() => { setParticipantStatusFilters([]); }, [selectedId]);
  useEffect(() => {
    if (!message) return;
    const timeoutId = window.setTimeout(() => setMessage(""), 3000);
    return () => window.clearTimeout(timeoutId);
  }, [message]);
  useEffect(() => {
    if (!showGuestForm || passengerLookup === "existing" || passengerLookup === "new") return;
    const email = guest.email.trim().toLowerCase();
    setPassengerSearchComplete(false);
    if (email.length < 2) {
      setPassengerSuggestions([]);
      setPassengerLookup("idle");
      return;
    }
    setPassengerLookup("checking");
    const timeoutId = window.setTimeout(async () => {
      if (!selectedEvent) return;
      const { data, error: lookupError } = await getSupabaseClient().rpc(
        "auth_search_event_people",
        { p_event_id: selectedEvent.id, p_query: email }
      );
      if (lookupError) {
        setError(messageOf(lookupError));
        setPassengerSuggestions([]);
      } else {
        setPassengerSuggestions(data ?? []);
      }
      setPassengerSearchComplete(true);
      setPassengerLookup("idle");
    }, 300);
    return () => window.clearTimeout(timeoutId);
  }, [guest.email, selectedEvent, showGuestForm]);

  async function createEvent() {
    if (!society || !role) return;
    if (!eventForm.title.trim() || !eventForm.city.trim() || eventForm.section_ids.length === 0) {
      setError("Unesite naziv i mesto i izaberite najmanje jednu sekciju.");
      return;
    }
    if (eventForm.has_participation_fee && (!eventForm.default_participation_fee_amount || Number(eventForm.default_participation_fee_amount) < 0 || eventForm.currency.trim().length !== 3 || !eventForm.payment_due_date)) {
      setError("Za kotizaciju unesite iznos, troslovnu valutu i krajnji rok plaćanja.");
      return;
    }
    setIsSaving(true); setError("");
    try {
      const { data, error: insertError } = await getSupabaseClient().rpc(
        "auth_manage_event",
        {
          p_action: "CREATE_EVENT",
          p_payload: {
        society_id: society.id,
        event_type: eventForm.event_type,
        title: eventForm.title.trim(),
        description: eventForm.description.trim() || null,
        country: eventForm.country.trim() || "Srbija",
        city: eventForm.city.trim() || null,
        venue_name: eventForm.venue_name.trim() || null,
        address: eventForm.address.trim() || null,
        departure_at: toDbDateTime(eventForm.departure_at),
        return_at: toDbDateTime(eventForm.return_at),
        meeting_point: eventForm.meeting_point.trim() || null,
        meeting_at: toDbDateTime(eventForm.meeting_at),
        organizer_name: eventForm.organizer_name.trim() || null,
        organizer_contact: eventForm.organizer_contact.trim() || null,
        transport_type: eventForm.transport_type.trim() || null,
        transport_company: eventForm.transport_company.trim() || null,
        accommodation: eventForm.accommodation.trim() || null,
        has_participation_fee: eventForm.has_participation_fee,
        default_participation_fee_amount: eventForm.has_participation_fee ? Number(eventForm.default_participation_fee_amount || 0) : null,
        currency: eventForm.currency,
        payment_due_date: eventForm.payment_due_date || null,
        fee_note: eventForm.fee_note.trim() || null,
            section_ids: eventForm.section_ids
          }
        }
      );
      if (insertError) throw insertError;
      if (!data?.id) throw new Error("Događaj nije kreiran.");
      setEventForm(emptyEvent);
      setIsCreateOpen(false);
      await loadPage();
      setSelectedId(data.id);
      await loadDetail(data.id);
      setMessage(role === "Predsednik" ? "Događaj je kreiran i odobren." : "Događaj je sačuvan kao nacrt.");
    } catch (saveError) { setError(messageOf(saveError)); }
    finally { setIsSaving(false); }
  }

  function openEventEdit() {
    if (!selectedEvent) return;
    setError("");
    setEditForm({
      ...emptyEvent,
      event_type: selectedEvent.event_type,
      title: selectedEvent.title,
      description: selectedEvent.description ?? "",
      country: selectedEvent.country,
      city: selectedEvent.city ?? "",
      departure_at: toLocalDateTimeInput(selectedEvent.departure_at),
      return_at: toLocalDateTimeInput(selectedEvent.return_at),
      has_participation_fee: selectedEvent.has_participation_fee,
      default_participation_fee_amount: selectedEvent.default_participation_fee_amount?.toString() ?? "",
      currency: selectedEvent.currency,
      payment_due_date: selectedEvent.payment_due_date ?? "",
      fee_note: selectedEvent.fee_note ?? ""
    });
    setIsEditOpen(true);
  }

  async function saveEventEdit() {
    if (!selectedEvent) return;
    if (!editForm.title.trim() || !editForm.city.trim()) {
      setError("Naziv i mesto su obavezni.");
      return;
    }
    if (editForm.has_participation_fee && (!editForm.default_participation_fee_amount || Number(editForm.default_participation_fee_amount) < 0 || editForm.currency.trim().length !== 3 || !editForm.payment_due_date)) {
      setError("Za kotizaciju unesite iznos, troslovnu valutu i krajnji rok plaćanja.");
      return;
    }
    setIsSaving(true);
    setError("");
    try {
      const { error: updateError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "UPDATE_EVENT",
        p_payload: {
        event_id: selectedEvent.id,
        event_type: editForm.event_type,
        title: editForm.title.trim(),
        description: editForm.description.trim() || null,
        country: editForm.country.trim() || "Srbija",
        city: editForm.city.trim(),
        departure_at: toDbDateTime(editForm.departure_at),
        return_at: toDbDateTime(editForm.return_at),
        has_participation_fee: editForm.has_participation_fee,
        default_participation_fee_amount: editForm.has_participation_fee ? Number(editForm.default_participation_fee_amount || 0) : null,
        currency: editForm.currency,
        payment_due_date: editForm.has_participation_fee ? editForm.payment_due_date : null,
        fee_note: editForm.has_participation_fee ? editForm.fee_note.trim() || null : null
        }
      });
      if (updateError) throw updateError;
      setIsEditOpen(false);
      await loadPage();
      setMessage("Izmene događaja su sačuvane.");
    } catch (updateError) { setError(messageOf(updateError)); }
    finally { setIsSaving(false); }
  }

  async function runWorkflow(action: "submit" | "approve" | "reject" | "cancel" | "complete") {
    if (!selectedEvent || !role) return;
    if (action === "approve" && eventSections.length === 0) {
      setError("Pre odobravanja izaberite najmanje jednu sekciju događaja.");
      setActiveTab("participants");
      return;
    }
    setIsSaving(true); setError("");
    try {
      const supabase = getSupabaseClient();
      if (action === "cancel") {
        if (!actorMemberId) throw new Error("Prijavljeni korisnik nije povezan sa članom društva.");
        const { error: cancelError } = await supabase.rpc("finance_cancel_event", {
          p_event_id: selectedEvent.id,
          p_reason: reason.trim(),
          p_actor_member_id: actorMemberId
        });
        if (cancelError) throw cancelError;
        setReason("");
        await loadPage();
        return;
      }
      const { error: rpcError } = await supabase.rpc("auth_manage_event", {
        p_action: action.toUpperCase(),
        p_payload: {
          event_id: selectedEvent.id,
          reason: reason.trim() || null
        }
      });
      if (rpcError) throw rpcError;
      setReason("");
      await loadPage();
    } catch (workflowError) { setError(messageOf(workflowError)); }
    finally { setIsSaving(false); }
  }

  async function toggleEventSection(section: Section) {
    if (!selectedEvent) return;
    setIsSaving(true);
    setError("");
    try {
      const existing = eventSections.find((item) => item.section_id === section.id);
      const supabase = getSupabaseClient();
      if (existing) {
        if (!selectedEvent.access.can_manage_sections) throw new Error("Nemate dozvolu za uklanjanje sekcije događaja.");
        if (!actorMemberId) throw new Error("Prijavljeni korisnik nije povezan sa članom društva.");
        const cancellationReason = window.prompt(`Unesite razlog otkazivanja sekcije „${section.name}“:`, "")?.trim() ?? "";
        if (!cancellationReason) return;
        const confirmed = window.confirm(
          `Potvrdite otkazivanje sekcije „${section.name}“.\n\nOtvorene kotizacije učesnika koji nisu povezani sa drugom sekcijom biće poništene. Plaćeni iznosi postaće kredit.`
        );
        if (!confirmed) return;
        const { data: cancellationResult, error: sectionError } = await supabase.rpc("finance_cancel_event_section", {
          p_event_section_id: existing.id,
          p_reason: cancellationReason,
          p_actor_member_id: actorMemberId
        });
        if (sectionError) throw sectionError;
        setMessage(
          `${section.name} je otkazana. Poništene kotizacije: ${cancellationResult.cancelled_obligations}; uklonjeni nepotvrđeni učesnici: ${cancellationResult.removed_unconfirmed_participants}.`
        );
      } else {
        const { error: sectionError } = await supabase.rpc("auth_manage_event", {
          p_action: "ADD_SECTION",
          p_payload: {
            event_id: selectedEvent.id,
            section_id: section.id
          }
        });
        if (sectionError) throw sectionError;
        setMessage(`${section.name}: članovi su dodati u planirani spisak.`);
      }
      await loadDetail(selectedEvent.id);
    } catch (sectionError) { setError(messageOf(sectionError)); }
    finally { setIsSaving(false); }
  }

  async function loadMemberCandidates(eventSectionId: string) {
    try {
      const { data, error: candidateError } = await getSupabaseClient().rpc(
        "auth_list_event_section_candidates",
        { p_event_section_id: eventSectionId }
      );
      if (candidateError) throw candidateError;
      setMemberCandidates(data ?? []);
    } catch (candidateError) { setError(messageOf(candidateError)); }
  }

  async function addGuest() {
    if (!selectedEvent || !guest.email.trim() || passengerLookup === "idle" || passengerLookup === "checking") return;
    if (passengerLookup === "new" && (!guest.first_name.trim() || !guest.last_name.trim())) return;
    setIsSaving(true);
    try {
      const { error: participantError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "ADD_PERSON",
        p_payload: {
          event_id: selectedEvent.id,
          person_id: existingPassenger?.id ?? null,
          first_name: guest.first_name.trim(),
          last_name: guest.last_name.trim(),
          email: guest.email.trim().toLowerCase(),
          phone: guest.phone.trim() || null,
          country: "Srbija"
        }
      });
      if (participantError) throw participantError;
      setGuest({ first_name: "", last_name: "", email: "", phone: "" });
      setShowGuestForm(false);
      setPassengerLookup("idle");
      setExistingPassenger(null);
      await loadDetail(selectedEvent.id);
    } catch (guestError) { setError(messageOf(guestError)); }
    finally { setIsSaving(false); }
  }

  async function createPassengerPerson() {
    if (!selectedEvent) return;
    setIsSaving(true);
    setError("");
    try {
      const { error: personError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "ADD_PERSON",
        p_payload: {
        event_id: selectedEvent.id,
        first_name: passengerPersonValues.first_name.trim(),
        last_name: passengerPersonValues.last_name.trim(),
        gender: passengerPersonValues.gender || null,
        birth_date: passengerPersonValues.birth_date || null,
        address: passengerPersonValues.address.trim() || null,
        city: passengerPersonValues.city.trim() || null,
        postal_code: passengerPersonValues.postal_code.trim() || null,
        country: passengerPersonValues.country.trim() || "Srbija",
        jmbg: passengerPersonValues.jmbg.trim() || null,
        passport_number: passengerPersonValues.passport_number.trim() || null,
        passport_expiry_date: passengerPersonValues.passport_expiry_date || null,
        parental_travel_consent: passengerPersonValues.parental_travel_consent,
        parental_travel_consent_valid_until: passengerPersonValues.parental_travel_consent ? passengerPersonValues.parental_travel_consent_valid_until || null : null,
        email: passengerPersonValues.email.trim().toLowerCase(),
        phone: passengerPersonValues.phone.trim() || null
        }
      });
      if (personError) throw personError;
      setIsNewPassengerFormOpen(false);
      setShowGuestForm(false);
      setPassengerLookup("idle");
      setPassengerSuggestions([]);
      setPassengerSearchComplete(false);
      setGuest({ first_name: "", last_name: "", email: "", phone: "" });
      setPassengerPersonValues(emptyPassengerPerson());
      await loadDetail(selectedEvent.id);
      setMessage("Novi putnik je sačuvan u people bazi i dodat događaju.");
    } catch (personError) { setError(messageOf(personError)); }
    finally { setIsSaving(false); }
  }

  async function changeParticipantStatus(participant: EventParticipantView, status: EventParticipant["participation_status"]) {
    if (!role) return;
    setIsSaving(true);
    setError("");
    try {
      if (!actorMemberId) throw new Error("Prijavljeni korisnik nije povezan sa članom društva.");
      const cancellationReason = status === "CANCELLED"
        ? window.prompt("Unesite razlog otkazivanja učešća:", "")?.trim() ?? ""
        : "";
      if (status === "CANCELLED" && !cancellationReason) return;
      const { error: statusError } = await getSupabaseClient().rpc("finance_set_event_participant_status", {
        p_event_participant_id: participant.id,
        p_new_status: status,
        p_reason: cancellationReason,
        p_actor_member_id: actorMemberId
      });
      if (statusError) throw statusError;
      if (selectedEvent) await loadDetail(selectedEvent.id);
      setMessage(status === "CONFIRMED"
        ? `Učešće za ${participant.name} je potvrđeno i kotizacija je formirana.`
        : `Status učesnika ${participant.name} je promenjen.`);
    } catch (statusError) { setError(messageOf(statusError)); }
    finally { setIsSaving(false); }
  }

  async function addAppearance() {
    if (!selectedEvent || !appearanceForm.title.trim()) return;
    setIsSaving(true);
    try {
      const { error: appearanceError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "ADD_APPEARANCE",
        p_payload: {
        event_id: selectedEvent.id,
        title: appearanceForm.title.trim(),
        starts_at: toDbDateTime(appearanceForm.starts_at), ends_at: null,
        country: selectedEvent.country, city: appearanceForm.city.trim() || selectedEvent.city,
        venue_name: appearanceForm.venue_name.trim() || selectedEvent.venue_name,
        performance_order: appearances.length
        }
      });
      if (appearanceError) throw appearanceError;
      setAppearanceForm({ title: "", starts_at: "", ends_at: "", city: "", venue_name: "" });
      setShowAppearanceForm(false);
      await loadDetail(selectedEvent.id);
    } catch (appearanceError) { setError(messageOf(appearanceError)); }
    finally { setIsSaving(false); }
  }

  async function addProgramItem() {
    if (!selectedEvent || !programForm.appearanceId || !programForm.eventSectionId || !programForm.repertoireId) return;
    setIsSaving(true);
    try {
      const { error: programError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "ADD_PROGRAM_ITEM",
        p_payload: {
        event_id: selectedEvent.id,
        event_appearance_id: programForm.appearanceId,
        event_section_id: programForm.eventSectionId,
        repertoire_item_id: programForm.repertoireId,
        performance_order: program.filter((item) => item.event_appearance_id === programForm.appearanceId).length
        }
      });
      if (programError) throw programError;
      setProgramForm((current) => ({ ...current, repertoireId: "" }));
      setShowProgramForm(false);
      await loadDetail(selectedEvent.id);
    } catch (programError) { setError(messageOf(programError)); }
    finally { setIsSaving(false); }
  }

  async function togglePerformer(programItem: EventAppearanceRepertoire, participant: EventParticipantView) {
    if (!selectedEvent) return;
    const existing = performerLinks.find((link) =>
      link.event_appearance_repertoire_id === programItem.id && link.event_participant_id === participant.id
    );
    try {
      const { error: performerError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "TOGGLE_PERFORMER",
        p_payload: {
          event_appearance_repertoire_id: programItem.id,
          event_participant_id: participant.id
        }
      });
      if (performerError) throw performerError;
      await loadDetail(selectedEvent.id);
    } catch (performerError) { setError(messageOf(performerError)); }
  }

  async function openPerformerPicker(programItem: EventAppearanceRepertoire) {
    setError("");
    await loadMemberCandidates(programItem.event_section_id);
    setPerformerPickerItem(programItem);
  }

  async function toggleCandidatePerformer(candidate: { member: SocietyMember; person: Person }) {
    if (!selectedEvent || !performerPickerItem) return;
    setIsSaving(true);
    setError("");
    try {
      let participant = participants.find((item) => item.person_id === candidate.person.id);
      const { error: performerError } = await getSupabaseClient().rpc("auth_manage_event", {
        p_action: "TOGGLE_PERFORMER",
        p_payload: {
          event_appearance_repertoire_id: performerPickerItem.id,
          event_section_id: performerPickerItem.event_section_id,
          event_participant_id: participant?.id ?? null,
          person_id: candidate.person.id,
          society_member_id: candidate.member.id
        }
      });
      if (performerError) throw performerError;
      await loadDetail(selectedEvent.id);
    } catch (performerError) { setError(messageOf(performerError)); }
    finally { setIsSaving(false); }
  }

  function toggleParticipantStatusFilter(status: EventParticipant["participation_status"]) {
    setParticipantStatusFilters((current) =>
      current.includes(status)
        ? current.filter((item) => item !== status)
        : [...current, status]
    );
  }

  const visibleParticipants = participantStatusFilters.length === 0
    ? participants
    : participants.filter((participant) => participantStatusFilters.includes(participant.participation_status));

  return (
    <>
      <section className="page-heading events-page-heading">
        <h1>Događaji</h1>
        {canCreateEvent && <button className="button button-primary" type="button" onClick={() => setIsCreateOpen(true)}>+ NOVI DOGAĐAJ</button>}
      </section>
      {message && <section className="card attendance-alert">{message}</section>}
      {error && <section className="card attendance-alert error" role="alert">{error}</section>}

      <section className="events-layout">
        <aside className="card events-list-card">
          <div className="events-list-heading"><strong>Događaji</strong><span>{events.length}</span></div>
          {events.map((item) => (
            <button className={`event-list-item ${selectedId === item.id ? "active" : ""}`} key={item.id} type="button" onClick={() => { setSelectedId(item.id); setActiveTab("overview"); }}>
              <span className={`event-type-icon ${item.event_type.toLowerCase()}`}>{item.event_type === "TRIP" ? "✈" : "♪"}</span>
              <span><strong>{item.title}</strong><small>{item.city || item.country} · {dateTime(item.departure_at)}</small></span>
              <span className={`event-status ${item.status.toLowerCase()}`}>{statusLabel(item.status)}</span>
            </button>
          ))}
          {!isLoading && events.length === 0 && <p className="attendance-empty">Nema događaja.</p>}
        </aside>

        {selectedEvent ? (
          <main className="card events-detail">
            <header className="events-detail-header">
              <div className="event-title-line">
                <span className="eyebrow">{selectedEvent.event_type === "TRIP" ? "Putovanje" : "Koncert"}</span>
                <h2>{selectedEvent.title}</h2>
                <span className="event-title-location">{selectedEvent.city || selectedEvent.country}</span>
              </div>
              <span className={`event-status ${selectedEvent.status.toLowerCase()}`}>{statusLabel(selectedEvent.status)}</span>
            </header>
            <nav className="section-tabs">
              <button className={activeTab === "overview" ? "active" : ""} onClick={() => setActiveTab("overview")} type="button">Pregled</button>
              <button className={activeTab === "participants" ? "active" : ""} onClick={() => setActiveTab("participants")} type="button">Sekcije i učesnici</button>
              <button className={activeTab === "program" ? "active" : ""} onClick={() => setActiveTab("program")} type="button">Program</button>
            </nav>

            {activeTab === "overview" && <section className="event-tab-panel">
              <div className="event-facts">
                <div><span>Polazak</span><strong>{dateTime(selectedEvent.departure_at)}</strong></div>
                <div><span>Povratak</span><strong>{dateTime(selectedEvent.return_at)}</strong></div>
                <div><span>Sekcije</span><strong>{eventSections.length}</strong></div>
                <div><span>Učesnici</span><strong>{participants.length}</strong></div>
                {selectedEvent.access.can_view_fees && <div><span>Finansijsko učešće</span><strong>{selectedEvent.has_participation_fee ? `${selectedEvent.default_participation_fee_amount} ${selectedEvent.currency}` : "Nema"}</strong></div>}
                {selectedEvent.access.can_view_fees && selectedEvent.has_participation_fee && <div><span>Rok plaćanja</span><strong>{selectedEvent.payment_due_date ? displayCalendarDate(selectedEvent.payment_due_date) : "Nije određen"}</strong></div>}
                {selectedEvent.access.can_view_fees && selectedEvent.has_participation_fee && selectedEvent.fee_note && <div><span>Napomena za kotizaciju</span><strong>{selectedEvent.fee_note}</strong></div>}
              </div>
              {selectedEvent.description && <p>{selectedEvent.description}</p>}
              {((["DRAFT", "REJECTED"].includes(selectedEvent.status) && selectedEvent.access.can_edit_draft) || (selectedEvent.status === "APPROVED" && selectedEvent.access.can_edit_approved)) && <button className="button button-secondary" onClick={openEventEdit} type="button">IZMENI DOGAĐAJ</button>}
              {eventSections.length === 0 && selectedEvent.access.can_manage_sections && <button className="button button-secondary" onClick={() => setActiveTab("participants")} type="button">+ DODAJ SEKCIJE DOGAĐAJA</button>}
              <div className="event-workflow-actions">
                {(selectedEvent.status === "DRAFT" || selectedEvent.status === "REJECTED") && selectedEvent.access.can_submit && <button className="button button-primary" disabled={isSaving} onClick={() => void runWorkflow("submit")} type="button">POŠALJI NA ODOBRENJE</button>}
                {(selectedEvent.status === "DRAFT" || selectedEvent.status === "REJECTED") && selectedEvent.access.can_review && <button className="button button-primary" disabled={isSaving} onClick={() => void runWorkflow("approve")} type="button">ODOBRI DOGAĐAJ</button>}
                {selectedEvent.status === "PENDING" && selectedEvent.access.can_review && <>
                  <button className="button button-primary" disabled={isSaving} onClick={() => void runWorkflow("approve")} type="button">ODOBRI</button>
                  <input className="input" placeholder="Razlog odbijanja" value={reason} onChange={(e) => setReason(e.target.value)} />
                  <button className="button button-secondary" disabled={!reason.trim() || isSaving} onClick={() => void runWorkflow("reject")} type="button">ODBIJ</button>
                </>}
                {selectedEvent.status === "APPROVED" && selectedEvent.access.can_edit_approved && <button className="button button-primary" disabled={isSaving} onClick={() => void runWorkflow("complete")} type="button">OZNAČI KAO ZAVRŠEN</button>}
                {!["CANCELLED", "COMPLETED"].includes(selectedEvent.status) && selectedEvent.access.can_cancel_approved && <>
                  <input className="input" placeholder="Razlog otkazivanja" value={reason} onChange={(e) => setReason(e.target.value)} />
                  <button className="button button-secondary danger-action" disabled={!reason.trim() || isSaving} onClick={() => void runWorkflow("cancel")} type="button">OTKAŽI DOGAĐAJ</button>
                </>}
              </div>
            </section>}

            {activeTab === "participants" && <section className="event-tab-panel participants-panel">
              <div className="participant-controls">
                <div className="participant-controls-row">
                  <div className="event-section-picker">{sections.map((section) => {
                    const checked = eventSections.some((item) => item.section_id === section.id);
                    return <label key={section.id}><input checked={checked} disabled={!selectedEvent.access.can_manage_sections || isSaving} onChange={() => void toggleEventSection(section)} type="checkbox" /> {section.name}</label>;
                  })}</div>
                  {selectedEvent.access.can_manage_participants && <label className="guest-toggle"><input checked={showGuestForm} onChange={(event) => { setShowGuestForm(event.target.checked); if (!event.target.checked) { setPassengerLookup("idle"); setExistingPassenger(null); setPassengerSuggestions([]); setPassengerSearchComplete(false); } }} type="checkbox" /> Dodaj putnika koji nije član</label>}
                </div>
                  {showGuestForm && <div className="passenger-email-flow">
                    <div className="passenger-email-check"><input autoComplete="off" className="input" placeholder="Počnite da kucate email putnika" type="email" value={guest.email} onChange={(event) => { setGuest({ first_name: "", last_name: "", email: event.target.value, phone: "" }); setPassengerLookup("idle"); setExistingPassenger(null); setPassengerSearchComplete(false); }} /><button className="button button-primary" disabled={!passengerSearchComplete || passengerSuggestions.length > 0 || guest.email.trim().length < 2} onClick={() => { setPassengerLookup("new"); setPassengerPersonValues(emptyPassengerPerson(guest.email.trim().toLowerCase())); setIsNewPassengerFormOpen(true); }} type="button">UNESI NOVOG PUTNIKA</button></div>
                    {passengerLookup === "checking" && <span className="passenger-search-note">Pretraga people baze...</span>}
                    {passengerSuggestions.length > 0 && passengerLookup !== "existing" && <div className="passenger-suggestions">{passengerSuggestions.map((person) => <button key={person.id} onClick={() => { setExistingPassenger(person); setGuest({ first_name: person.first_name, last_name: person.last_name, email: person.email ?? "", phone: person.phone ?? "" }); setPassengerLookup("existing"); setPassengerSuggestions([]); }} type="button"><strong>{person.email}</strong><span>{personName(person)}{person.phone ? ` · ${person.phone}` : ""}</span></button>)}</div>}
                    {passengerSearchComplete && passengerSuggestions.length === 0 && passengerLookup === "idle" && guest.email.trim().length >= 2 && <span className="passenger-search-note">Nema pronađenih osoba. Možete uneti novog putnika.</span>}
                    {passengerLookup === "existing" && existingPassenger && <div className="passenger-found"><div><strong>{personName(existingPassenger)}</strong><span>Osoba je pronađena u people bazi{existingPassenger.phone ? ` · ${existingPassenger.phone}` : ""}</span></div><button className="button button-primary" disabled={isSaving} onClick={() => void addGuest()} type="button">DODAJ PUTNIKA</button></div>}
                  </div>}
              </div>
              <div className="participant-list-heading">
                <strong>Spisak učesnika</strong>
                <div className="participant-filter">
                  <span>Filter</span>
                  <div className="participant-status-actions" role="group" aria-label="Filtriranje učesnika po statusu">
                    {PARTICIPANT_STATUSES.map((status) => <button
                      aria-label={`Filter: ${status.label}`}
                      aria-pressed={participantStatusFilters.includes(status.value)}
                      className={`participant-status-button ${status.value.toLowerCase()} ${participantStatusFilters.includes(status.value) ? "active" : ""}`}
                      key={status.value}
                      onClick={() => toggleParticipantStatusFilter(status.value)}
                      title={`Filter: ${status.label}`}
                      type="button"
                    ><span aria-hidden="true">{status.icon}</span></button>)}
                  </div>
                </div>
              </div>
              <div className="event-participant-list">
                {participants.length === 0 && <p className="program-empty-row">Još nema dodatih putnika.</p>}
                {participants.length > 0 && visibleParticipants.length === 0 && <p className="program-empty-row">Nema učesnika sa izabranim statusima.</p>}
                {visibleParticipants.map((participant) => <article key={participant.id}>
                  <div>
                    <strong>{participant.name}</strong>
                    <span>{participant.society_member_id ? "Član društva" : "Putnik koji nije član"}{selectedEvent.access.can_view_fees ? ` · ${participant.participation_fee_amount ?? 0} ${selectedEvent.currency}` : ""}</span>
                  </div>
                  <div className="participant-status-actions" role="group" aria-label={`Status učesnika ${participant.name}`}>
                    {PARTICIPANT_STATUSES.map((status) => <button
                      aria-label={status.label}
                      className={`participant-status-button ${status.value.toLowerCase()} ${participant.participation_status === status.value ? "active" : ""}`}
                      disabled={!selectedEvent.access.can_change_participant_status || isSaving || !canSetParticipantStatus(participant.participation_status, status.value)}
                      key={status.value}
                      onClick={() => void changeParticipantStatus(participant, status.value)}
                      title={status.label}
                      type="button"
                    ><span aria-hidden="true">{status.icon}</span></button>)}
                  </div>
                </article>)}
              </div>
            </section>}

            {activeTab === "program" && <section className="event-tab-panel program-panel">
              <header className="program-toolbar"><div><h3>Program događaja</h3><p>Termini, numere i izvođači</p></div>{selectedEvent.access.can_manage_program && <div className="header-actions"><button className="button button-secondary" onClick={() => setShowAppearanceForm((value) => !value)} type="button">+ TERMIN NASTUPA</button><button className="button button-primary" disabled={appearances.length === 0} onClick={() => setShowProgramForm((value) => !value)} type="button">+ NUMERA</button></div>}</header>
              {showAppearanceForm && <div className="program-inline-form"><input className="input" placeholder="Naziv termina" value={appearanceForm.title} onChange={(e) => setAppearanceForm({ ...appearanceForm, title: e.target.value })} /><DateTimeField label="Datum i vreme" value={appearanceForm.starts_at} onChange={(value) => setAppearanceForm({ ...appearanceForm, starts_at: value })} /><input className="input" placeholder="Mesto" value={appearanceForm.city} onChange={(e) => setAppearanceForm({ ...appearanceForm, city: e.target.value })} /><div className="header-actions"><button className="button button-secondary" onClick={() => setShowAppearanceForm(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={!appearanceForm.title.trim() || isSaving} onClick={() => void addAppearance()} type="button">SAČUVAJ TERMIN</button></div></div>}
              {showProgramForm && <div className="program-inline-form program-number-form"><select className="input" value={programForm.appearanceId} onChange={(e) => setProgramForm({ ...programForm, appearanceId: e.target.value })}><option value="">Termin nastupa</option>{appearances.map((a) => <option key={a.id} value={a.id}>{a.title}</option>)}</select><select className="input" value={programForm.eventSectionId} onChange={(e) => setProgramForm({ ...programForm, eventSectionId: e.target.value, repertoireId: "" })}><option value="">Sekcija</option>{eventSections.map((link) => <option key={link.id} value={link.id}>{sections.find((s) => s.id === link.section_id)?.name}</option>)}</select><select className="input" value={programForm.repertoireId} onChange={(e) => setProgramForm({ ...programForm, repertoireId: e.target.value })}><option value="">Numera</option>{repertoire.filter((item) => { const es = eventSections.find((link) => link.id === programForm.eventSectionId); return es && repertoireSectionLinks.some((link) => link.repertoire_item_id === item.id && link.section_id === es.section_id); }).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select><div className="header-actions"><button className="button button-secondary" onClick={() => setShowProgramForm(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving || !programForm.appearanceId || !programForm.eventSectionId || !programForm.repertoireId} onClick={() => void addProgramItem()} type="button">DODAJ NUMERU</button></div></div>}
              {appearances.length === 0 && <div className="program-empty"><strong>Program još nema termin nastupa.</strong><span>Dodajte termin, a zatim njegove numere.</span></div>}
              <div className="event-program-list">{appearances.map((appearance) => {
                const appearanceProgram = program.filter((item) => item.event_appearance_id === appearance.id);
                return <section className="program-appearance" key={appearance.id}>
                  <header><div><h3>{appearance.title}</h3><span>{dateTime(appearance.starts_at)} · {appearance.city || selectedEvent.city}</span></div><strong>{appearanceProgram.length} numera</strong></header>
                  {appearanceProgram.length === 0 && <p className="program-empty-row">Još nema dodatih numera.</p>}
                  {appearanceProgram.map((item) => {
                    const eventSection = eventSections.find((link) => link.id === item.event_section_id);
                    const eligible = participants.filter((participant) => participantSectionLinks.some((link) => link.event_participant_id === participant.id && link.event_section_id === item.event_section_id));
                    return <article className="program-number-row" key={item.id}>
                      <div className="program-number-heading"><strong>{repertoire.find((repertoireItem) => repertoireItem.id === item.repertoire_item_id)?.name}</strong><span>{sections.find((section) => section.id === eventSection?.section_id)?.name}</span></div>
                      <div className="program-performers"><strong>Ko učestvuje u numeri</strong>
                        <div className="program-no-performers">
                          <span>{eligible.filter((participant) => performerLinks.some((link) => link.event_appearance_repertoire_id === item.id && link.event_participant_id === participant.id)).map((participant) => participant.name).join(", ") || "Niko još nije izabran."}</span>
                          {selectedEvent.access.can_manage_program && <button className="button button-secondary" onClick={() => void openPerformerPicker(item)} type="button">{eligible.some((participant) => performerLinks.some((link) => link.event_appearance_repertoire_id === item.id && link.event_participant_id === participant.id)) ? "IZMENI UČESNIKE" : "DODAJ UČESNIKE"}</button>}
                        </div>
                      </div>
                    </article>;
                  })}
                </section>;
              })}</div>
            </section>}
          </main>
        ) : <section className="card attendance-empty">Izaberite događaj ili kreirajte novi.</section>}
      </section>

      {performerPickerItem && <div className="modal-backdrop">
        <section className="card modal-card performer-modal">
          <header className="performer-modal-header"><div><p className="eyebrow">Učesnici numere</p><h2>{repertoire.find((item) => item.id === performerPickerItem.repertoire_item_id)?.name}</h2><p>{sections.find((section) => section.id === eventSections.find((link) => link.id === performerPickerItem.event_section_id)?.section_id)?.name}</p></div><button className="button button-secondary" onClick={() => setPerformerPickerItem(null)} type="button">ZATVORI</button></header>
          <div className="performer-gender-grid">
            {[{ title: "Muškarci", gender: "Muško" }, { title: "Devojke", gender: "Žensko" }].map((group) => <section key={group.gender}><h3>{group.title}</h3><div className="performer-member-list">{memberCandidates.filter((candidate) => candidate.person.gender === group.gender).map((candidate) => {
              const participant = participants.find((item) => item.person_id === candidate.person.id);
              const selected = Boolean(participant && performerLinks.some((link) => link.event_appearance_repertoire_id === performerPickerItem.id && link.event_participant_id === participant.id));
              return <button className={`performer-member ${selected ? "selected" : ""}`} disabled={isSaving} key={candidate.member.id} onClick={() => void toggleCandidatePerformer(candidate)} type="button"><span>{personName(candidate.person)}</span><strong>{selected ? "UČESTVUJE" : "+ DODAJ"}</strong></button>;
            })}</div></section>)}
          </div>
          {memberCandidates.some((candidate) => candidate.person.gender !== "Muško" && candidate.person.gender !== "Žensko") && <section><h3>Pol nije naveden</h3><div className="performer-member-list">{memberCandidates.filter((candidate) => candidate.person.gender !== "Muško" && candidate.person.gender !== "Žensko").map((candidate) => { const participant = participants.find((item) => item.person_id === candidate.person.id); const selected = Boolean(participant && performerLinks.some((link) => link.event_appearance_repertoire_id === performerPickerItem.id && link.event_participant_id === participant.id)); return <button className={`performer-member ${selected ? "selected" : ""}`} disabled={isSaving} key={candidate.member.id} onClick={() => void toggleCandidatePerformer(candidate)} type="button"><span>{personName(candidate.person)}</span><strong>{selected ? "UČESTVUJE" : "+ DODAJ"}</strong></button>; })}</div></section>}
          {error && <p className="alert alert-error">{error}</p>}
        </section>
      </div>}

      {isNewPassengerFormOpen && society && <div className="modal-backdrop">
        <section className="card modal-card passenger-person-modal">
          <header><p className="eyebrow">Novi putnik</p><h2>Podaci o osobi</h2></header>
          <UF_MEMBER_FORM
            mode="person_create"
            societyId={society.id}
            values={passengerPersonValues}
            isSubmitting={isSaving}
            readOnlyPersonFields={{ email: true }}
            onFieldChange={(field: UFMemberFormField | "showGuardian2" | "is_minor_member", value: string | boolean) => setPassengerPersonValues((current) => ({ ...current, [field]: value } as UFMemberFormValues))}
            onGuardianFieldChange={(guardian: "guardian1" | "guardian2", field: UFMemberGuardianField, value: string) => setPassengerPersonValues((current) => ({ ...current, [guardian]: { ...current[guardian], [field]: value } }))}
            onAddSecondGuardian={() => setPassengerPersonValues((current) => ({ ...current, showGuardian2: true }))}
            onRemoveSecondGuardian={() => setPassengerPersonValues((current) => ({ ...current, showGuardian2: false }))}
            onFunctionToggle={() => undefined}
            onSubmit={() => void createPassengerPerson()}
            onCancel={() => { setIsNewPassengerFormOpen(false); setPassengerLookup("idle"); }}
          />
          {error && <p className="alert alert-error">{error}</p>}
        </section>
      </div>}

      {isCreateOpen && <div className="modal-backdrop">
        <section className="card modal-card events-create-modal">
          <header><p className="eyebrow">Novi događaj</p><h2>Osnovni podaci</h2></header>
          <div className="form-grid">
            <label className="form-field"><span>Tip</span><select className="input" value={eventForm.event_type} onChange={(e) => setEventForm({ ...eventForm, event_type: e.target.value as SocietyEvent["event_type"] })}><option value="CONCERT">Koncert</option><option value="TRIP">Putovanje</option></select></label>
            <label className="form-field"><span>Naziv *</span><input className="input" value={eventForm.title} onChange={(e) => setEventForm({ ...eventForm, title: e.target.value })} /></label>
            <label className="form-field"><span>Država</span><input className="input" value={eventForm.country} onChange={(e) => setEventForm({ ...eventForm, country: e.target.value })} /></label>
            <label className="form-field"><span>Mesto *</span><input className="input" value={eventForm.city} onChange={(e) => setEventForm({ ...eventForm, city: e.target.value })} /></label>
            <DateTimeField label="Polazak" value={eventForm.departure_at} onChange={(value) => setEventForm((current) => ({ ...current, departure_at: value }))} />
            <DateTimeField label="Povratak" value={eventForm.return_at} onChange={(value) => setEventForm((current) => ({ ...current, return_at: value }))} />
          </div>
          <fieldset className="event-create-sections">
            <legend>Sekcije koje učestvuju *</legend>
            <div className="event-section-picker">{sections.map((section) => {
              const checked = eventForm.section_ids.includes(section.id);
              return <label key={section.id}><input checked={checked} onChange={() => setEventForm({ ...eventForm, section_ids: checked ? eventForm.section_ids.filter((id) => id !== section.id) : [...eventForm.section_ids, section.id] })} type="checkbox" /> {section.name}</label>;
            })}</div>
            {sections.length === 0 && <p className="field-warning">Nema dostupnih aktivnih sekcija.</p>}
          </fieldset>
          {error && <p className="alert alert-error">{error}</p>}
          <label className="form-field"><span>Opis</span><textarea className="input" rows={3} value={eventForm.description} onChange={(e) => setEventForm({ ...eventForm, description: e.target.value })} /></label>
          {canManageNewEventFee && <label className="form-field"><span><input checked={eventForm.has_participation_fee} onChange={(e) => setEventForm({ ...eventForm, has_participation_fee: e.target.checked })} type="checkbox" /> Finansijsko učešće putnika</span></label>}
          {canManageNewEventFee && eventForm.has_participation_fee && <>
            <div className="form-grid">
              <label className="form-field"><span>Podrazumevani iznos *</span><input className="input" min="0" step="0.01" type="number" value={eventForm.default_participation_fee_amount} onChange={(e) => setEventForm({ ...eventForm, default_participation_fee_amount: e.target.value })} /></label>
              <label className="form-field"><span>Valuta *</span><input className="input" maxLength={3} value={eventForm.currency} onChange={(e) => setEventForm({ ...eventForm, currency: e.target.value.toUpperCase() })} /></label>
              <label className="form-field"><span>Krajnji rok plaćanja *</span><input className="input" type="date" value={eventForm.payment_due_date} onChange={(e) => setEventForm({ ...eventForm, payment_due_date: e.target.value })} /></label>
            </div>
            <label className="form-field"><span>Napomena za kotizaciju</span><textarea className="input" rows={2} value={eventForm.fee_note} onChange={(e) => setEventForm({ ...eventForm, fee_note: e.target.value })} /></label>
          </>}
          <div className="header-actions"><button className="button button-secondary" onClick={() => setIsCreateOpen(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving} onClick={() => void createEvent()} type="button">{role === "Predsednik" ? "KREIRAJ I ODOBRI" : "SAČUVAJ NACRT"}</button></div>
        </section>
      </div>}
      {isEditOpen && <div className="modal-backdrop">
        <section className="card modal-card events-create-modal">
          <header><p className="eyebrow">Izmena događaja</p><h2>Osnovni podaci</h2></header>
          <div className="form-grid">
            <label className="form-field"><span>Tip</span><select className="input" value={editForm.event_type} onChange={(e) => setEditForm({ ...editForm, event_type: e.target.value as SocietyEvent["event_type"] })}><option value="CONCERT">Koncert</option><option value="TRIP">Putovanje</option></select></label>
            <label className="form-field"><span>Naziv *</span><input className="input" value={editForm.title} onChange={(e) => setEditForm({ ...editForm, title: e.target.value })} /></label>
            <label className="form-field"><span>Država</span><input className="input" value={editForm.country} onChange={(e) => setEditForm({ ...editForm, country: e.target.value })} /></label>
            <label className="form-field"><span>Mesto *</span><input className="input" value={editForm.city} onChange={(e) => setEditForm({ ...editForm, city: e.target.value })} /></label>
            <DateTimeField label="Polazak" value={editForm.departure_at} onChange={(value) => setEditForm((current) => ({ ...current, departure_at: value }))} />
            <DateTimeField label="Povratak" value={editForm.return_at} onChange={(value) => setEditForm((current) => ({ ...current, return_at: value }))} />
          </div>
          <label className="form-field"><span>Opis</span><textarea className="input" rows={3} value={editForm.description} onChange={(e) => setEditForm({ ...editForm, description: e.target.value })} /></label>
          {selectedEvent?.access.can_manage_fee && <label className="guest-toggle"><input checked={editForm.has_participation_fee} onChange={(e) => setEditForm({ ...editForm, has_participation_fee: e.target.checked })} type="checkbox" /> Finansijsko učešće putnika</label>}
          {selectedEvent?.access.can_manage_fee && editForm.has_participation_fee && <>
            <div className="form-grid">
              <label className="form-field"><span>Podrazumevani iznos *</span><input className="input" min="0" step="0.01" type="number" value={editForm.default_participation_fee_amount} onChange={(e) => setEditForm({ ...editForm, default_participation_fee_amount: e.target.value })} /></label>
              <label className="form-field"><span>Valuta *</span><input className="input" maxLength={3} value={editForm.currency} onChange={(e) => setEditForm({ ...editForm, currency: e.target.value.toUpperCase() })} /></label>
              <label className="form-field"><span>Krajnji rok plaćanja *</span><input className="input" type="date" value={editForm.payment_due_date} onChange={(e) => setEditForm({ ...editForm, payment_due_date: e.target.value })} /></label>
            </div>
            <label className="form-field"><span>Napomena za kotizaciju</span><textarea className="input" rows={2} value={editForm.fee_note} onChange={(e) => setEditForm({ ...editForm, fee_note: e.target.value })} /></label>
          </>}
          {error && <p className="alert alert-error">{error}</p>}
          <div className="header-actions"><button className="button button-secondary" onClick={() => setIsEditOpen(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving} onClick={() => void saveEventEdit()} type="button">SAČUVAJ IZMENE</button></div>
        </section>
      </div>}
    </>
  );
}
