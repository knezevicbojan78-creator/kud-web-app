"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type WardrobeAssignment,
  type WardrobeItem,
  type WardrobeLossCase,
  type WardrobeOperations,
  type WardrobeRepair,
  type WardrobeWorkspace
} from "../../_lib/supabaseClient";

type Tab = "overview" | "inventory" | "kits" | "assignments" | "repairs" | "categories";

const tabLabels: Array<[Tab, string]> = [
  ["overview", "Pregled"], ["inventory", "Inventar"], ["kits", "Kompleti"],
  ["assignments", "Zaduženja"], ["repairs", "Popravke"], ["categories", "Kategorije"]
];
const ageLabels = { CHILD: "Dečje", ADULT: "Odraslo", UNIVERSAL: "Univerzalno" };
const genderLabels = { MALE: "Muško", FEMALE: "Žensko", UNISEX: "Univerzalno" };
const statusLabels: Record<string, string> = {
  OPEN: "Zaduženo", PARTIALLY_RETURNED: "Delimično vraćeno",
  RETURNED: "Vraćeno", OVERDUE: "Kasni", CANCELLED: "Otkazano"
};
const repairStatusLabels: Record<string, string> = {
  WAITING_HANDOVER: "Čeka predaju", HANDED_OVER: "Predato",
  IN_PROGRESS: "Popravka u toku", COMPLETED: "Završeno",
  RETURNED_TO_WARDROBE: "Vraćeno u garderobu", UNREPAIRABLE: "Nije moguće popraviti"
};

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) return String(error.message);
  return "Akcija nije uspela.";
}
function date(value: string | null) {
  if (!value) return "Bez roka";
  return new Intl.DateTimeFormat("sr-Latn-RS").format(new Date(`${value.slice(0, 10)}T00:00:00`));
}
function remaining(item: WardrobeAssignment["items"][number]) {
  return item.issued_quantity - item.returned_quantity - item.laundry_quantity -
    item.repair_quantity - item.lost_quantity - item.damaged_quantity;
}

export default function GarderobaPage() {
  const [workspace, setWorkspace] = useState<WardrobeWorkspace | null>(null);
  const [operations, setOperations] = useState<WardrobeOperations>({
    repairs: [], loss_cases: [], luggage: []
  });
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [inventoryQuery, setInventoryQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [showItemForm, setShowItemForm] = useState(false);
  const [showKitForm, setShowKitForm] = useState(false);
  const [showAssignmentForm, setShowAssignmentForm] = useState(false);
  const [showCategoryForm, setShowCategoryForm] = useState(false);
  const [editingItemId, setEditingItemId] = useState("");
  const [editingKitId, setEditingKitId] = useState("");
  const [editingCategoryId, setEditingCategoryId] = useState("");
  const [itemForm, setItemForm] = useState({
    category_id: "", name: "", internal_code: "", age_group: "UNIVERSAL",
    gender_group: "UNISEX", shoe_size: "", total_quantity: "1", note: "",
    repertoire_ids: [] as string[]
  });
  const [kitForm, setKitForm] = useState({
    name: "", internal_code: "", age_group: "UNIVERSAL", gender_group: "UNISEX",
    note: "", items: {} as Record<string, string>
  });
  const [assignmentForm, setAssignmentForm] = useState({
    assignment_type: "MEMBER", assigned_member_id: "", event_id: "",
    title: "", due_date: "", note: "", kit_ids: [] as string[]
  });
  const [categoryForm, setCategoryForm] = useState({
    name: "", code: "", is_footwear: false
  });
  const [returnAssignment, setReturnAssignment] = useState<WardrobeAssignment | null>(null);
  const [returnRows, setReturnRows] = useState<Record<string, { quantity: string; result: string }>>({});
  const [returnDays, setReturnDays] = useState("3");
  const [reminderDays, setReminderDays] = useState("1");
  const [editingRepair, setEditingRepair] = useState<WardrobeRepair | null>(null);
  const [repairForm, setRepairForm] = useState({
    assignee_type: "SOCIETY_PERSON", assigned_member_id: "", external_name: "",
    external_contact: "", description: "", due_date: "", status: "WAITING_HANDOVER",
    cost: "", note: ""
  });
  const [resolvingLoss, setResolvingLoss] = useState<WardrobeLossCase | null>(null);
  const [lossForm, setLossForm] = useState({
    resolution: "RETURNED", replacement_quantity: "1", note: ""
  });
  const [handoverLuggageId, setHandoverLuggageId] = useState("");
  const [handoverMemberId, setHandoverMemberId] = useState("");
  const [handoverNote, setHandoverNote] = useState("");

  async function load() {
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: context, error: contextError } = await supabase.rpc("auth_get_application_context");
      if (contextError) throw contextError;
      const membership = context?.memberships?.[0];
      if (!membership) throw new Error("Aktivno članstvo nije pronađeno.");
      const [workspaceResult, operationsResult] = await Promise.all([
        supabase.rpc("auth_get_wardrobe_workspace", { p_society_id: membership.society_id }),
        supabase.rpc("auth_get_wardrobe_operations", { p_society_id: membership.society_id })
      ]);
      if (workspaceResult.error) throw workspaceResult.error;
      if (operationsResult.error) throw operationsResult.error;
      const data = workspaceResult.data;
      setWorkspace(data);
      setOperations(operationsResult.data);
      setReturnDays(String(data.settings.return_days_after_event));
      setReminderDays(String(data.settings.reminder_days_before_due));
      setItemForm((current) => ({
        ...current,
        category_id: current.category_id || data.categories.find((category) => category.is_active)?.id || ""
      }));
    } catch (loadError) {
      setError(errorMessage(loadError));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  const activeAssignments = useMemo(() => workspace?.assignments.filter(
    (assignment) => ["OPEN", "PARTIALLY_RETURNED", "OVERDUE"].includes(assignment.status)
  ) ?? [], [workspace]);
  const overdueAssignments = activeAssignments.filter((assignment) =>
    assignment.due_date && assignment.due_date < new Date().toISOString().slice(0, 10)
  );
  const partialAssignments = activeAssignments.filter((assignment) =>
    assignment.status === "PARTIALLY_RETURNED"
  );
  const readyKitCount = workspace?.kits.filter((kit) =>
    kit.items.every((kitItem) =>
      (workspace.items.find((item) => item.id === kitItem.wardrobe_item_id)?.available_quantity ?? 0)
        >= kitItem.quantity
    )
  ).length ?? 0;
  const filteredItems = useMemo(() => {
    const query = inventoryQuery.trim().toLowerCase();
    return (workspace?.items ?? []).filter((item) => {
      const matchesQuery = !query || `${item.name} ${item.category_name} ${item.internal_code ?? ""}`
        .toLowerCase().includes(query);
      const matchesStatus = !statusFilter ||
        (statusFilter === "AVAILABLE" && item.available_quantity > 0) ||
        (statusFilter === "ASSIGNED" && item.assigned_quantity > 0) ||
        (statusFilter === "UNAVAILABLE" && item.unavailable_quantity > 0);
      return matchesQuery && matchesStatus;
    });
  }, [inventoryQuery, statusFilter, workspace]);

  async function perform(action: () => PromiseLike<{ error: { message?: string } | null }>, success: string) {
    setIsSaving(true); setError(""); setMessage("");
    try {
      const result = await action();
      if (result.error) throw result.error;
      setMessage(success);
      await load();
    } catch (actionError) {
      setError(errorMessage(actionError));
    } finally {
      setIsSaving(false);
    }
  }

  async function saveItem() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_item", {
      p_society_id: workspace.society_id,
      p_item: {
        ...itemForm,
        id: editingItemId || null,
        shoe_size: itemForm.shoe_size || null,
        total_quantity: Number(itemForm.total_quantity)
      }
    }), "Stavka garderobe je sačuvana.");
    setShowItemForm(false);
    setEditingItemId("");
    setItemForm({ category_id: workspace.categories[0]?.id ?? "", name: "", internal_code: "",
      age_group: "UNIVERSAL", gender_group: "UNISEX", shoe_size: "",
      total_quantity: "1", note: "", repertoire_ids: [] });
  }
  async function saveCategory() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_category", {
      p_society_id: workspace.society_id,
      p_category: { ...categoryForm, id: editingCategoryId || null, is_active: true }
    }), "Kategorija je dodata.");
    setShowCategoryForm(false);
    setEditingCategoryId("");
    setCategoryForm({ name: "", code: "", is_footwear: false });
  }
  async function saveKit() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_kit", {
      p_society_id: workspace.society_id,
      p_kit: {
        ...kitForm,
        id: editingKitId || null,
        items: Object.entries(kitForm.items)
          .filter(([, quantity]) => Number(quantity) > 0)
          .map(([wardrobe_item_id, quantity]) => ({
            wardrobe_item_id, quantity: Number(quantity)
          }))
      }
    }), "Komplet je sačuvan.");
    setShowKitForm(false);
    setEditingKitId("");
    setKitForm({ name: "", internal_code: "", age_group: "UNIVERSAL",
      gender_group: "UNISEX", note: "", items: {} });
  }
  async function openItemEdit(item: WardrobeItem) {
    if (!workspace) return;
    setError("");
    const { data, error: linksError } = await getSupabaseClient().rpc(
      "auth_wardrobe_get_item_repertoire",
      { p_society_id: workspace.society_id, p_wardrobe_item_id: item.id }
    );
    if (linksError) {
      setError(linksError.message);
      return;
    }
    setEditingItemId(item.id);
    setItemForm({
      category_id: item.category_id, name: item.name,
      internal_code: item.internal_code ?? "", age_group: item.age_group,
      gender_group: item.gender_group, shoe_size: item.shoe_size ? String(item.shoe_size) : "",
      total_quantity: String(item.total_quantity), note: item.note ?? "",
      repertoire_ids: data ?? []
    });
    setShowItemForm(true);
  }
  function openKitEdit(kit: WardrobeWorkspace["kits"][number]) {
    setEditingKitId(kit.id);
    setKitForm({
      name: kit.name, internal_code: kit.internal_code ?? "",
      age_group: kit.age_group, gender_group: kit.gender_group,
      note: kit.note ?? "",
      items: Object.fromEntries(kit.items.map((item) => [
        item.wardrobe_item_id, String(item.quantity)
      ]))
    });
    setShowKitForm(true);
  }
  function openCategoryEdit(category: WardrobeWorkspace["categories"][number]) {
    setEditingCategoryId(category.id);
    setCategoryForm({
      name: category.name, code: category.code ?? "",
      is_footwear: category.is_footwear
    });
    setShowCategoryForm(true);
  }
  function openNewItem() {
    setEditingItemId("");
    setItemForm({
      category_id: workspace?.categories.find((category) => category.is_active)?.id ?? "",
      name: "", internal_code: "", age_group: "UNIVERSAL",
      gender_group: "UNISEX", shoe_size: "", total_quantity: "1",
      note: "", repertoire_ids: []
    });
    setShowItemForm(true);
  }
  function openNewKit() {
    setEditingKitId("");
    setKitForm({
      name: "", internal_code: "", age_group: "UNIVERSAL",
      gender_group: "UNISEX", note: "", items: {}
    });
    setShowKitForm(true);
  }
  function openNewCategory() {
    setEditingCategoryId("");
    setCategoryForm({ name: "", code: "", is_footwear: false });
    setShowCategoryForm(true);
  }
  async function saveAssignment() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_create_assignment", {
      p_society_id: workspace.society_id,
      p_assignment: { ...assignmentForm, lines: [] }
    }), "Garderoba je zadužena.");
    setShowAssignmentForm(false);
    setAssignmentForm({ assignment_type: "MEMBER", assigned_member_id: "", event_id: "",
      title: "", due_date: "", note: "", kit_ids: [] });
  }
  function openReturn(assignment: WardrobeAssignment) {
    setReturnAssignment(assignment);
    setReturnRows(Object.fromEntries(assignment.items.filter((item) => remaining(item) > 0).map((item) => [
      item.id, { quantity: String(remaining(item)), result: "RETURNED" }
    ])));
  }
  async function recordReturn() {
    if (!workspace || !returnAssignment) return;
    const rows = Object.entries(returnRows).filter(([, row]) => Number(row.quantity) > 0)
      .map(([assignment_item_id, row]) => ({
        assignment_item_id, quantity: Number(row.quantity), result: row.result
      }));
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_record_return", {
      p_society_id: workspace.society_id,
      p_assignment_id: returnAssignment.id, p_returns: rows, p_note: null
    }), "Razduženje je evidentirano.");
    setReturnAssignment(null);
  }
  async function saveSettings() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_settings", {
      p_society_id: workspace.society_id,
      p_return_days: Number(returnDays), p_reminder_days: Number(reminderDays)
    }), "Podešavanja garderobe su sačuvana.");
  }
  function openRepair(repair: WardrobeRepair) {
    setEditingRepair(repair);
    setRepairForm({
      assignee_type: repair.assignee_type,
      assigned_member_id: repair.assigned_member_id ?? "",
      external_name: repair.external_name ?? "",
      external_contact: repair.external_contact ?? "",
      description: repair.description,
      due_date: repair.due_date ?? "",
      status: repair.status,
      cost: repair.cost == null ? "" : String(repair.cost),
      note: repair.note ?? ""
    });
  }
  async function saveRepair() {
    if (!workspace || !editingRepair) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_update_repair", {
      p_society_id: workspace.society_id,
      p_repair_id: editingRepair.id,
      p_changes: repairForm
    }), "Nalog za popravku je ažuriran.");
    setEditingRepair(null);
  }
  async function resolveLoss() {
    if (!workspace || !resolvingLoss) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_resolve_loss", {
      p_society_id: workspace.society_id,
      p_loss_case_id: resolvingLoss.id,
      p_resolution: lossForm.resolution as "RETURNED" | "REPLACED" | "FINANCIAL" | "WRITTEN_OFF" | "OTHER",
      p_note: lossForm.note,
      p_replacement_quantity: lossForm.resolution === "REPLACED"
        ? Number(lossForm.replacement_quantity) : 0
    }), "Slučaj gubitka je rešen i sačuvan u istoriji.");
    setResolvingLoss(null);
  }
  async function handoverLuggage() {
    if (!workspace || !handoverLuggageId) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_handover_luggage", {
      p_society_id: workspace.society_id,
      p_luggage_id: handoverLuggageId,
      p_new_member_id: handoverMemberId,
      p_condition_note: handoverNote
    }), "Primopredaja kofera je evidentirana.");
    setHandoverLuggageId(""); setHandoverMemberId(""); setHandoverNote("");
  }

  if (isLoading) return <section className="card dashboard-card">Učitavanje garderobe...</section>;
  if (!workspace) return <section className="card dashboard-card"><p className="alert alert-error">{error}</p></section>;

  const selectedCategory = workspace.categories.find((category) => category.id === itemForm.category_id);

  return (
    <>
      <section className="wardrobe-heading">
        <div><p className="eyebrow">Evidencija nošnji i opreme</p><h1>Garderoba</h1>
          <p>Kompleti, zaduženja, povrati i stanje garderobe na jednom mestu.</p></div>
        {workspace.is_manager && <button className="button button-primary" onClick={() => setShowAssignmentForm(true)} type="button">+ NOVO ZADUŽENJE</button>}
      </section>
      {message && <p className="alert alert-success">{message}</p>}
      {error && <p className="alert alert-error">{error}</p>}

      <section className="wardrobe-summary">
        {[
          ["kits", "Spremni kompleti", readyKitCount, ""],
          ["assignments", "Zaduženo", activeAssignments.length, ""],
          ["assignments", "Rok je prošao", overdueAssignments.length, "OVERDUE"],
          ["assignments", "Nepotpuno vraćeno", partialAssignments.length, "PARTIAL"],
          ["repairs", "Nedostaje / popravka", workspace.items.reduce((sum, item) => sum + item.unavailable_quantity, 0), ""]
        ].map(([tab, label, value, filter]) => (
          <button className="card wardrobe-stat" key={label} onClick={() => {
            setActiveTab(tab as Tab); if (filter === "AVAILABLE") setStatusFilter("AVAILABLE");
          }} type="button"><span>{label}</span><strong>{value}</strong><small>Otvori pregled →</small></button>
        ))}
      </section>

      <section className="card wardrobe-panel">
        <nav className="wardrobe-tabs">
          {tabLabels.map(([id, label]) => <button className={activeTab === id ? "active" : ""} key={id} onClick={() => setActiveTab(id)} type="button">{label}</button>)}
        </nav>

        {activeTab === "overview" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Trenutno stanje</p><h2>Šta zahteva pažnju</h2></div></div>
          <div className="wardrobe-overview-grid">
            <article><strong>{overdueAssignments.length}</strong><span>zaduženja sa isteklim rokom</span><button onClick={() => setActiveTab("assignments")} type="button">Pregledaj</button></article>
            <article><strong>{partialAssignments.length}</strong><span>delimično vraćenih zaduženja</span><button onClick={() => setActiveTab("assignments")} type="button">Pregledaj</button></article>
            <article><strong>{workspace.kits.length}</strong><span>definisanih kompleta</span><button onClick={() => setActiveTab("kits")} type="button">Pregledaj</button></article>
          </div>
          {workspace.is_manager && <div className="wardrobe-settings">
            <div><p className="eyebrow">Automatski rokovi</p><h3>Podešavanja vraćanja</h3></div>
            <label><span>Dana nakon događaja</span><input className="input" type="number" min="0" max="90" value={returnDays} onChange={(e) => setReturnDays(e.target.value)} /></label>
            <label><span>Podsetnik dana ranije</span><input className="input" type="number" min="0" max="30" value={reminderDays} onChange={(e) => setReminderDays(e.target.value)} /></label>
            <button className="button button-secondary" disabled={isSaving} onClick={() => void saveSettings()} type="button">SAČUVAJ</button>
          </div>}
        </div>}

        {activeTab === "inventory" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Količinska evidencija</p><h2>Inventar</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={openNewItem} type="button">+ DODAJ STAVKU</button>}</div>
          <div className="wardrobe-filters"><input className="input" placeholder="Pretraži naziv, kategoriju ili oznaku" value={inventoryQuery} onChange={(e) => setInventoryQuery(e.target.value)} />
            <select className="input" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}><option value="">Sva stanja</option><option value="AVAILABLE">Raspoloživo</option><option value="ASSIGNED">Zaduženo</option><option value="UNAVAILABLE">Nedostupno</option></select></div>
          <div className="wardrobe-list">{filteredItems.map((item) => <article className="wardrobe-item-row" key={item.id}>
            <div><strong>{item.name}{item.shoe_size ? ` · broj ${item.shoe_size}` : ""}</strong><span>{item.category_name} · {ageLabels[item.age_group]} · {genderLabels[item.gender_group]}</span><small>{item.internal_code || "Bez interne oznake"}{item.repertoire_names.length ? ` · ${item.repertoire_names.join(", ")}` : ""}</small></div>
            <div className="wardrobe-row-actions"><div className="wardrobe-quantities"><span><b>{item.available_quantity}</b> raspoloživo</span><span><b>{item.assigned_quantity}</b> zaduženo</span><span><b>{item.total_quantity}</b> ukupno</span></div>
              {workspace.is_manager && <button className="button button-secondary" onClick={() => void openItemEdit(item)} type="button">IZMENI</button>}</div>
          </article>)}{filteredItems.length === 0 && <p className="wardrobe-empty">Nema stavki koje odgovaraju izabranom pregledu.</p>}</div>
        </div>}

        {activeTab === "kits" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Brzo izdavanje</p><h2>Kompleti nošnje</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={openNewKit} type="button">+ NOVI KOMPLET</button>}</div>
          <div className="wardrobe-kit-grid">{workspace.kits.map((kit) => <article className="card" key={kit.id}><span>{ageLabels[kit.age_group]} · {genderLabels[kit.gender_group]}</span><h3>{kit.name}</h3><small>{kit.internal_code || "Bez interne oznake"}</small><ul>{kit.items.map((item) => <li key={item.wardrobe_item_id}>{item.quantity} × {item.name}{item.shoe_size ? ` (${item.shoe_size})` : ""}</li>)}</ul>{workspace.is_manager && <button className="button button-secondary" onClick={() => openKitEdit(kit)} type="button">IZMENI KOMPLET</button>}</article>)}
            {workspace.kits.length === 0 && <p className="wardrobe-empty">Još nema definisanih kompleta.</p>}</div>
        </div>}

        {activeTab === "assignments" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Istorija izdavanja</p><h2>Zaduženja</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={() => setShowAssignmentForm(true)} type="button">+ NOVO ZADUŽENJE</button>}</div>
          <div className="wardrobe-list">{workspace.assignments.map((assignment) => <article className="wardrobe-assignment" key={assignment.id}>
            <div><span className={`master-status ${assignment.status === "RETURNED" ? "active" : assignment.status === "OVERDUE" ? "suspended" : "onboarding"}`}>{statusLabels[assignment.status]}</span><h3>{assignment.title || assignment.member_name || "Zaduženje"}</h3><p>{assignment.member_name}{assignment.event_title ? ` · ${assignment.event_title}` : ""}</p><small>Izdato {date(assignment.issued_at)} · rok {date(assignment.due_date)}</small></div>
            <div><ul>{assignment.items.map((item) => <li key={item.id}>{item.issued_quantity} × {item.item_name}{item.kit_name ? ` — ${item.kit_name}` : ""}{remaining(item) < item.issued_quantity ? ` · preostalo ${remaining(item)}` : ""}</li>)}</ul>
              {workspace.is_manager && ["OPEN", "PARTIALLY_RETURNED", "OVERDUE"].includes(assignment.status) && <button className="button button-secondary" onClick={() => openReturn(assignment)} type="button">RAZDUŽI</button>}</div>
          </article>)}{workspace.assignments.length === 0 && <p className="wardrobe-empty">Još nema zaduženja.</p>}</div>
          {operations.luggage.length > 0 && <><h3 className="wardrobe-subtitle">Zajednički koferi i primopredaje</h3><div className="wardrobe-list">{operations.luggage.map((luggage) => <article className="wardrobe-operation-row" key={luggage.id}><div><span className="master-status onboarding">{luggage.status}</span><strong>{luggage.assignment_title}</strong><small>Odgovoran: {luggage.responsible_name}{luggage.event_title ? ` · ${luggage.event_title}` : ""}</small>{luggage.handovers.length > 0 && <details><summary>Istorija primopredaje ({luggage.handovers.length})</summary><ul>{luggage.handovers.map((handover) => <li key={handover.id}>{handover.previous_name || "Početno stanje"} → {handover.new_name} · {date(handover.created_at)}{handover.condition_note ? ` · ${handover.condition_note}` : ""}</li>)}</ul></details>}</div>{workspace.is_manager && <button className="button button-secondary" onClick={() => { setHandoverLuggageId(luggage.id); setHandoverMemberId(""); setHandoverNote(""); }} type="button">PROMENI ODGOVORNOG</button>}</article>)}</div></>}
        </div>}

        {activeTab === "repairs" && <div className="wardrobe-content"><div className="wardrobe-section-title"><div><p className="eyebrow">Posebni slučajevi</p><h2>Popravke i nedostajući delovi</h2></div></div>
          <h3 className="wardrobe-subtitle">Nalozi za popravku</h3>
          <div className="wardrobe-list">{operations.repairs.map((repair) => <article className="wardrobe-operation-row" key={repair.id}><div><span className="master-status onboarding">{repairStatusLabels[repair.status]}</span><strong>{repair.quantity} × {repair.item_name}</strong><small>{repair.member_name ? `Vraćeno od: ${repair.member_name}` : ""}{repair.assigned_name ? ` · zadužen: ${repair.assigned_name}` : ""}</small><p>{repair.description}</p></div>{workspace.is_manager && <button className="button button-secondary" onClick={() => openRepair(repair)} type="button">UREDI NALOG</button>}</article>)}{operations.repairs.length === 0 && <p className="wardrobe-empty">Nema naloga za popravku.</p>}</div>
          <h3 className="wardrobe-subtitle">Izgubljeni delovi</h3>
          <div className="wardrobe-list">{operations.loss_cases.map((loss) => <article className="wardrobe-operation-row" key={loss.id}><div><span className={`master-status ${loss.status === "RESOLVED" ? "active" : "suspended"}`}>{loss.status === "RESOLVED" ? "REŠENO" : "OTVORENO"}</span><strong>{loss.quantity} × {loss.item_name}</strong><small>{loss.member_name} · {loss.assignment_title}</small>{loss.resolution_note && <p>{loss.resolution_note}</p>}</div>{workspace.is_manager && loss.status !== "RESOLVED" && <button className="button button-secondary" onClick={() => { setResolvingLoss(loss); setLossForm({ resolution: "RETURNED", replacement_quantity: String(loss.quantity), note: "" }); }} type="button">REŠI SLUČAJ</button>}</article>)}{operations.loss_cases.length === 0 && <p className="wardrobe-empty">Nema otvorenih ili ranije rešenih gubitaka.</p>}</div>
        </div>}

        {activeTab === "categories" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Prilagodljiv spisak</p><h2>Kategorije</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={openNewCategory} type="button">+ NOVA KATEGORIJA</button>}</div>
          <div className="wardrobe-category-grid">{workspace.categories.map((category) => <article key={category.id}><span>{category.code || "—"}</span><strong>{category.name}</strong><small>{category.is_footwear ? "Koristi brojeve obuće" : "Bez veličina"}</small>{workspace.is_manager && <button onClick={() => openCategoryEdit(category)} type="button">Izmeni</button>}</article>)}</div>
        </div>}
      </section>

      {showItemForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Inventar</p><h2>{editingItemId ? "Izmena stavke" : "Nova stavka"}</h2></div><button onClick={() => { setShowItemForm(false); setEditingItemId(""); }} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Kategorija</span><select className="input" value={itemForm.category_id} onChange={(e) => setItemForm({ ...itemForm, category_id: e.target.value, shoe_size: "" })}>{workspace.categories.filter((c) => c.is_active).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          <label className="form-field"><span>Naziv</span><input className="input" value={itemForm.name} onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })} /></label>
          <label className="form-field"><span>Interna oznaka</span><input className="input" value={itemForm.internal_code} onChange={(e) => setItemForm({ ...itemForm, internal_code: e.target.value })} /></label>
          <label className="form-field"><span>Uzrast</span><select className="input" value={itemForm.age_group} onChange={(e) => setItemForm({ ...itemForm, age_group: e.target.value })}><option value="CHILD">Dečje</option><option value="ADULT">Odraslo</option><option value="UNIVERSAL">Univerzalno</option></select></label>
          <label className="form-field"><span>Namena</span><select className="input" value={itemForm.gender_group} onChange={(e) => setItemForm({ ...itemForm, gender_group: e.target.value })}><option value="MALE">Muško</option><option value="FEMALE">Žensko</option><option value="UNISEX">Univerzalno</option></select></label>
          {selectedCategory?.is_footwear && <label className="form-field"><span>Broj obuće</span><input className="input" type="number" min="15" max="55" value={itemForm.shoe_size} onChange={(e) => setItemForm({ ...itemForm, shoe_size: e.target.value })} /></label>}
          <label className="form-field"><span>Ukupna količina</span><input className="input" type="number" min="0" value={itemForm.total_quantity} onChange={(e) => setItemForm({ ...itemForm, total_quantity: e.target.value })} /></label>
          <fieldset className="wardrobe-checks"><legend>Koreografije i igre</legend>{workspace.repertoire.map((r) => <label key={r.id}><input type="checkbox" checked={itemForm.repertoire_ids.includes(r.id)} onChange={() => setItemForm({ ...itemForm, repertoire_ids: itemForm.repertoire_ids.includes(r.id) ? itemForm.repertoire_ids.filter((id) => id !== r.id) : [...itemForm.repertoire_ids, r.id] })} /> {r.name}</label>)}</fieldset>
          <label className="form-field wardrobe-wide"><span>Napomena</span><textarea className="input" value={itemForm.note} onChange={(e) => setItemForm({ ...itemForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => { setShowItemForm(false); setEditingItemId(""); }} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving} onClick={() => void saveItem()} type="button">SAČUVAJ</button></footer>
      </section></div>}

      {showCategoryForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Kategorije</p><h2>{editingCategoryId ? "Izmena kategorije" : "Nova kategorija"}</h2></div><button onClick={() => { setShowCategoryForm(false); setEditingCategoryId(""); }} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Naziv</span><input className="input" value={categoryForm.name} onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })} /></label><label className="form-field"><span>Kratka oznaka</span><input className="input" value={categoryForm.code} onChange={(e) => setCategoryForm({ ...categoryForm, code: e.target.value })} /></label><label className="wardrobe-checkbox"><input type="checkbox" checked={categoryForm.is_footwear} onChange={(e) => setCategoryForm({ ...categoryForm, is_footwear: e.target.checked })} /> Kategorija koristi brojeve obuće</label></div>
        <footer><button className="button button-secondary" onClick={() => setShowCategoryForm(false)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveCategory()} type="button">DODAJ</button></footer>
      </section></div>}

      {showKitForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Kompleti</p><h2>{editingKitId ? "Izmena kompleta" : "Novi komplet"}</h2></div><button onClick={() => { setShowKitForm(false); setEditingKitId(""); }} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Naziv</span><input className="input" value={kitForm.name} onChange={(e) => setKitForm({ ...kitForm, name: e.target.value })} /></label><label className="form-field"><span>Interna oznaka</span><input className="input" value={kitForm.internal_code} onChange={(e) => setKitForm({ ...kitForm, internal_code: e.target.value })} /></label><label className="form-field"><span>Uzrast</span><select className="input" value={kitForm.age_group} onChange={(e) => setKitForm({ ...kitForm, age_group: e.target.value })}><option value="CHILD">Dečje</option><option value="ADULT">Odraslo</option><option value="UNIVERSAL">Univerzalno</option></select></label><label className="form-field"><span>Namena</span><select className="input" value={kitForm.gender_group} onChange={(e) => setKitForm({ ...kitForm, gender_group: e.target.value })}><option value="MALE">Muško</option><option value="FEMALE">Žensko</option><option value="UNISEX">Univerzalno</option></select></label>
          <fieldset className="wardrobe-checks wardrobe-wide"><legend>Delovi kompleta i količine</legend>{workspace.items.filter((i) => i.is_active).map((item) => <label className="wardrobe-kit-line" key={item.id}><input type="checkbox" checked={Boolean(kitForm.items[item.id])} onChange={() => { const next = { ...kitForm.items }; if (next[item.id]) delete next[item.id]; else next[item.id] = "1"; setKitForm({ ...kitForm, items: next }); }} /><span>{item.name}{item.shoe_size ? ` · ${item.shoe_size}` : ""}</span>{kitForm.items[item.id] && <input aria-label={`Količina za ${item.name}`} className="input" type="number" min="1" max="99" value={kitForm.items[item.id]} onChange={(e) => setKitForm({ ...kitForm, items: { ...kitForm.items, [item.id]: e.target.value } })} />}</label>)}</fieldset></div>
        <footer><button className="button button-secondary" onClick={() => { setShowKitForm(false); setEditingKitId(""); }} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveKit()} type="button">SAČUVAJ</button></footer>
      </section></div>}

      {showAssignmentForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Izdavanje</p><h2>Novo zaduženje</h2></div><button onClick={() => setShowAssignmentForm(false)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Način izdavanja</span><select className="input" value={assignmentForm.assignment_type} onChange={(e) => setAssignmentForm({ ...assignmentForm, assignment_type: e.target.value })}><option value="MEMBER">Lično članu</option><option value="LUGGAGE">Zajednički kofer</option></select></label><label className="form-field"><span>Odgovorni član</span><select className="input" value={assignmentForm.assigned_member_id} onChange={(e) => setAssignmentForm({ ...assignmentForm, assigned_member_id: e.target.value })}><option value="">Izaberite člana</option>{workspace.members.map((m) => <option key={m.id} value={m.id}>{m.name}{m.shoe_size ? ` · obuća ${m.shoe_size}` : ""}</option>)}</select></label>
          <label className="form-field"><span>Događaj</span><select className="input" value={assignmentForm.event_id} onChange={(e) => setAssignmentForm({ ...assignmentForm, event_id: e.target.value, due_date: "" })}><option value="">Nije povezano sa događajem</option>{workspace.events.map((event) => <option key={event.id} value={event.id}>{event.title}</option>)}</select></label><label className="form-field"><span>{assignmentForm.assignment_type === "LUGGAGE" ? "Naziv kofera" : "Naziv zaduženja"}</span><input className="input" value={assignmentForm.title} onChange={(e) => setAssignmentForm({ ...assignmentForm, title: e.target.value })} /></label>
          {!assignmentForm.event_id && <label className="form-field"><span>Rok vraćanja</span><input className="input" type="date" value={assignmentForm.due_date} onChange={(e) => setAssignmentForm({ ...assignmentForm, due_date: e.target.value })} /></label>}
          <fieldset className="wardrobe-checks wardrobe-wide"><legend>Kompleti — može se izabrati više</legend>{workspace.kits.filter((k) => k.is_active).map((kit) => <label key={kit.id}><input type="checkbox" checked={assignmentForm.kit_ids.includes(kit.id)} onChange={() => setAssignmentForm({ ...assignmentForm, kit_ids: assignmentForm.kit_ids.includes(kit.id) ? assignmentForm.kit_ids.filter((id) => id !== kit.id) : [...assignmentForm.kit_ids, kit.id] })} /> {kit.name}</label>)}</fieldset><label className="form-field wardrobe-wide"><span>Napomena</span><textarea className="input" value={assignmentForm.note} onChange={(e) => setAssignmentForm({ ...assignmentForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setShowAssignmentForm(false)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveAssignment()} type="button">POTVRDI ZADUŽENJE</button></footer>
      </section></div>}

      {editingRepair && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Popravka</p><h2>{editingRepair.item_name}</h2></div><button onClick={() => setEditingRepair(null)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Ko obavlja popravku</span><select className="input" value={repairForm.assignee_type} onChange={(e) => setRepairForm({ ...repairForm, assignee_type: e.target.value, assigned_member_id: "", external_name: "", external_contact: "" })}><option value="MEMBER">Član koji je koristio nošnju</option><option value="GUARDIAN">Roditelj maloletnog člana</option><option value="SOCIETY_PERSON">Drugi član društva</option><option value="EXTERNAL">Spoljni saradnik</option></select></label>
          {repairForm.assignee_type !== "EXTERNAL" ? <label className="form-field"><span>Zadužena osoba</span><select className="input" value={repairForm.assigned_member_id} onChange={(e) => setRepairForm({ ...repairForm, assigned_member_id: e.target.value })}><option value="">Još nije određena</option>{workspace.members.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}</select></label> : <><label className="form-field"><span>Ime / naziv saradnika</span><input className="input" value={repairForm.external_name} onChange={(e) => setRepairForm({ ...repairForm, external_name: e.target.value })} /></label><label className="form-field"><span>Kontakt</span><input className="input" value={repairForm.external_contact} onChange={(e) => setRepairForm({ ...repairForm, external_contact: e.target.value })} /></label></>}
          <label className="form-field"><span>Status</span><select className="input" value={repairForm.status} onChange={(e) => setRepairForm({ ...repairForm, status: e.target.value })}>{Object.entries(repairStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><label className="form-field"><span>Rok</span><input className="input" type="date" value={repairForm.due_date} onChange={(e) => setRepairForm({ ...repairForm, due_date: e.target.value })} /></label><label className="form-field"><span>Trošak</span><input className="input" type="number" min="0" value={repairForm.cost} onChange={(e) => setRepairForm({ ...repairForm, cost: e.target.value })} /></label><label className="form-field wardrobe-wide"><span>Opis popravke</span><textarea className="input" value={repairForm.description} onChange={(e) => setRepairForm({ ...repairForm, description: e.target.value })} /></label><label className="form-field wardrobe-wide"><span>Napomena</span><textarea className="input" value={repairForm.note} onChange={(e) => setRepairForm({ ...repairForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setEditingRepair(null)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveRepair()} type="button">SAČUVAJ NALOG</button></footer>
      </section></div>}

      {resolvingLoss && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Izgubljeni deo</p><h2>{resolvingLoss.item_name}</h2></div><button onClick={() => setResolvingLoss(null)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Način rešavanja</span><select className="input" value={lossForm.resolution} onChange={(e) => setLossForm({ ...lossForm, resolution: e.target.value })}><option value="RETURNED">Naknadno pronađeno i vraćeno</option><option value="REPLACED">Prihvaćena fizička zamena</option><option value="FINANCIAL">Finansijska nadoknada</option><option value="WRITTEN_OFF">Otpis društva</option><option value="OTHER">Drugo rešenje</option></select></label>{lossForm.resolution === "REPLACED" && <label className="form-field"><span>Prihvaćena količina zamene</span><input className="input" type="number" min="1" max={resolvingLoss.quantity} value={lossForm.replacement_quantity} onChange={(e) => setLossForm({ ...lossForm, replacement_quantity: e.target.value })} /></label>}<label className="form-field wardrobe-wide"><span>Obavezna napomena</span><textarea className="input" value={lossForm.note} onChange={(e) => setLossForm({ ...lossForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setResolvingLoss(null)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void resolveLoss()} type="button">POTVRDI REŠENJE</button></footer>
      </section></div>}

      {handoverLuggageId && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Primopredaja</p><h2>Promena odgovornog člana</h2></div><button onClick={() => setHandoverLuggageId("")} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Novi odgovorni član</span><select className="input" value={handoverMemberId} onChange={(e) => setHandoverMemberId(e.target.value)}><option value="">Izaberite člana</option>{workspace.members.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}</select></label><label className="form-field wardrobe-wide"><span>Stanje kofera i napomena</span><textarea className="input" value={handoverNote} onChange={(e) => setHandoverNote(e.target.value)} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setHandoverLuggageId("")} type="button">OTKAŽI</button><button className="button button-primary" disabled={!handoverMemberId} onClick={() => void handoverLuggage()} type="button">POTVRDI PRIMOPREDAJU</button></footer>
      </section></div>}

      {returnAssignment && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Povrat garderobe</p><h2>{returnAssignment.member_name}</h2></div><button onClick={() => setReturnAssignment(null)} type="button">×</button></header>
        <div className="wardrobe-return-list">{returnAssignment.items.filter((item) => remaining(item) > 0).map((item) => <article key={item.id}><div><strong>{item.item_name}</strong><span>Preostalo za razduženje: {remaining(item)}</span></div><input className="input" type="number" min="0" max={remaining(item)} value={returnRows[item.id]?.quantity ?? "0"} onChange={(e) => setReturnRows({ ...returnRows, [item.id]: { ...returnRows[item.id], quantity: e.target.value } })} /><select className="input" value={returnRows[item.id]?.result ?? "RETURNED"} onChange={(e) => setReturnRows({ ...returnRows, [item.id]: { ...returnRows[item.id], result: e.target.value } })}><option value="RETURNED">Vraćeno ispravno</option><option value="LAUNDRY">Za pranje</option><option value="REPAIR">Za popravku</option><option value="DAMAGED">Oštećeno</option><option value="LOST">Izgubljeno</option></select></article>)}</div>
        <footer><button className="button button-secondary" onClick={() => setReturnAssignment(null)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void recordReturn()} type="button">POTVRDI RAZDUŽENJE</button></footer>
      </section></div>}
    </>
  );
}
