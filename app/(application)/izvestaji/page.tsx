"use client";

import { Fragment, useCallback, useEffect, useState } from "react";
import { getSupabaseClient, type Society } from "../../_lib/supabaseClient";

type ReportTab = "membership" | "finance" | "attendance" | "events" | "wardrobe" | "completion" | "emails" | "activity";
type EmailAttempt = { attempt_number:number; started_at:string; completed_at:string|null; status:string; error:string|null };
type EmailLogItem = { id:string; message_type:string; recipient_email:string; recipient_name:string|null; sender_email:string|null; subject:string; status:string; attempt_count:number; last_error:string|null; created_at:string; last_attempt_at:string|null; sent_at:string|null; receipt_number:string|null; attempts:EmailAttempt[] };
type ReportsOverview = {
  can_view:boolean;
  access:Record<ReportTab,boolean>;
  membership:{ active:number; inactive:number; minors:number; incomplete:number; without_section:number; custom_fee:number; exempt_fee:number; sections:Array<{id:string;name:string;member_count:number}> };
  finance:{ posted_payments:number; payment_count:number; open_amount:number; open_count:number; overdue_count:number; membership_amount:number; event_amount:number };
  attendance:{ sessions:number; open_sessions:number; present:number; absent:number; by_section:Array<{id:string;name:string;sessions:number;present:number;absent:number}> };
  events:{ total:number; approved:number; completed:number; cancelled:number; participants:number; recent:Array<{id:string;title:string;status:string;event_type:string;departure_at:string|null;created_at:string;participant_count:number}> };
  wardrobe:{ items:number; quantity:number; active_assignments:number; overdue_assignments:number; open_repairs:number; open_losses:number };
  data_completion:{ pending:number; approved:number; rejected:number; awaiting_data:number; awaiting_review:number };
  activity:Array<{id:string;action:string;entity_type:string;reason:string|null;actor_role:string|null;created_at:string;module:string}>;
};

const tabs:Array<{id:ReportTab;label:string}> = [
  {id:"membership",label:"Članstvo"},{id:"finance",label:"Članarine i uplate"},
  {id:"attendance",label:"Prisustvo"},{id:"events",label:"Događaji"},
  {id:"wardrobe",label:"Garderoba"},{id:"completion",label:"Dopuna podataka"},
  {id:"emails",label:"Evidencija emailova"},{id:"activity",label:"Aktivnosti korisnika"}
];
const typeLabels:Record<string,string> = { MEMBER_DATA_INVITATION:"Dopuna podataka člana",GUARDIAN_DATA_INVITATION:"Dopuna podataka roditelja",PAYMENT_CONFIRMATION:"Potvrda uplate",PAYMENT_VOIDED:"Poništavanje uplate",PAYMENT_REMINDER:"Opomena" };
const statusLabels:Record<string,string> = { PENDING:"Čeka",SENDING:"Šalje se",SENT:"Poslato",FAILED:"Neuspešno",CANCELLED:"Otkazano",APPROVED:"Odobreno",COMPLETED:"Završeno",REJECTED:"Odbijeno" };
const activityLabels:Record<string,string> = { FINANCE:"Finansije",WARDROBE:"Garderoba" };

function dateTime(value?:string|null) { if(!value)return "—"; return new Intl.DateTimeFormat("sr-Latn-RS",{day:"2-digit",month:"2-digit",year:"numeric",hour:"2-digit",minute:"2-digit"}).format(new Date(value)); }
function money(value:number) { return new Intl.NumberFormat("sr-Latn-RS",{minimumFractionDigits:0,maximumFractionDigits:2}).format(Number(value)||0)+" RSD"; }
function getError(error:unknown) { if(error instanceof Error)return error.message; if(typeof error==="object"&&error&&"message" in error)return String(error.message); return "Izveštaj nije dostupan."; }
function Kpi({label,value,detail}:{label:string;value:string|number;detail?:string}) { return <article className="report-kpi"><span>{label}</span><strong>{value}</strong>{detail&&<small>{detail}</small>}</article>; }
function Empty({children}:{children:string}) { return <div className="card attendance-empty">{children}</div>; }

export default function IzvestajiPage() {
  const [society,setSociety]=useState<Society|null>(null);
  const [activeTab,setActiveTab]=useState<ReportTab>("membership");
  const [overview,setOverview]=useState<ReportsOverview|null>(null);
  const [messages,setMessages]=useState<EmailLogItem[]>([]);
  const [status,setStatus]=useState(""); const [messageType,setMessageType]=useState(""); const [query,setQuery]=useState("");
  const [expandedId,setExpandedId]=useState<string|null>(null); const [loading,setLoading]=useState(true); const [emailLoading,setEmailLoading]=useState(false); const [error,setError]=useState("");

  const loadMessages=useCallback(async(currentSociety:Society,nextStatus="",nextType="",nextQuery="")=>{
    setEmailLoading(true); setError("");
    try { const {data,error:loadError}=await (getSupabaseClient().rpc as any)("auth_list_society_email_log",{p_society_id:currentSociety.id,p_status:nextStatus||null,p_message_type:nextType||null,p_query:nextQuery.trim()||null,p_limit:150}); if(loadError)throw loadError; setMessages(data?.messages??[]); }
    catch(loadError){setError(getError(loadError));setMessages([]);} finally{setEmailLoading(false);}
  },[]);

  useEffect(()=>{void(async()=>{try{
    const supabase=getSupabaseClient(); const {data:context,error:contextError}=await supabase.rpc("auth_get_application_context"); if(contextError)throw contextError;
    const membership=context?.memberships?.[0]; if(!membership)throw new Error("Aktivno društvo nije pronađeno.");
    const currentSociety={id:membership.society_id,name:membership.society_name} as Society; setSociety(currentSociety);
    const {data,error:reportError}=await (supabase.rpc as any)("auth_get_society_reports_overview",{p_society_id:currentSociety.id}); if(reportError)throw reportError;
    const reportData=data as ReportsOverview; const firstAllowed=tabs.find(tab=>reportData.access?.[tab.id]); if(!firstAllowed)throw new Error("Nemate dodeljeno ovlašćenje ni za jedan izveštaj.");
    setActiveTab(firstAllowed.id); setOverview(reportData);
  }catch(loadError){setError(getError(loadError));}finally{setLoading(false);}})();},[]);

  function selectTab(tab:ReportTab){setActiveTab(tab);setError("");if(tab==="emails"&&society&&messages.length===0)void loadMessages(society);}

  return <main className="page reports-page">
    <header className="page-header"><div><p className="eyebrow">Izveštaji</p><h1>Pregled društva</h1><p>Članstvo, finansije i operativne evidencije na jednom mestu.</p></div></header>
    {overview&&<nav className="section-tabs reports-tabs" aria-label="Izveštaji">{tabs.filter(tab=>overview.access?.[tab.id]).map(tab=><button className={activeTab===tab.id?"active":""} key={tab.id} onClick={()=>selectTab(tab.id)} type="button">{tab.label}</button>)}</nav>}
    {error&&<div className="feedback feedback-error">{error}</div>}
    {loading&&<Empty>Učitavanje izveštaja...</Empty>}
    {!loading&&overview&&<>
      {activeTab==="membership"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Aktivni članovi" value={overview.membership.active}/><Kpi label="Maloletni" value={overview.membership.minors}/><Kpi label="Čekaju dopunu" value={overview.membership.incomplete}/><Kpi label="Bez sekcije" value={overview.membership.without_section}/><Kpi label="Posebna članarina" value={overview.membership.custom_fee}/><Kpi label="Oslobođeni" value={overview.membership.exempt_fee}/></div><section className="card report-table-card"><h2>Članovi po sekcijama</h2><table className="report-table"><thead><tr><th>Sekcija</th><th>Broj članova</th></tr></thead><tbody>{overview.membership.sections.map(row=><tr key={row.id}><td>{row.name}</td><td>{row.member_count}</td></tr>)}</tbody></table></section></section>}
      {activeTab==="finance"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Primljene uplate" value={money(overview.finance.posted_payments)} detail={`${overview.finance.payment_count} uplata`}/><Kpi label="Otvorena dugovanja" value={money(overview.finance.open_amount)} detail={`${overview.finance.open_count} obaveza`}/><Kpi label="Zakasnela dugovanja" value={overview.finance.overdue_count}/><Kpi label="Članarine" value={money(overview.finance.membership_amount)}/><Kpi label="Kotizacije i ostalo" value={money(overview.finance.event_amount)}/></div></section>}
      {activeTab==="attendance"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Završene probe" value={overview.attendance.sessions}/><Kpi label="Otvorene probe" value={overview.attendance.open_sessions}/><Kpi label="Prisustva" value={overview.attendance.present}/><Kpi label="Izostanci" value={overview.attendance.absent}/></div><section className="card report-table-card"><h2>Prisustvo po sekcijama</h2><table className="report-table"><thead><tr><th>Sekcija</th><th>Probe</th><th>Prisutan</th><th>Odsutan</th><th>Prisustvo</th></tr></thead><tbody>{overview.attendance.by_section.map(row=>{const total=row.present+row.absent;return <tr key={row.id}><td>{row.name}</td><td>{row.sessions}</td><td>{row.present}</td><td>{row.absent}</td><td>{total?Math.round(row.present/total*100):0}%</td></tr>;})}</tbody></table></section></section>}
      {activeTab==="events"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Ukupno događaja" value={overview.events.total}/><Kpi label="Odobreni" value={overview.events.approved}/><Kpi label="Završeni" value={overview.events.completed}/><Kpi label="Otkazani" value={overview.events.cancelled}/><Kpi label="Učesnici" value={overview.events.participants}/></div><section className="card report-table-card"><h2>Poslednji događaji</h2><table className="report-table"><thead><tr><th>Naziv</th><th>Vrsta</th><th>Status</th><th>Polazak</th><th>Učesnici</th></tr></thead><tbody>{overview.events.recent.map(row=><tr key={row.id}><td>{row.title}</td><td>{row.event_type}</td><td>{statusLabels[row.status]??row.status}</td><td>{dateTime(row.departure_at)}</td><td>{row.participant_count}</td></tr>)}</tbody></table></section></section>}
      {activeTab==="wardrobe"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Vrste predmeta" value={overview.wardrobe.items}/><Kpi label="Ukupna količina" value={overview.wardrobe.quantity}/><Kpi label="Aktivna zaduženja" value={overview.wardrobe.active_assignments}/><Kpi label="Prekoračeni rokovi" value={overview.wardrobe.overdue_assignments}/><Kpi label="Na popravci" value={overview.wardrobe.open_repairs}/><Kpi label="Nerešeni gubici" value={overview.wardrobe.open_losses}/></div></section>}
      {activeTab==="completion"&&<section className="reports-content"><div className="report-kpis"><Kpi label="Čekaju obradu" value={overview.data_completion.pending}/><Kpi label="Čekaju podatke" value={overview.data_completion.awaiting_data}/><Kpi label="Čekaju pregled" value={overview.data_completion.awaiting_review}/><Kpi label="Potvrđeni" value={overview.data_completion.approved}/><Kpi label="Odbačeni" value={overview.data_completion.rejected}/></div></section>}
      {activeTab==="activity"&&<section className="card report-table-card"><h2>Poslednje aktivnosti</h2>{overview.activity.length===0?<Empty>Nema evidentiranih aktivnosti.</Empty>:<table className="report-table"><thead><tr><th>Vreme</th><th>Oblast</th><th>Radnja</th><th>Vrsta zapisa</th><th>Razlog</th></tr></thead><tbody>{overview.activity.map(row=><tr key={`${row.module}-${row.id}`}><td>{dateTime(row.created_at)}</td><td>{activityLabels[row.module]??row.module}</td><td>{row.action}</td><td>{row.entity_type}</td><td>{row.reason||"—"}</td></tr>)}</tbody></table>}</section>}
      {activeTab==="emails"&&<section className="reports-content"><section className="card email-log-filters"><label className="form-field"><span>Pretraga</span><input className="input" onChange={e=>setQuery(e.target.value)} placeholder="Primalac, email ili broj potvrde" value={query}/></label><label className="form-field"><span>Vrsta poruke</span><select className="input" onChange={e=>setMessageType(e.target.value)} value={messageType}><option value="">Sve vrste</option>{Object.entries(typeLabels).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label><label className="form-field"><span>Status</span><select className="input" onChange={e=>setStatus(e.target.value)} value={status}><option value="">Svi statusi</option>{Object.entries(statusLabels).slice(0,5).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label><button className="button button-primary" onClick={()=>society&&void loadMessages(society,status,messageType,query)} type="button">PRIKAŽI</button></section>{emailLoading?<Empty>Učitavanje evidencije...</Empty>:messages.length===0?<Empty>Nema emailova za izabrane kriterijume.</Empty>:<section className="card email-log-table-wrap"><table className="email-log-table"><thead><tr><th>Vreme</th><th>Vrsta</th><th>Primalac</th><th>Veza</th><th>Status</th><th>Pokušaji</th><th></th></tr></thead><tbody>{messages.map(message=><Fragment key={message.id}><tr><td>{dateTime(message.sent_at??message.created_at)}</td><td>{typeLabels[message.message_type]??message.message_type}</td><td><strong>{message.recipient_name||"—"}</strong><span>{message.recipient_email}</span></td><td>{message.receipt_number||"—"}</td><td><span className={`email-status ${message.status.toLowerCase()}`}>{statusLabels[message.status]??message.status}</span></td><td>{message.attempt_count}</td><td><button className="table-link" onClick={()=>setExpandedId(current=>current===message.id?null:message.id)} type="button">{expandedId===message.id?"SAKRIJ":"DETALJI"}</button></td></tr>{expandedId===message.id&&<tr className="email-log-detail"><td colSpan={7}><dl><div><dt>Pošiljalac</dt><dd>{message.sender_email||"—"}</dd></div><div><dt>Predmet</dt><dd>{message.subject}</dd></div><div><dt>Kreirano</dt><dd>{dateTime(message.created_at)}</dd></div><div><dt>Poslato</dt><dd>{dateTime(message.sent_at)}</dd></div></dl>{message.last_error&&<p className="email-log-error">{message.last_error}</p>}</td></tr>}</Fragment>)}</tbody></table></section>}</section>}
    </>}
  </main>;
}
