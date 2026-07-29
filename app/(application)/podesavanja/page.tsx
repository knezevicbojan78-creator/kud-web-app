"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getSupabaseClient,
  type FinanceMemberFeeSetting,
  type FinanceMembershipSettings,
  type PermissionFunctionMember,
  type PermissionMemberConfiguration,
  type PermissionSettingsData
} from "../../_lib/supabaseClient";
import GmailConnectionPanel from "../../_components/GmailConnectionPanel";

const months = [
  "Januar", "Februar", "Mart", "April", "Maj", "Jun",
  "Jul", "Avgust", "Septembar", "Oktobar", "Novembar", "Decembar"
];

const permissionModuleLabels: Record<string, string> = {
  members: "Članovi i lični podaci",
  sections: "Sekcije",
  attendance: "Prisustvo",
  events: "Događaji",
  repertoire: "Repertoar",
  finance: "Finansije",
  permissions: "Podešavanja dozvola",
  audit: "Audit"
};

const permissionScopeLabels: Record<string, string> = {
  SELF: "Sopstveni podaci",
  CHILDREN: "Sopstvena deca",
  MEMBER_SECTIONS: "Sekcije člana",
  SELF_ASSIGNED_SECTIONS: "Lično dodeljene sekcije",
  ASSIGNED_SECTIONS: "Dodeljene sekcije",
  CREATED_EVENTS: "Kreirani događaji",
  PARTICIPATING_EVENTS: "Događaji sa učešćem",
  CHILD_PARTICIPATING_EVENTS: "Događaji deteta",
  SOCIETY: "Celo društvo"
};

function errorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (typeof error === "object" && error && "message" in error) return String(error.message);
  return "Akcija nije uspela.";
}

function displayDate(value: string) {
  return new Intl.DateTimeFormat("sr-Latn-RS").format(new Date(`${value}T00:00:00`));
}

export default function PodesavanjaPage() {
  const [activeTab, setActiveTab] = useState<"membership" | "permissions" | "gmail">("membership");
  const [settings, setSettings] = useState<FinanceMembershipSettings | null>(null);
  const [societyId, setSocietyId] = useState("");
  const [actorMemberId, setActorMemberId] = useState("");
  const [amount, setAmount] = useState("");
  const [chargeableMonths, setChargeableMonths] = useState<number[]>([]);
  const [reason, setReason] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [exceptions, setExceptions] = useState<FinanceMemberFeeSetting[]>([]);
  const [memberQuery, setMemberQuery] = useState("");
  const [memberResults, setMemberResults] = useState<FinanceMemberFeeSetting[]>([]);
  const [editingMember, setEditingMember] = useState<FinanceMemberFeeSetting | null>(null);
  const [memberMode, setMemberMode] = useState<"STANDARD" | "CUSTOM" | "EXEMPT">("STANDARD");
  const [customAmount, setCustomAmount] = useState("");
  const [memberReason, setMemberReason] = useState("");
  const [permissionSettings, setPermissionSettings] = useState<PermissionSettingsData | null>(null);
  const [isLoadingPermissions, setIsLoadingPermissions] = useState(false);
  const [permissionError, setPermissionError] = useState("");
  const [permissionsRequested, setPermissionsRequested] = useState(false);
  const [permissionDraft, setPermissionDraft] = useState<Record<string, { enabled: boolean; scope_key: string | null }>>({});
  const [permissionReason, setPermissionReason] = useState("");
  const [permissionMessage, setPermissionMessage] = useState("");
  const [isSavingPermissions, setIsSavingPermissions] = useState(false);
  const [permissionMode, setPermissionMode] = useState<"function" | "member">("function");
  const [permissionMemberQuery, setPermissionMemberQuery] = useState("");
  const [permissionMembers, setPermissionMembers] = useState<PermissionFunctionMember[]>([]);
  const [selectedPermissionMember, setSelectedPermissionMember] = useState<PermissionMemberConfiguration | null>(null);
  const [memberPermissionDraft, setMemberPermissionDraft] = useState<Record<string, {
    effect: "INHERIT" | "ALLOW" | "DENY";
    scope_key: string | null;
  }>>({});

  const loadSettings = useCallback(async () => {
    setIsLoading(true);
    setError("");
    try {
      const supabase = getSupabaseClient();
      const { data: applicationContext, error: applicationContextError } =
        await supabase.rpc("auth_get_application_context");
      if (applicationContextError) throw applicationContextError;
      const membership = applicationContext?.memberships?.[0] ?? null;
      if (!membership?.functions.includes("Predsednik")) {
        throw new Error("Samo predsednik može da menja podešavanja članarine.");
      }
      setSocietyId(membership.society_id);
      setActorMemberId(membership.society_member_id);
      const { data, error: settingsError } = await supabase.rpc(
        "finance_get_membership_settings",
        {
          p_society_id: membership.society_id,
          p_actor_member_id: membership.society_member_id
        }
      );
      if (settingsError) throw settingsError;
      setSettings(data);
      setAmount(data.standard_amount == null ? "" : String(data.standard_amount));
      setChargeableMonths(data.chargeable_months ?? []);
      const { data: exceptionRows, error: exceptionsError } = await supabase.rpc(
        "finance_list_member_fee_settings",
        {
          p_society_id: membership.society_id,
          p_query: "",
          p_only_nonstandard: true,
          p_actor_member_id: membership.society_member_id
        }
      );
      if (exceptionsError) throw exceptionsError;
      setExceptions(exceptionRows ?? []);
    } catch (loadError) {
      setError(errorMessage(loadError));
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!settings || !actorMemberId || memberQuery.trim().length < 2) {
      setMemberResults([]);
      return;
    }
    const timeout = window.setTimeout(async () => {
      const { data, error: searchError } = await getSupabaseClient().rpc(
        "finance_list_member_fee_settings",
        {
          p_society_id: settings.society_id,
          p_query: memberQuery.trim(),
          p_only_nonstandard: false,
          p_actor_member_id: actorMemberId
        }
      );
      if (searchError) setError(errorMessage(searchError));
      else setMemberResults(data ?? []);
    }, 250);
    return () => window.clearTimeout(timeout);
  }, [actorMemberId, memberQuery, settings]);

  useEffect(() => {
    void loadSettings();
  }, [loadSettings]);

  const loadPermissionSettings = useCallback(async (functionId?: string | null) => {
    setPermissionsRequested(true);
    setIsLoadingPermissions(true);
    setPermissionError("");
    try {
      const { data, error: permissionsError } = await getSupabaseClient().rpc(
        "auth_permissions_get_settings",
        { p_function_id: functionId ?? null }
      );
      if (permissionsError) throw permissionsError;
      setPermissionSettings(data);
      setPermissionDraft(Object.fromEntries(
        data.rules.map((rule) => [
          rule.permission_key,
          { enabled: rule.is_enabled, scope_key: rule.current_scope }
        ])
      ));
      setPermissionReason("");
      setPermissionMessage("");
    } catch (permissionsLoadError) {
      setPermissionError(errorMessage(permissionsLoadError));
    } finally {
      setIsLoadingPermissions(false);
    }
  }, []);

  useEffect(() => {
    if (activeTab === "permissions" && !permissionSettings && !isLoadingPermissions && !permissionsRequested) {
      void loadPermissionSettings();
    }
  }, [activeTab, isLoadingPermissions, loadPermissionSettings, permissionSettings, permissionsRequested]);

  useEffect(() => {
    if (new URLSearchParams(window.location.search).has("gmail")) {
      setActiveTab("gmail");
    }
  }, []);

  useEffect(() => {
    if (permissionMode !== "member" || !permissionSettings?.selected_function_id || selectedPermissionMember) return;
    const timeout = window.setTimeout(async () => {
      setPermissionError("");
      const { data, error: memberSearchError } = await getSupabaseClient().rpc(
        "auth_permissions_list_function_members",
        {
          p_function_id: permissionSettings.selected_function_id,
          p_query: permissionMemberQuery.trim()
        }
      );
      if (memberSearchError) setPermissionError(errorMessage(memberSearchError));
      else setPermissionMembers(data ?? []);
    }, 220);
    return () => window.clearTimeout(timeout);
  }, [permissionMemberQuery, permissionMode, permissionSettings?.selected_function_id, selectedPermissionMember]);

  function defaultPermissionScope(allowedScopes: string[]) {
    if (allowedScopes.includes("ASSIGNED_SECTIONS")) return "ASSIGNED_SECTIONS";
    if (allowedScopes.includes("SOCIETY")) return "SOCIETY";
    return allowedScopes[0] ?? null;
  }

  function togglePermission(permissionKey: string, allowedScopes: string[], isLocked: boolean) {
    if (isLocked) return;
    setPermissionDraft((current) => {
      const existing = current[permissionKey] ?? { enabled: false, scope_key: null };
      const enabled = !existing.enabled;
      return {
        ...current,
        [permissionKey]: {
          enabled,
          scope_key: enabled ? (existing.scope_key ?? defaultPermissionScope(allowedScopes)) : null
        }
      };
    });
    setPermissionMessage("");
  }

  async function saveFunctionPermissions() {
    if (!permissionSettings) return;
    const selectedFunction = permissionSettings.functions.find(
      (item) => item.id === permissionSettings.selected_function_id
    );
    if (selectedFunction?.is_president) {
      setPermissionError("Zaključana prava predsednika ne mogu se menjati.");
      return;
    }
    if (!permissionReason.trim()) {
      setPermissionError("Unesite razlog promene dozvola.");
      return;
    }
    const changes = permissionSettings.rules
      .filter((rule) => !rule.is_locked)
      .map((rule) => ({
        permission_key: rule.permission_key,
        enabled: permissionDraft[rule.permission_key]?.enabled ?? false,
        scope_key: permissionDraft[rule.permission_key]?.enabled
          ? permissionDraft[rule.permission_key]?.scope_key ?? defaultPermissionScope(rule.allowed_scopes)
          : null
      }))
      .filter((change) => {
        const original = permissionSettings.rules.find((rule) => rule.permission_key === change.permission_key);
        return original && (
          original.is_enabled !== change.enabled
          || (change.enabled && original.current_scope !== change.scope_key)
        );
      });
    if (changes.length === 0) {
      setPermissionError("");
      setPermissionMessage("Nema izmena za čuvanje.");
      return;
    }

    setIsSavingPermissions(true);
    setPermissionError("");
    setPermissionMessage("");
    try {
      const { data, error: saveError } = await getSupabaseClient().rpc(
        "auth_permissions_save_function_rules",
        {
          p_function_id: permissionSettings.selected_function_id,
          p_changes: changes,
          p_reason: permissionReason.trim()
        }
      );
      if (saveError) throw saveError;
      setPermissionSettings(data);
      setPermissionDraft(Object.fromEntries(
        data.rules.map((rule) => [
          rule.permission_key,
          { enabled: rule.is_enabled, scope_key: rule.current_scope }
        ])
      ));
      setPermissionReason("");
      setPermissionMessage("Izmene dozvola su sačuvane.");
    } catch (permissionsSaveError) {
      setPermissionError(errorMessage(permissionsSaveError));
    } finally {
      setIsSavingPermissions(false);
    }
  }

  async function openPermissionMember(member: PermissionFunctionMember) {
    setPermissionError("");
    setPermissionMessage("");
    const { data, error: memberError } = await getSupabaseClient().rpc(
      "auth_permissions_get_member_configuration",
      { p_target_member_id: member.society_member_id }
    );
    if (memberError) {
      setPermissionError(errorMessage(memberError));
      return;
    }
    setSelectedPermissionMember(data);
    setMemberPermissionDraft(Object.fromEntries(
      data.rules.map((rule) => [
        rule.permission_key,
        { effect: rule.override_effect, scope_key: rule.override_scope }
      ])
    ));
    setPermissionReason("");
  }

  async function saveMemberPermissions() {
    if (!selectedPermissionMember) return;
    if (!permissionReason.trim()) {
      setPermissionError("Unesite razlog promene dozvola.");
      return;
    }
    const changes = selectedPermissionMember.rules.map((rule) => {
      const draft = memberPermissionDraft[rule.permission_key] ?? {
        effect: rule.override_effect,
        scope_key: rule.override_scope
      };
      return {
        permission_key: rule.permission_key,
        effect: draft.effect,
        scope_key: draft.effect === "ALLOW"
          ? draft.scope_key ?? defaultPermissionScope(rule.allowed_scopes)
          : null
      };
    }).filter((change) => {
      const original = selectedPermissionMember.rules.find((rule) => rule.permission_key === change.permission_key);
      return original && (
        original.override_effect !== change.effect
        || (change.effect === "ALLOW" && original.override_scope !== change.scope_key)
      );
    });
    if (changes.length === 0) {
      setPermissionError("");
      setPermissionMessage("Nema izmena za čuvanje.");
      return;
    }
    setIsSavingPermissions(true);
    setPermissionError("");
    setPermissionMessage("");
    try {
      const { data, error: saveError } = await getSupabaseClient().rpc(
        "auth_permissions_save_member_overrides",
        {
          p_target_member_id: selectedPermissionMember.society_member_id,
          p_changes: changes,
          p_reason: permissionReason.trim()
        }
      );
      if (saveError) throw saveError;
      setSelectedPermissionMember(data);
      setMemberPermissionDraft(Object.fromEntries(
        data.rules.map((rule) => [
          rule.permission_key,
          { effect: rule.override_effect, scope_key: rule.override_scope }
        ])
      ));
      setPermissionReason("");
      setPermissionMessage("Pojedinačne dozvole su sačuvane.");
    } catch (memberSaveError) {
      setPermissionError(errorMessage(memberSaveError));
    } finally {
      setIsSavingPermissions(false);
    }
  }

  function toggleMonth(month: number) {
    setChargeableMonths((current) =>
      current.includes(month)
        ? current.filter((item) => item !== month)
        : [...current, month].sort((a, b) => a - b)
    );
    setMessage("");
  }

  async function saveSettings() {
    if (!settings || !actorMemberId) return;
    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      setError("Standardna članarina mora biti veća od nule.");
      return;
    }
    if (!reason.trim()) {
      setError("Unesite razlog promene.");
      return;
    }

    setIsSaving(true);
    setError("");
    setMessage("");
    try {
      const { data, error: saveError } = await getSupabaseClient().rpc(
        "finance_update_membership_settings",
        {
          p_society_id: settings.society_id,
          p_standard_amount: numericAmount,
          p_chargeable_months: chargeableMonths,
          p_reason: reason.trim(),
          p_actor_member_id: actorMemberId
        }
      );
      if (saveError) throw saveError;
      setSettings(data);
      setAmount(String(data.standard_amount));
      setChargeableMonths(data.chargeable_months ?? []);
      setReason("");
      setMessage(`Izmene su sačuvane i važe od ${displayDate(data.effective_from)}`);
    } catch (saveError) {
      setError(errorMessage(saveError));
    } finally {
      setIsSaving(false);
    }
  }

  function editMember(member: FinanceMemberFeeSetting) {
    setEditingMember(member);
    setMemberMode(member.fee_mode);
    setCustomAmount(member.fee_mode === "CUSTOM" && member.fee_amount != null ? String(member.fee_amount) : "");
    setMemberReason("");
    setMemberResults([]);
    setMemberQuery("");
    setError("");
  }

  async function saveMemberFee() {
    if (!editingMember || !actorMemberId) return;
    const parsedAmount = Number(customAmount);
    if (memberMode === "CUSTOM" && (!Number.isFinite(parsedAmount) || parsedAmount <= 0)) {
      setError("Posebna članarina mora biti veća od nule.");
      return;
    }
    if (!memberReason.trim()) {
      setError("Unesite razlog promene članarine člana.");
      return;
    }
    setIsSaving(true);
    setError("");
    try {
      const { data: authData } = await getSupabaseClient().auth.getUser();
      const { error: memberFeeError } = await getSupabaseClient().rpc("finance_set_member_fee", {
        p_society_member_id: editingMember.society_member_id,
        p_fee_mode: memberMode,
        p_custom_amount: memberMode === "CUSTOM" ? parsedAmount : null,
        p_reason: memberReason.trim(),
        p_actor_user_id: authData.user?.id ?? null,
        p_actor_member_id: actorMemberId
      });
      if (memberFeeError) throw memberFeeError;
      setEditingMember(null);
      setMessage(`Izmena za člana ${editingMember.display_name} sačuvana je za sledeći mesec.`);
      await loadSettings();
    } catch (memberFeeError) {
      setError(errorMessage(memberFeeError));
    } finally {
      setIsSaving(false);
    }
  }

  const selectedPermissionFunction = permissionSettings?.functions.find(
    (item) => item.id === permissionSettings.selected_function_id
  ) ?? null;

  return (
    <>
      <section className="page-heading">
        <h1>Podešavanja</h1>
      </section>

      <section className="card settings-card">
        <nav className="section-tabs" aria-label="Podešavanja">
          <button className={activeTab === "membership" ? "active" : ""} onClick={() => setActiveTab("membership")} type="button">
            Članarina
          </button>
          <button className={activeTab === "permissions" ? "active" : ""} onClick={() => setActiveTab("permissions")} type="button">
            Dozvole
          </button>
          <button className={activeTab === "gmail" ? "active" : ""} onClick={() => setActiveTab("gmail")} type="button">
            Gmail povezivanje
          </button>
        </nav>

        {activeTab === "membership" && <div className="settings-membership-panel">
          {isLoading && <p className="program-empty-row">Učitavanje podešavanja...</p>}
          {!isLoading && error && !settings && <p className="alert alert-error">{error}</p>}
          {!isLoading && settings && (
            <>
              <header>
                <div>
                  <h2>Članarina</h2>
                  <p>Promene važe od prvog dana sledećeg meseca i ostaju aktivne dok ih predsednik ponovo ne promeni.</p>
                </div>
                <span className="settings-effective">Nove izmene važe od {displayDate(settings.effective_from)}</span>
              </header>

              {error && <p className="alert alert-error">{error}</p>}
              {message && <p className="alert alert-success">{message}</p>}

              <section className="settings-block">
                <div>
                  <h3>Standardna mesečna članarina</h3>
                  <p>Članovi sa režimom „Standardna“ koriste ovaj iznos.</p>
                </div>
                <label className="settings-money-field">
                  <input className="input" min="0.01" step="0.01" type="number" value={amount}
                    onChange={(event) => setAmount(event.target.value)} />
                  <strong>{settings.currency}</strong>
                </label>
              </section>

              <section className="settings-block settings-month-block">
                <div>
                  <h3>Meseci u kojima se članarina naplaćuje</h3>
                  <p>Štiklirano pravilo ponavlja se svake godine bez vremenskog ograničenja.</p>
                </div>
                <div className="settings-month-grid">
                  {months.map((name, index) => {
                    const month = index + 1;
                    return (
                      <label className={chargeableMonths.includes(month) ? "selected" : ""} key={name}>
                        <input checked={chargeableMonths.includes(month)} onChange={() => toggleMonth(month)} type="checkbox" />
                        <span>{name}</span>
                      </label>
                    );
                  })}
                </div>
              </section>

              <label className="form-field settings-reason">
                <span>Razlog promene *</span>
                <textarea className="input" rows={2} value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="Na primer: letnja pauza u julu i avgustu" />
              </label>

              <div className="header-actions">
                <button className="button button-primary" disabled={isSaving} onClick={() => void saveSettings()} type="button">
                  {isSaving ? "ČUVANJE..." : "SAČUVAJ IZMENE"}
                </button>
              </div>

              <section className="settings-member-fees">
                <header>
                  <div>
                    <h3>Posebne članarine i oslobođenja</h3>
                    <p>Ovde su prikazani samo članovi koji ne koriste standardnu članarinu.</p>
                  </div>
                  <label className="form-field">
                    <span>Pronađi člana</span>
                    <input className="input" placeholder="Ime, prezime, email ili telefon"
                      value={memberQuery} onChange={(event) => setMemberQuery(event.target.value)} />
                  </label>
                </header>
                {memberResults.length > 0 && <div className="settings-member-search-results">
                  {memberResults.map((member) => <button key={member.society_member_id}
                    onClick={() => editMember(member)} type="button">
                    <strong>{member.display_name}</strong>
                    <span>{member.fee_mode === "STANDARD" ? "Standardna" : member.fee_mode === "CUSTOM" ? "Posebna" : "Oslobođen"}</span>
                  </button>)}
                </div>}
                <div className="settings-exception-list">
                  {exceptions.length === 0 && <p className="program-empty-row">Svi aktivni članovi koriste standardnu članarinu.</p>}
                  {exceptions.map((member) => <button key={member.society_member_id}
                    onClick={() => editMember(member)} type="button">
                    <strong>{member.display_name}</strong>
                    <span>{member.fee_mode === "EXEMPT"
                      ? "Oslobođen članarine"
                      : `Posebna članarina · ${member.fee_amount} ${member.currency}`}</span>
                    <small>Izmeni</small>
                  </button>)}
                </div>
              </section>
            </>
          )}
        </div>}

        {activeTab === "permissions" && <div className="permissions-settings-panel">
          {isLoadingPermissions && <p className="program-empty-row">Učitavanje dozvola...</p>}
          {permissionError && <p className="alert alert-error">{permissionError}</p>}
          {permissionMessage && <p className="alert alert-success">{permissionMessage}</p>}
          {!isLoadingPermissions && permissionSettings && <>
            <div className="permissions-toolbar">
              <label className="form-field">
                <span>Funkcija</span>
                <select className="input" value={permissionSettings.selected_function_id}
                  onChange={(event) => {
                    setSelectedPermissionMember(null);
                    setPermissionMembers([]);
                    setPermissionMemberQuery("");
                    void loadPermissionSettings(event.target.value);
                  }}>
                  {permissionSettings.functions.map((memberFunction) => (
                    <option key={memberFunction.id} value={memberFunction.id}>{memberFunction.name}</option>
                  ))}
                </select>
              </label>
              <div className="permission-mode-switch">
                <button className={permissionMode === "function" ? "active" : ""} onClick={() => {
                  setPermissionMode("function");
                  setSelectedPermissionMember(null);
                }} type="button">Pravila funkcije</button>
                <button className={permissionMode === "member" ? "active" : ""} onClick={() => {
                  setPermissionMode("member");
                  setPermissionMessage("");
                }} type="button">Pojedinačni izuzetak</button>
              </div>
            </div>

            {permissionMode === "function" && <><div className="permission-module-list">
              {Object.entries(
                permissionSettings.rules.reduce<Record<string, PermissionSettingsData["rules"]>>((groups, rule) => {
                  (groups[rule.module_key] ??= []).push(rule);
                  return groups;
                }, {})
              ).map(([moduleKey, rules]) => (
                <section className="permission-module-card" key={moduleKey}>
                  <h3>{permissionModuleLabels[moduleKey] ?? moduleKey}</h3>
                  <div className="permission-rule-list">
                    {rules.map((rule) => (
                      <label
                        className={`permission-rule-toggle ${
                          permissionDraft[rule.permission_key]?.enabled ? "is-enabled" : "is-disabled"
                        } ${rule.is_locked || selectedPermissionFunction?.is_president ? "is-locked" : ""}`}
                        key={rule.permission_key}
                        title={rule.description ?? rule.label}
                      >
                        <input
                          checked={permissionDraft[rule.permission_key]?.enabled ?? false}
                          disabled={rule.is_locked || Boolean(selectedPermissionFunction?.is_president)}
                          onChange={() => togglePermission(
                            rule.permission_key,
                            rule.allowed_scopes,
                            rule.is_locked || Boolean(selectedPermissionFunction?.is_president)
                          )}
                          type="checkbox"
                        />
                        <span>{rule.label}</span>
                        {permissionDraft[rule.permission_key]?.enabled && (
                          rule.allowed_scopes.length > 1 && !rule.is_locked && !selectedPermissionFunction?.is_president
                            ? <select
                                className="permission-scope-select"
                                onClick={(event) => event.stopPropagation()}
                                onChange={(event) => setPermissionDraft((current) => ({
                                  ...current,
                                  [rule.permission_key]: {
                                    enabled: true,
                                    scope_key: event.target.value
                                  }
                                }))}
                                value={permissionDraft[rule.permission_key]?.scope_key ?? defaultPermissionScope(rule.allowed_scopes) ?? ""}
                              >
                                {rule.allowed_scopes.map((scope) => (
                                  <option key={scope} value={scope}>{permissionScopeLabels[scope] ?? scope}</option>
                                ))}
                              </select>
                            : <small>{permissionScopeLabels[
                                permissionDraft[rule.permission_key]?.scope_key ?? ""
                              ] ?? permissionDraft[rule.permission_key]?.scope_key}</small>
                        )}
                        {rule.is_locked && <small className="permission-lock">Zaključano</small>}
                      </label>
                    ))}
                  </div>
                </section>
              ))}
            </div>
            {!selectedPermissionFunction?.is_president && <div className="permissions-save-bar">
              <label className="form-field">
                <span>Razlog promene *</span>
                <input
                  className="input"
                  onChange={(event) => setPermissionReason(event.target.value)}
                  placeholder="Kratko obrazloženje"
                  value={permissionReason}
                />
              </label>
              <button
                className="button button-primary"
                disabled={isSavingPermissions}
                onClick={() => void saveFunctionPermissions()}
                type="button"
              >
                {isSavingPermissions ? "ČUVANJE..." : "SAČUVAJ IZMENE"}
              </button>
            </div>}
            </>}

            {permissionMode === "member" && !selectedPermissionMember && <div className="permission-member-picker">
              <input
                className="input"
                onChange={(event) => setPermissionMemberQuery(event.target.value)}
                placeholder="Pretraži člana po imenu, emailu ili telefonu"
                value={permissionMemberQuery}
              />
              <div className="permission-member-results">
                {permissionMembers.length === 0 && <p className="program-empty-row">Nema članova sa izabranom funkcijom.</p>}
                {permissionMembers.map((member) => (
                  <button key={member.society_member_id} onClick={() => void openPermissionMember(member)} type="button">
                    <span><strong>{member.display_name}</strong><small>{member.active_function_names.join(" · ")}</small></span>
                    {member.individual_override_count > 0 && <small>{member.individual_override_count} izuzetaka</small>}
                  </button>
                ))}
              </div>
            </div>}

            {permissionMode === "member" && selectedPermissionMember && <>
              <div className="permission-member-heading">
                <div>
                  <strong>{selectedPermissionMember.display_name}</strong>
                  <span>{selectedPermissionMember.active_function_names.join(" · ")}</span>
                </div>
                <div className="header-actions">
                  <button className="button button-secondary" onClick={() => {
                    setMemberPermissionDraft(Object.fromEntries(
                      selectedPermissionMember.rules.map((rule) => [
                        rule.permission_key,
                        {
                          effect: rule.effective_is_locked ? rule.override_effect : "INHERIT",
                          scope_key: null
                        }
                      ])
                    ));
                    setPermissionMessage("");
                  }} type="button">VRATI NA PRAVILA FUNKCIJE</button>
                  <button className="button button-secondary" onClick={() => {
                    setSelectedPermissionMember(null);
                    setPermissionReason("");
                    setPermissionMessage("");
                  }} type="button">PROMENI ČLANA</button>
                </div>
              </div>
              <div className="permission-module-list">
                {Object.entries(
                  selectedPermissionMember.rules.reduce<Record<string, PermissionMemberConfiguration["rules"]>>((groups, rule) => {
                    (groups[rule.module_key] ??= []).push(rule);
                    return groups;
                  }, {})
                ).map(([moduleKey, rules]) => (
                  <section className="permission-module-card" key={moduleKey}>
                    <h3>{permissionModuleLabels[moduleKey] ?? moduleKey}</h3>
                    <div className="permission-member-rule-list">
                      {rules.map((rule) => {
                        const draft = memberPermissionDraft[rule.permission_key] ?? {
                          effect: rule.override_effect,
                          scope_key: rule.override_scope
                        };
                        return <div className={`permission-member-rule effect-${draft.effect.toLowerCase()}`} key={rule.permission_key}>
                          <span title={rule.effective_source_names.join(", ")}>{rule.label}</span>
                          <select
                            disabled={rule.effective_is_locked}
                            onChange={(event) => {
                              const effect = event.target.value as "INHERIT" | "ALLOW" | "DENY";
                              setMemberPermissionDraft((current) => ({
                                ...current,
                                [rule.permission_key]: {
                                  effect,
                                  scope_key: effect === "ALLOW"
                                    ? current[rule.permission_key]?.scope_key ?? defaultPermissionScope(rule.allowed_scopes)
                                    : null
                                }
                              }));
                              setPermissionMessage("");
                            }}
                            value={draft.effect}
                          >
                            <option value="INHERIT">Nasleđeno</option>
                            <option value="ALLOW">Dozvoljeno</option>
                            <option disabled={rule.effective_is_locked} value="DENY">Zabranjeno</option>
                          </select>
                          {draft.effect === "ALLOW" && <select
                            className="permission-member-scope"
                            onChange={(event) => setMemberPermissionDraft((current) => ({
                              ...current,
                              [rule.permission_key]: { effect: "ALLOW", scope_key: event.target.value }
                            }))}
                            value={draft.scope_key ?? defaultPermissionScope(rule.allowed_scopes) ?? ""}
                          >
                            {rule.allowed_scopes.map((scope) => (
                              <option key={scope} value={scope}>{permissionScopeLabels[scope] ?? scope}</option>
                            ))}
                          </select>}
                          {rule.effective_is_locked && <small>Zaključano</small>}
                        </div>;
                      })}
                    </div>
                  </section>
                ))}
              </div>
              <div className="permissions-save-bar">
                <label className="form-field">
                  <span>Razlog promene *</span>
                  <input className="input" onChange={(event) => setPermissionReason(event.target.value)}
                    placeholder="Kratko obrazloženje" value={permissionReason} />
                </label>
                <button className="button button-primary" disabled={isSavingPermissions}
                  onClick={() => void saveMemberPermissions()} type="button">
                  {isSavingPermissions ? "ČUVANJE..." : "SAČUVAJ IZMENE"}
                </button>
              </div>
            </>}
          </>}
        </div>}

        {activeTab === "gmail" && (
          societyId
            ? <GmailConnectionPanel societyId={societyId} />
            : <div className="gmail-connection-panel">
                <p className="program-empty-row">
                  {isLoading ? "Učitavanje podataka društva..." : error || "Društvo nije dostupno."}
                </p>
              </div>
        )}
      </section>

      {editingMember && settings && <div className="modal-backdrop">
        <section className="card modal-card settings-member-modal">
          <header>
            <div><p className="eyebrow">Članarina člana</p><h2>{editingMember.display_name}</h2></div>
            <button className="button button-secondary" onClick={() => setEditingMember(null)} type="button">ZATVORI</button>
          </header>
          {error && <p className="alert alert-error">{error}</p>}
          <label className="form-field">
            <span>Režim članarine</span>
            <select className="input" value={memberMode}
              onChange={(event) => setMemberMode(event.target.value as "STANDARD" | "CUSTOM" | "EXEMPT")}>
              <option value="STANDARD">Standardna članarina</option>
              <option value="CUSTOM">Posebna članarina</option>
              <option value="EXEMPT">Oslobođen članarine</option>
            </select>
          </label>
          {memberMode === "CUSTOM" && <label className="form-field">
            <span>Poseban mesečni iznos ({settings.currency})</span>
            <input className="input" min="0.01" step="0.01" type="number"
              value={customAmount} onChange={(event) => setCustomAmount(event.target.value)} />
          </label>}
          <label className="form-field">
            <span>Razlog promene *</span>
            <textarea className="input" rows={3} value={memberReason}
              onChange={(event) => setMemberReason(event.target.value)} />
          </label>
          <p className="settings-effective">Nova vrednost važi od {displayDate(settings.effective_from)}</p>
          <div className="header-actions">
            <button className="button button-secondary" onClick={() => setEditingMember(null)} type="button">OTKAŽI</button>
            <button className="button button-primary" disabled={isSaving}
              onClick={() => void saveMemberFee()} type="button">{isSaving ? "ČUVANJE..." : "SAČUVAJ"}</button>
          </div>
        </section>
      </div>}
    </>
  );
}
