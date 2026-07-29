"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getSupabaseClient,
  type WardrobeAssignment,
  type WardrobeItem,
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
  const [itemForm, setItemForm] = useState({
    category_id: "", name: "", internal_code: "", age_group: "UNIVERSAL",
    gender_group: "UNISEX", shoe_size: "", total_quantity: "1", note: "",
    repertoire_ids: [] as string[]
  });
  const [kitForm, setKitForm] = useState({
    name: "", internal_code: "", age_group: "UNIVERSAL", gender_group: "UNISEX",
    note: "", item_ids: [] as string[]
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

  async function load() {
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: context, error: contextError } = await supabase.rpc("auth_get_application_context");
      if (contextError) throw contextError;
      const membership = context?.memberships?.[0];
      if (!membership) throw new Error("Aktivno članstvo nije pronađeno.");
      const { data, error: workspaceError } = await supabase.rpc("auth_get_wardrobe_workspace", {
        p_society_id: membership.society_id
      });
      if (workspaceError) throw workspaceError;
      setWorkspace(data);
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
        shoe_size: itemForm.shoe_size || null,
        total_quantity: Number(itemForm.total_quantity)
      }
    }), "Stavka garderobe je sačuvana.");
    setShowItemForm(false);
    setItemForm({ category_id: workspace.categories[0]?.id ?? "", name: "", internal_code: "",
      age_group: "UNIVERSAL", gender_group: "UNISEX", shoe_size: "",
      total_quantity: "1", note: "", repertoire_ids: [] });
  }
  async function saveCategory() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_category", {
      p_society_id: workspace.society_id, p_category: categoryForm
    }), "Kategorija je dodata.");
    setShowCategoryForm(false);
    setCategoryForm({ name: "", code: "", is_footwear: false });
  }
  async function saveKit() {
    if (!workspace) return;
    await perform(() => getSupabaseClient().rpc("auth_wardrobe_save_kit", {
      p_society_id: workspace.society_id,
      p_kit: {
        ...kitForm,
        items: kitForm.item_ids.map((wardrobe_item_id) => ({ wardrobe_item_id, quantity: 1 }))
      }
    }), "Komplet je sačuvan.");
    setShowKitForm(false);
    setKitForm({ name: "", internal_code: "", age_group: "UNIVERSAL",
      gender_group: "UNISEX", note: "", item_ids: [] });
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
            {workspace.is_manager && <button className="button button-primary" onClick={() => setShowItemForm(true)} type="button">+ DODAJ STAVKU</button>}</div>
          <div className="wardrobe-filters"><input className="input" placeholder="Pretraži naziv, kategoriju ili oznaku" value={inventoryQuery} onChange={(e) => setInventoryQuery(e.target.value)} />
            <select className="input" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}><option value="">Sva stanja</option><option value="AVAILABLE">Raspoloživo</option><option value="ASSIGNED">Zaduženo</option><option value="UNAVAILABLE">Nedostupno</option></select></div>
          <div className="wardrobe-list">{filteredItems.map((item) => <article className="wardrobe-item-row" key={item.id}>
            <div><strong>{item.name}{item.shoe_size ? ` · broj ${item.shoe_size}` : ""}</strong><span>{item.category_name} · {ageLabels[item.age_group]} · {genderLabels[item.gender_group]}</span><small>{item.internal_code || "Bez interne oznake"}{item.repertoire_names.length ? ` · ${item.repertoire_names.join(", ")}` : ""}</small></div>
            <div className="wardrobe-quantities"><span><b>{item.available_quantity}</b> raspoloživo</span><span><b>{item.assigned_quantity}</b> zaduženo</span><span><b>{item.total_quantity}</b> ukupno</span></div>
          </article>)}{filteredItems.length === 0 && <p className="wardrobe-empty">Nema stavki koje odgovaraju izabranom pregledu.</p>}</div>
        </div>}

        {activeTab === "kits" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Brzo izdavanje</p><h2>Kompleti nošnje</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={() => setShowKitForm(true)} type="button">+ NOVI KOMPLET</button>}</div>
          <div className="wardrobe-kit-grid">{workspace.kits.map((kit) => <article className="card" key={kit.id}><span>{ageLabels[kit.age_group]} · {genderLabels[kit.gender_group]}</span><h3>{kit.name}</h3><small>{kit.internal_code || "Bez interne oznake"}</small><ul>{kit.items.map((item) => <li key={item.wardrobe_item_id}>{item.quantity} × {item.name}{item.shoe_size ? ` (${item.shoe_size})` : ""}</li>)}</ul></article>)}
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
        </div>}

        {activeTab === "repairs" && <div className="wardrobe-content"><div className="wardrobe-section-title"><div><p className="eyebrow">Posebni slučajevi</p><h2>Popravke i nedostajući delovi</h2></div></div>
          <p className="wardrobe-empty">Ovde će se prikazivati otvoreni nalozi za popravku i slučajevi gubitka nastali prilikom razduživanja.</p></div>}

        {activeTab === "categories" && <div className="wardrobe-content">
          <div className="wardrobe-section-title"><div><p className="eyebrow">Prilagodljiv spisak</p><h2>Kategorije</h2></div>
            {workspace.is_manager && <button className="button button-primary" onClick={() => setShowCategoryForm(true)} type="button">+ NOVA KATEGORIJA</button>}</div>
          <div className="wardrobe-category-grid">{workspace.categories.map((category) => <article key={category.id}><span>{category.code || "—"}</span><strong>{category.name}</strong><small>{category.is_footwear ? "Koristi brojeve obuće" : "Bez veličina"}</small></article>)}</div>
        </div>}
      </section>

      {showItemForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Inventar</p><h2>Nova stavka</h2></div><button onClick={() => setShowItemForm(false)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Kategorija</span><select className="input" value={itemForm.category_id} onChange={(e) => setItemForm({ ...itemForm, category_id: e.target.value, shoe_size: "" })}>{workspace.categories.filter((c) => c.is_active).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          <label className="form-field"><span>Naziv</span><input className="input" value={itemForm.name} onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })} /></label>
          <label className="form-field"><span>Interna oznaka</span><input className="input" value={itemForm.internal_code} onChange={(e) => setItemForm({ ...itemForm, internal_code: e.target.value })} /></label>
          <label className="form-field"><span>Uzrast</span><select className="input" value={itemForm.age_group} onChange={(e) => setItemForm({ ...itemForm, age_group: e.target.value })}><option value="CHILD">Dečje</option><option value="ADULT">Odraslo</option><option value="UNIVERSAL">Univerzalno</option></select></label>
          <label className="form-field"><span>Namena</span><select className="input" value={itemForm.gender_group} onChange={(e) => setItemForm({ ...itemForm, gender_group: e.target.value })}><option value="MALE">Muško</option><option value="FEMALE">Žensko</option><option value="UNISEX">Univerzalno</option></select></label>
          {selectedCategory?.is_footwear && <label className="form-field"><span>Broj obuće</span><input className="input" type="number" min="15" max="55" value={itemForm.shoe_size} onChange={(e) => setItemForm({ ...itemForm, shoe_size: e.target.value })} /></label>}
          <label className="form-field"><span>Ukupna količina</span><input className="input" type="number" min="0" value={itemForm.total_quantity} onChange={(e) => setItemForm({ ...itemForm, total_quantity: e.target.value })} /></label>
          <fieldset className="wardrobe-checks"><legend>Koreografije i igre</legend>{workspace.repertoire.map((r) => <label key={r.id}><input type="checkbox" checked={itemForm.repertoire_ids.includes(r.id)} onChange={() => setItemForm({ ...itemForm, repertoire_ids: itemForm.repertoire_ids.includes(r.id) ? itemForm.repertoire_ids.filter((id) => id !== r.id) : [...itemForm.repertoire_ids, r.id] })} /> {r.name}</label>)}</fieldset>
          <label className="form-field wardrobe-wide"><span>Napomena</span><textarea className="input" value={itemForm.note} onChange={(e) => setItemForm({ ...itemForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setShowItemForm(false)} type="button">OTKAŽI</button><button className="button button-primary" disabled={isSaving} onClick={() => void saveItem()} type="button">SAČUVAJ</button></footer>
      </section></div>}

      {showCategoryForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Kategorije</p><h2>Nova kategorija</h2></div><button onClick={() => setShowCategoryForm(false)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Naziv</span><input className="input" value={categoryForm.name} onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })} /></label><label className="form-field"><span>Kratka oznaka</span><input className="input" value={categoryForm.code} onChange={(e) => setCategoryForm({ ...categoryForm, code: e.target.value })} /></label><label className="wardrobe-checkbox"><input type="checkbox" checked={categoryForm.is_footwear} onChange={(e) => setCategoryForm({ ...categoryForm, is_footwear: e.target.checked })} /> Kategorija koristi brojeve obuće</label></div>
        <footer><button className="button button-secondary" onClick={() => setShowCategoryForm(false)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveCategory()} type="button">DODAJ</button></footer>
      </section></div>}

      {showKitForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Kompleti</p><h2>Novi komplet</h2></div><button onClick={() => setShowKitForm(false)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Naziv</span><input className="input" value={kitForm.name} onChange={(e) => setKitForm({ ...kitForm, name: e.target.value })} /></label><label className="form-field"><span>Interna oznaka</span><input className="input" value={kitForm.internal_code} onChange={(e) => setKitForm({ ...kitForm, internal_code: e.target.value })} /></label><label className="form-field"><span>Uzrast</span><select className="input" value={kitForm.age_group} onChange={(e) => setKitForm({ ...kitForm, age_group: e.target.value })}><option value="CHILD">Dečje</option><option value="ADULT">Odraslo</option><option value="UNIVERSAL">Univerzalno</option></select></label><label className="form-field"><span>Namena</span><select className="input" value={kitForm.gender_group} onChange={(e) => setKitForm({ ...kitForm, gender_group: e.target.value })}><option value="MALE">Muško</option><option value="FEMALE">Žensko</option><option value="UNISEX">Univerzalno</option></select></label>
          <fieldset className="wardrobe-checks wardrobe-wide"><legend>Delovi kompleta</legend>{workspace.items.filter((i) => i.is_active).map((item) => <label key={item.id}><input type="checkbox" checked={kitForm.item_ids.includes(item.id)} onChange={() => setKitForm({ ...kitForm, item_ids: kitForm.item_ids.includes(item.id) ? kitForm.item_ids.filter((id) => id !== item.id) : [...kitForm.item_ids, item.id] })} /> {item.name}{item.shoe_size ? ` · ${item.shoe_size}` : ""}</label>)}</fieldset></div>
        <footer><button className="button button-secondary" onClick={() => setShowKitForm(false)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveKit()} type="button">SAČUVAJ</button></footer>
      </section></div>}

      {showAssignmentForm && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Izdavanje</p><h2>Novo zaduženje</h2></div><button onClick={() => setShowAssignmentForm(false)} type="button">×</button></header>
        <div className="my-data-form"><label className="form-field"><span>Način izdavanja</span><select className="input" value={assignmentForm.assignment_type} onChange={(e) => setAssignmentForm({ ...assignmentForm, assignment_type: e.target.value })}><option value="MEMBER">Lično članu</option><option value="LUGGAGE">Zajednički kofer</option></select></label><label className="form-field"><span>Odgovorni član</span><select className="input" value={assignmentForm.assigned_member_id} onChange={(e) => setAssignmentForm({ ...assignmentForm, assigned_member_id: e.target.value })}><option value="">Izaberite člana</option>{workspace.members.map((m) => <option key={m.id} value={m.id}>{m.name}{m.shoe_size ? ` · obuća ${m.shoe_size}` : ""}</option>)}</select></label>
          <label className="form-field"><span>Događaj</span><select className="input" value={assignmentForm.event_id} onChange={(e) => setAssignmentForm({ ...assignmentForm, event_id: e.target.value, due_date: "" })}><option value="">Nije povezano sa događajem</option>{workspace.events.map((event) => <option key={event.id} value={event.id}>{event.title}</option>)}</select></label><label className="form-field"><span>{assignmentForm.assignment_type === "LUGGAGE" ? "Naziv kofera" : "Naziv zaduženja"}</span><input className="input" value={assignmentForm.title} onChange={(e) => setAssignmentForm({ ...assignmentForm, title: e.target.value })} /></label>
          {!assignmentForm.event_id && <label className="form-field"><span>Rok vraćanja</span><input className="input" type="date" value={assignmentForm.due_date} onChange={(e) => setAssignmentForm({ ...assignmentForm, due_date: e.target.value })} /></label>}
          <fieldset className="wardrobe-checks wardrobe-wide"><legend>Kompleti — može se izabrati više</legend>{workspace.kits.filter((k) => k.is_active).map((kit) => <label key={kit.id}><input type="checkbox" checked={assignmentForm.kit_ids.includes(kit.id)} onChange={() => setAssignmentForm({ ...assignmentForm, kit_ids: assignmentForm.kit_ids.includes(kit.id) ? assignmentForm.kit_ids.filter((id) => id !== kit.id) : [...assignmentForm.kit_ids, kit.id] })} /> {kit.name}</label>)}</fieldset><label className="form-field wardrobe-wide"><span>Napomena</span><textarea className="input" value={assignmentForm.note} onChange={(e) => setAssignmentForm({ ...assignmentForm, note: e.target.value })} /></label></div>
        <footer><button className="button button-secondary" onClick={() => setShowAssignmentForm(false)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void saveAssignment()} type="button">POTVRDI ZADUŽENJE</button></footer>
      </section></div>}

      {returnAssignment && <div className="modal-backdrop"><section className="card modal-card wardrobe-modal"><header><div><p className="eyebrow">Povrat garderobe</p><h2>{returnAssignment.member_name}</h2></div><button onClick={() => setReturnAssignment(null)} type="button">×</button></header>
        <div className="wardrobe-return-list">{returnAssignment.items.filter((item) => remaining(item) > 0).map((item) => <article key={item.id}><div><strong>{item.item_name}</strong><span>Preostalo za razduženje: {remaining(item)}</span></div><input className="input" type="number" min="0" max={remaining(item)} value={returnRows[item.id]?.quantity ?? "0"} onChange={(e) => setReturnRows({ ...returnRows, [item.id]: { ...returnRows[item.id], quantity: e.target.value } })} /><select className="input" value={returnRows[item.id]?.result ?? "RETURNED"} onChange={(e) => setReturnRows({ ...returnRows, [item.id]: { ...returnRows[item.id], result: e.target.value } })}><option value="RETURNED">Vraćeno ispravno</option><option value="LAUNDRY">Za pranje</option><option value="REPAIR">Za popravku</option><option value="DAMAGED">Oštećeno</option><option value="LOST">Izgubljeno</option></select></article>)}</div>
        <footer><button className="button button-secondary" onClick={() => setReturnAssignment(null)} type="button">OTKAŽI</button><button className="button button-primary" onClick={() => void recordReturn()} type="button">POTVRDI RAZDUŽENJE</button></footer>
      </section></div>}
    </>
  );
}
