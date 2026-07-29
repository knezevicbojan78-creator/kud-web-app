"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import {
  UF_MEMBER_FORM,
  type UFMemberFormField,
  type UFMemberFormValues,
  type UFMemberGuardianField
} from "../../_components/UF_MEMBER_FORM";
import {
  getSupabaseClient,
  type Person,
  type RepertoireItem,
  type Section,
  type SectionAccompanist,
  type SectionRoleAssignment,
  type Society,
  type SocietyMember
} from "../../_lib/supabaseClient";
import type { ApplicationRole } from "../../_lib/roles";

type RoleName = "UR";

const REHEARSAL_DURATION_OPTIONS = Array.from(
  { length: 15 },
  (_, index) => 30 + index * 15
);

function formatRehearsalDuration(minutes: number) {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (!hours) return `${rest} min`;
  return rest ? `${hours} h ${rest} min` : `${hours} h`;
}

function formatRepertoireType(itemType: RepertoireItem["item_type"]) {
  return {
    CHOREOGRAPHY: "Koreografija",
    SONG: "Pesma",
    INSTRUMENTAL: "Instrumental",
    OTHER: "Ostalo"
  }[itemType];
}

type SearchSocietyMembersOptions = {
  excludeActiveSectionId?: string;
  excludeActiveRole?: RoleName;
};

type MemberCandidate = {
  societyMemberId: string;
  personId: string;
  name: string;
  email: string | null;
  phone: string | null;
};

type SectionRoleView = SectionRoleAssignment & {
  memberName: string;
  email: string | null;
  phone: string | null;
};

type SectionMemberView = {
  memberSectionId: string;
  societyMemberId: string;
  personId: string;
  name: string;
  email: string | null;
  phone: string | null;
  status: string;
  guardians: Array<{
    name: string;
    email: string | null;
    phone: string | null;
  }>;
};

type SectionSummary = Section & {
  access: {
    can_edit: boolean;
    can_manage_members: boolean;
    can_manage_roles: boolean;
    can_manage_repertoire: boolean;
    can_manage_accompanists: boolean;
  };
  roles: SectionRoleView[];
};

type AccompanistView = SectionAccompanist & {
  name: string;
  email: string | null;
  phone: string | null;
};

type AccompanistCandidate = {
  personId: string;
  name: string;
  email: string | null;
  phone: string | null;
};

type ConfirmationState =
  | { type: "member"; member: SectionMemberView }
  | { type: "section"; section: SectionSummary }
  | null;

function normalizeSearch(value: string) {
  return value.trim().toLowerCase();
}

function getPersonName(person: Pick<Person, "first_name" | "last_name">) {
  return `${person.first_name ?? ""} ${person.last_name ?? ""}`.trim();
}

function formatMemberCandidate(candidate: MemberCandidate) {
  return [candidate.name, candidate.email, candidate.phone].filter(Boolean).join(" \u2014 ");
}

function getCurrentDate() {
  return new Date().toISOString().slice(0, 10);
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error && "message" in error) {
    return String(error.message);
  }

  return "Akcija trenutno nije uspela. Proverite podatke i pokušajte ponovo.";
}

function canManageSection(role: ApplicationRole) {
  return role === "Predsednik";
}

function canManageMembers(role: ApplicationRole, selectedSection: SectionSummary | null) {
  if (role === "Predsednik") {
    return true;
  }

  return (
    role === "UR" &&
    Boolean(
      selectedSection?.roles.some(
        (sectionRole) =>
          sectionRole.role === "UR" && sectionRole.status === "ACTIVE"
      )
    )
  );
}

function createInitialMemberFormValues(): UFMemberFormValues {
  return {
    is_minor_member: false,
    first_name: "",
    last_name: "",
    gender: "",
    birth_date: "",
    address: "",
    city: "",
    postal_code: "",
    country: "Srbija",
    jmbg: "",
    passport_number: "",
    passport_expiry_date: "",
    parental_travel_consent: false,
    parental_travel_consent_valid_until: "",
    email: "",
    phone: "",
    status: "ACTIVE",
    start_date: "",
    membership_fee_required: true,
    membership_fee_amount: "0",
    guardian1: {
      first_name: "",
      last_name: "",
      email: "",
      phone: ""
    },
    guardian2: {
      first_name: "",
      last_name: "",
      email: "",
      phone: ""
    },
    showGuardian2: false,
    selectedFunctionIds: [],
    selectedSectionIds: []
  };
}

function getValueForInput(value: string | null) {
  return value ?? "";
}

export default function MojeSekcijePage() {
  const [role, setRole] = useState<ApplicationRole>("Predsednik");
  const [actorSocietyMemberId, setActorSocietyMemberId] = useState<string | null>(
    null
  );
  const [society, setSociety] = useState<Society | null>(null);
  const [workspaceAccess, setWorkspaceAccess] = useState({
    can_create: false,
    can_change_status: false,
    can_manage_roles: false
  });
  const [sections, setSections] = useState<SectionSummary[]>([]);
  const [showInactiveSections, setShowInactiveSections] = useState(false);
  const [selectedSectionId, setSelectedSectionId] = useState<string | null>(null);
  const [members, setMembers] = useState<SectionMemberView[]>([]);
  const [newSectionName, setNewSectionName] = useState("");
  const [newSectionDuration, setNewSectionDuration] = useState(120);
  const [isCreateSectionOpen, setIsCreateSectionOpen] = useState(false);
  const [activeDetailTab, setActiveDetailTab] = useState<"members" | "roles" | "repertoire" | "settings">("members");
  const [isRoleFormOpen, setIsRoleFormOpen] = useState(false);
  const [isMemberFormOpen, setIsMemberFormOpen] = useState(false);
  const [editedSectionName, setEditedSectionName] = useState("");
  const [editedSectionDuration, setEditedSectionDuration] = useState(120);
  const [isRenameOpen, setIsRenameOpen] = useState(false);
  const [memberSearch, setMemberSearch] = useState("");
  const [memberCandidates, setMemberCandidates] = useState<MemberCandidate[]>([]);
  const [selectedMemberId, setSelectedMemberId] = useState("");
  const [isMemberSearchLoading, setIsMemberSearchLoading] = useState(false);
  const [memberSearchHasRun, setMemberSearchHasRun] = useState(false);
  const [roleSearch, setRoleSearch] = useState("");
  const [roleCandidates, setRoleCandidates] = useState<MemberCandidate[]>([]);
  const [selectedRoleMemberId, setSelectedRoleMemberId] = useState("");
  const [selectedRoleName, setSelectedRoleName] = useState<RoleName>("UR");
  const [repertoireItems, setRepertoireItems] = useState<RepertoireItem[]>([]);
  const [accompanists, setAccompanists] = useState<AccompanistView[]>([]);
  const [isAccompanistFormOpen, setIsAccompanistFormOpen] = useState(false);
  const [accompanistSearch, setAccompanistSearch] = useState("");
  const [accompanistCandidates, setAccompanistCandidates] = useState<
    AccompanistCandidate[]
  >([]);
  const [selectedAccompanistPersonId, setSelectedAccompanistPersonId] =
    useState("");
  const [newAccompanist, setNewAccompanist] = useState({
    first_name: "",
    last_name: "",
    email: "",
    phone: ""
  });
  const [isRepertoireFormOpen, setIsRepertoireFormOpen] = useState(false);
  const [repertoireName, setRepertoireName] = useState("");
  const [repertoireType, setRepertoireType] =
    useState<RepertoireItem["item_type"]>("CHOREOGRAPHY");
  const [repertoireDuration, setRepertoireDuration] = useState("");
  const [repertoireDescription, setRepertoireDescription] = useState("");
  const [repertoireCostumeNote, setRepertoireCostumeNote] = useState("");
  const [isRoleSearchLoading, setIsRoleSearchLoading] = useState(false);
  const [roleSearchHasRun, setRoleSearchHasRun] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [confirmation, setConfirmation] = useState<ConfirmationState>(null);
  const [editingMemberId, setEditingMemberId] = useState<string | null>(null);
  const [editingPersonId, setEditingPersonId] = useState<string | null>(null);
  const [editingInitialSectionIds, setEditingInitialSectionIds] = useState<string[]>(
    []
  );
  const [memberFormValues, setMemberFormValues] = useState<UFMemberFormValues>(
    () => createInitialMemberFormValues()
  );

  const selectedSection = useMemo(
    () => sections.find((section) => section.id === selectedSectionId) ?? null,
    [sections, selectedSectionId]
  );
  const displayedSections = useMemo(
    () =>
      showInactiveSections
        ?sections
        : sections.filter((section) => section.status === "ACTIVE"),
    [sections, showInactiveSections]
  );
  const editableSectionOptions = useMemo(
    () => sections.filter((section) => section.status === "ACTIVE"),
    [sections]
  );
  const canCreateSection = workspaceAccess.can_create;
  const canEditSection = Boolean(selectedSection?.access.can_edit);
  const canChangeSectionStatus = workspaceAccess.can_change_status;
  const canManageRoles = Boolean(selectedSection?.access.can_manage_roles);
  const userCanManageMembers = Boolean(selectedSection?.access.can_manage_members);
  const userCanManageRepertoire = Boolean(selectedSection?.access.can_manage_repertoire);
  const userCanManageAccompanists = Boolean(
    selectedSection?.access.can_manage_accompanists
  );
  const selectedMemberCandidate = useMemo(
    () =>
      memberCandidates.find(
        (candidate) => candidate.societyMemberId === selectedMemberId
      ) ?? null,
    [memberCandidates, selectedMemberId]
  );

  const loadSectionDetail = useCallback(async (sectionId: string) => {
    const { data, error } = await getSupabaseClient().rpc(
      "auth_get_section_detail",
      { p_section_id: sectionId }
    );
    if (error || !data) {
      throw error ?? new Error("Podaci sekcije nisu dostupni.");
    }
    setMembers(data.members ?? []);
    setAccompanists(data.accompanists ?? []);
    setRepertoireItems(data.repertoire ?? []);
  }, []);

  const loadPageData = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();
      const { data: context, error: contextError } =
        await supabase.rpc("auth_get_application_context");
      if (contextError || !context) throw contextError ?? new Error("Korisnički kontekst nije dostupan.");
      const membership = context.memberships[0];
      if (!membership) throw new Error("Korisnik nema aktivno društvo.");
      const effectiveRole: ApplicationRole = membership.functions.includes("Predsednik")
        ? "Predsednik"
        : membership.functions.includes("UR")
          ? "UR"
          : "Član";
      setRole(effectiveRole);

      const { data: workspace, error: workspaceError } =
        await supabase.rpc("auth_get_sections_workspace", {
          p_society_id: membership.society_id
        });
      if (workspaceError || !workspace) throw workspaceError ?? new Error("Društvo nije dostupno.");

      const activeSociety = workspace.society;
      setActorSocietyMemberId(workspace.actor_society_member_id ?? null);
      setWorkspaceAccess(workspace.access);
      setSociety(activeSociety);

      if (!activeSociety) {
        setSections([]);
        setSelectedSectionId(null);
        setMembers([]);
        setErrorMessage("Nema aktivnog društva za prikaz sekcija.");
        return;
      }

      const visibleSections: SectionSummary[] = workspace.sections;

      setSections(visibleSections);

      const selectableSections = showInactiveSections
        ?visibleSections
        : visibleSections.filter((section) => section.status === "ACTIVE");
      const nextSelectedSectionId =
        selectableSections.find((section) => section.id === selectedSectionId)?.id ??
        selectableSections[0]?.id ??
        null;
      setSelectedSectionId(nextSelectedSectionId);
      setEditedSectionName(
        visibleSections.find((section) => section.id === nextSelectedSectionId)?.name ??
          ""
      );
      setEditedSectionDuration(
        visibleSections.find((section) => section.id === nextSelectedSectionId)
          ?.rehearsal_duration_minutes ?? 120
      );

      if (nextSelectedSectionId) {
        await loadSectionDetail(nextSelectedSectionId);
      } else {
        setMembers([]);
      }
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, [loadSectionDetail, selectedSectionId, showInactiveSections]);

  useEffect(() => {
    void loadPageData();
  }, [loadPageData]);

  useEffect(() => {
    setEditedSectionName(selectedSection?.name ?? "");
    setEditedSectionDuration(
      selectedSection?.rehearsal_duration_minutes ?? 120
    );
    setMemberSearch("");
    setMemberCandidates([]);
    setSelectedMemberId("");
    setMemberSearchHasRun(false);
    setRoleSearch("");
    setRoleCandidates([]);
    setSelectedRoleMemberId("");
    setRoleSearchHasRun(false);
    setAccompanistSearch("");
    setAccompanistCandidates([]);
    setSelectedAccompanistPersonId("");
    setIsAccompanistFormOpen(false);
    setEditingMemberId(null);
    setEditingPersonId(null);
  }, [selectedSection]);

  useEffect(() => {
    if (!selectedSectionId) {
      setRepertoireItems([]);
      return;
    }
    void loadSectionDetail(selectedSectionId).catch((error: unknown) =>
      setErrorMessage(getErrorMessage(error))
    );
  }, [loadSectionDetail, selectedSectionId]);

  useEffect(() => {
    const query = memberSearch.trim();

    setSelectedMemberId("");

    if (!userCanManageMembers || query.length < 2) {
      setMemberCandidates([]);
      setMemberSearchHasRun(false);
      setIsMemberSearchLoading(false);
      return;
    }

    let isActive = true;
    setIsMemberSearchLoading(true);

    const timeoutId = window.setTimeout(() => {
      void searchSocietyMembers(query, {
        excludeActiveSectionId: selectedSection?.id
      })
        .then((results) => {
          if (!isActive) {
            return;
          }

          setMemberCandidates(results);
          setMemberSearchHasRun(true);
        })
        .catch((error) => {
          if (!isActive) {
            return;
          }

          setErrorMessage(getErrorMessage(error));
          setMemberCandidates([]);
          setMemberSearchHasRun(true);
        })
        .finally(() => {
          if (isActive) {
            setIsMemberSearchLoading(false);
          }
        });
    }, 300);

    return () => {
      isActive = false;
      window.clearTimeout(timeoutId);
    };
  }, [memberSearch, selectedSection?.id, society, userCanManageMembers]);

  useEffect(() => {
    const query = roleSearch.trim();
    setSelectedRoleMemberId("");

    if (!canManageRoles || !selectedSection || query.length < 2) {
      setRoleCandidates([]);
      setRoleSearchHasRun(false);
      setIsRoleSearchLoading(false);
      return;
    }

    let isActive = true;
    setIsRoleSearchLoading(true);

    const timeoutId = window.setTimeout(() => {
      void searchSocietyMembers(query, {
        excludeActiveRole: selectedRoleName
      })
        .then((results) => {
          if (!isActive) {
            return;
          }

          setRoleCandidates(results);
          setRoleSearchHasRun(true);
        })
        .catch((error) => {
          if (!isActive) {
            return;
          }

          setErrorMessage(getErrorMessage(error));
          setRoleCandidates([]);
          setRoleSearchHasRun(true);
        })
        .finally(() => {
          if (isActive) {
            setIsRoleSearchLoading(false);
          }
        });
    }, 300);

    return () => {
      isActive = false;
      window.clearTimeout(timeoutId);
    };
  }, [canManageRoles, roleSearch, selectedRoleName, selectedSection, society]);

  useEffect(() => {
    const query = accompanistSearch.trim();
    setSelectedAccompanistPersonId("");

    if (
      !userCanManageAccompanists ||
      !society ||
      !selectedSection ||
      query.length < 2
    ) {
      setAccompanistCandidates([]);
      return;
    }

    let active = true;
    const timeoutId = window.setTimeout(() => {
      void (async () => {
        try {
          const { data, error } = await getSupabaseClient().rpc(
            "auth_search_accompanist_people",
            {
              p_society_id: society.id,
              p_section_id: selectedSection.id,
              p_query: query
            }
          );
          if (!active) return;
          if (error) throw error;
          setAccompanistCandidates((data ?? []).slice(0, 10));
        } catch (error) {
          if (!active) return;
          setErrorMessage(getErrorMessage(error));
          setAccompanistCandidates([]);
        }
      })();
    }, 300);

    return () => {
      active = false;
      window.clearTimeout(timeoutId);
    };
  }, [
    accompanistSearch,
    selectedSection,
    society,
    userCanManageAccompanists
  ]);

  async function searchSocietyMembers(
    query: string,
    options: SearchSocietyMembersOptions = {}
  ) {
    if (!society || query.trim().length < 2) {
      return [];
    }

    const sectionId =
      options.excludeActiveSectionId ?? selectedSection?.id ?? null;
    const { data, error } = await getSupabaseClient().rpc(
      "auth_search_society_members",
      {
        p_society_id: society.id,
        p_query: query.trim(),
        p_section_id: sectionId,
        p_exclude_active_section: Boolean(options.excludeActiveSectionId),
        p_exclude_active_role: options.excludeActiveRole ?? null
      }
    );
    if (error) throw error;
    return (data ?? []).slice(0, 12);
  }

  async function handleCreateSection() {
    if (!society || !canCreateSection || !newSectionName.trim()) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "CREATE_SECTION",
        p_payload: {
          society_id: society.id,
          name: newSectionName.trim(),
          rehearsal_duration_minutes: newSectionDuration
        }
      });

      if (error) {
        throw error;
      }

      setNewSectionName("");
      setNewSectionDuration(120);
      setMessage("Sekcija je kreirana.");
      await loadPageData();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleCreateRepertoireItem() {
    if (!society || !selectedSection || !userCanManageRepertoire || !repertoireName.trim()) return;
    setIsSaving(true);
    setErrorMessage("");
    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "CREATE_REPERTOIRE",
        p_payload: {
          society_id: society.id,
          section_id: selectedSection.id,
          name: repertoireName.trim(),
          item_type: repertoireType,
          duration_minutes: repertoireDuration ? Number(repertoireDuration) : null,
          description: repertoireDescription.trim() || null,
          costume_note: repertoireCostumeNote.trim() || null
        }
      });
      if (error) throw error;
      setRepertoireName("");
      setRepertoireDuration("");
      setRepertoireDescription("");
      setRepertoireCostumeNote("");
      setIsRepertoireFormOpen(false);
      await loadSectionDetail(selectedSection.id);
      setMessage("Numera je dodata u repertoar sekcije.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleToggleRepertoireStatus(item: RepertoireItem) {
    if (!userCanManageRepertoire || !selectedSection) return;
    setIsSaving(true);
    try {
      const nextStatus = item.status === "ACTIVE" ? "INACTIVE" : "ACTIVE";
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_REPERTOIRE_STATUS",
        p_payload: {
          society_id: selectedSection.society_id,
          section_id: selectedSection.id,
          repertoire_item_id: item.id,
          status: nextStatus
        }
      });
      if (error) throw error;
      await loadSectionDetail(selectedSection.id);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleToggleRepertoirePermission(assignment: SectionRoleAssignment) {
    if (!canManageRoles) return;
    setIsSaving(true);
    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_REPERTOIRE_PERMISSION",
        p_payload: {
          society_id: assignment.society_id,
          section_id: assignment.section_id,
          assignment_id: assignment.id,
          enabled: !assignment.can_manage_repertoire
        }
      });
      if (error) throw error;
      await loadPageData();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleUpdateSectionName() {
    if (!selectedSection || !canEditSection || !editedSectionName.trim()) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const nextName = editedSectionName.trim();
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "UPDATE_SECTION",
        p_payload: {
          society_id: selectedSection.society_id,
          section_id: selectedSection.id,
          name: nextName,
          rehearsal_duration_minutes: editedSectionDuration
        }
      });

      if (error) {
        throw error;
      }

      setMessage("");
      await loadPageData();

      setMessage("Podaci sekcije su sačuvani.");
    } catch (error) {
      setMessage("");
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleToggleSectionStatus() {
    if (!selectedSection || !canChangeSectionStatus) {
      return;
    }

    if (selectedSection.status === "ACTIVE") {
      setConfirmation({ type: "section", section: selectedSection });
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_SECTION_STATUS",
        p_payload: {
          society_id: selectedSection.society_id,
          section_id: selectedSection.id,
          status: "ACTIVE"
        }
      });

      if (error) {
        throw error;
      }

      setMessage("Sekcija je aktivirana. Clanstva i uloge nisu automatski reaktivirani.");
      await loadPageData();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function confirmDeactivateSection(section: SectionSummary) {
    if (!society || !canChangeSectionStatus) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");
    setConfirmation(null);

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_SECTION_STATUS",
        p_payload: {
          society_id: society.id,
          section_id: section.id,
          status: "INACTIVE"
        }
      });
      if (error) throw error;

      setConfirmation(null);
      await loadPageData();
      setMessage("Sekcija je deaktivirana. Aktivna clanstva i uloge u sekciji su deaktivirani.");
    } catch (error) {
      setMessage("");
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleAssignSectionRole() {
    if (!society || !selectedSection || !canManageRoles || !selectedRoleMemberId) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "ASSIGN_ROLE",
        p_payload: {
          society_id: society.id,
          section_id: selectedSection.id,
          society_member_id: selectedRoleMemberId,
          role: selectedRoleName
        }
      });
      if (error) throw error;

      await loadPageData();
      setMessage("Umetnički rukovodilac je dodeljen sekciji.");
    } catch (error) {
      setMessage("");
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDeactivateRole(roleId: string) {
    if (!canManageRoles) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const assignment = selectedSection?.roles.find((item) => item.id === roleId);
      if (!selectedSection || !assignment) return;
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "DEACTIVATE_ROLE",
        p_payload: {
          society_id: selectedSection.society_id,
          section_id: selectedSection.id,
          assignment_id: roleId
        }
      });

      if (error) {
        throw error;
      }

      setMessage("Sekcijska uloga je uklonjena.");
      await loadPageData();
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function manageAccompanist(
    action: "ASSIGN" | "CREATE_AND_ASSIGN" | "SET_ATTENDANCE" | "DEACTIVATE",
    payload: Record<string, string | boolean | null>
  ) {
    if (!society || !selectedSection || !userCanManageAccompanists) return;
    setIsSaving(true);
    setMessage("");
    setErrorMessage("");
    try {
      const { error } = await getSupabaseClient().rpc(
        "auth_manage_section_accompanist",
        {
          p_action: action,
          p_payload: {
            society_id: society.id,
            section_id: selectedSection.id,
            ...payload
          }
        }
      );
      if (error) throw error;
      await loadSectionDetail(selectedSection.id);
      setIsAccompanistFormOpen(false);
      setAccompanistSearch("");
      setAccompanistCandidates([]);
      setSelectedAccompanistPersonId("");
      setNewAccompanist({
        first_name: "",
        last_name: "",
        email: "",
        phone: ""
      });
      setMessage("Podešavanje korepetitora je sačuvano.");
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleAddMemberToSection() {
    if (!society || !selectedSection || !userCanManageMembers || !selectedMemberId) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_MEMBER_STATUS",
        p_payload: {
          society_id: society.id,
          section_id: selectedSection.id,
          society_member_id: selectedMemberId,
          status: "ACTIVE"
        }
      });
      if (error) throw error;
      setMessage("\u010clan je dodat ili reaktiviran u sekciji.");

      setMemberSearch("");
      setMemberCandidates([]);
      setSelectedMemberId("");
      setMemberSearchHasRun(false);
      await loadSectionDetail(selectedSection.id);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleToggleMemberStatus(memberSection: SectionMemberView) {
    if (!society || !selectedSection || !userCanManageMembers) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { error } = await getSupabaseClient().rpc("auth_manage_section", {
        p_action: "SET_MEMBER_STATUS",
        p_payload: {
          society_id: society.id,
          section_id: selectedSection.id,
          society_member_id: memberSection.societyMemberId,
          status: "INACTIVE"
        }
      });

      if (error) {
        throw error;
      }

      setConfirmation(null);
      setMessage("\u010clanstvo u sekciji je deaktivirano.");
      await loadSectionDetail(selectedSection.id);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleOpenMemberEdit(member: SectionMemberView) {
    if (!society || !userCanManageMembers) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const { data: detail, error } = await getSupabaseClient().rpc(
        "auth_get_member_detail",
        { p_society_member_id: member.societyMemberId }
      );
      if (error || !detail) {
        throw error ?? new Error("Podaci člana nisu dostupni.");
      }
      const memberRow = detail.member;
      const personRow = detail.person;

      setMemberFormValues({
        ...createInitialMemberFormValues(),
        first_name: personRow.first_name,
        last_name: personRow.last_name,
        gender: personRow.gender === "Muško" || personRow.gender === "Žensko" ?personRow.gender : "",
        birth_date: getValueForInput(personRow.birth_date),
        address: getValueForInput(personRow.address),
        city: getValueForInput(personRow.city),
        postal_code: getValueForInput(personRow.postal_code),
        country: getValueForInput(personRow.country) || "Srbija",
        jmbg: getValueForInput(personRow.jmbg),
        passport_number: getValueForInput(personRow.passport_number),
        passport_expiry_date: getValueForInput(personRow.passport_expiry_date),
        parental_travel_consent: personRow.parental_travel_consent,
        parental_travel_consent_valid_until: getValueForInput(personRow.parental_travel_consent_valid_until),
        email: getValueForInput(personRow.email),
        phone: getValueForInput(personRow.phone),
        status: memberRow.status === "INACTIVE" ?"INACTIVE" : "ACTIVE",
        start_date: getValueForInput(memberRow.start_date),
        membership_fee_required: memberRow.membership_fee_required,
        membership_fee_amount:
          memberRow.membership_fee_amount === null
            ?"0"
            : String(memberRow.membership_fee_amount),
        selectedSectionIds: detail.section_ids
      });
      setEditingMemberId(member.societyMemberId);
      setEditingPersonId(member.personId);
      setEditingInitialSectionIds(detail.section_ids);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  function handleMemberFormFieldChange(
    field: UFMemberFormField | "showGuardian2" | "is_minor_member",
    value: string | boolean
  ) {
    setMemberFormValues((currentValues) => ({
      ...currentValues,
      [field]: value
    }));
  }

  function handleMemberFormGuardianFieldChange(
    guardian: "guardian1" | "guardian2",
    field: UFMemberGuardianField,
    value: string
  ) {
    setMemberFormValues((currentValues) => ({
      ...currentValues,
      [guardian]: {
        ...currentValues[guardian],
        [field]: value
      }
    }));
  }

  function handleMemberFormSectionToggle(sectionId: string) {
    setMemberFormValues((currentValues) => {
      const selectedSectionIds = currentValues.selectedSectionIds.includes(sectionId)
        ?currentValues.selectedSectionIds.filter((id) => id !== sectionId)
        : [...currentValues.selectedSectionIds, sectionId];

      return {
        ...currentValues,
        selectedSectionIds
      };
    });
  }

  async function handleSubmitMemberEdit() {
    if (!society || !editingMemberId || !selectedSection || !userCanManageMembers) {
      return;
    }

    setIsSaving(true);
    setMessage("");
    setErrorMessage("");

    try {
      const supabase = getSupabaseClient();
      const selectedSectionIds = new Set(memberFormValues.selectedSectionIds);
      const editableSectionIds = new Set(editableSectionOptions.map((section) => section.id));
      const initialSectionIds = new Set(editingInitialSectionIds);
      for (const sectionId of editableSectionIds) {
        const wasActive = initialSectionIds.has(sectionId);
        const shouldBeActive = selectedSectionIds.has(sectionId);

        if (shouldBeActive !== wasActive) {
          const { error } = await supabase.rpc("auth_manage_section", {
            p_action: "SET_MEMBER_STATUS",
            p_payload: {
              society_id: society.id,
              section_id: sectionId,
              society_member_id: editingMemberId,
              status: shouldBeActive ? "ACTIVE" : "INACTIVE"
            }
          });
          if (error) throw error;
        }
      }

      setEditingMemberId(null);
      setEditingPersonId(null);
      setEditingInitialSectionIds([]);
      setMessage("Sekcije clana su sacuvane.");
      await loadPageData();
      await loadSectionDetail(selectedSection.id);
    } catch (error) {
      setErrorMessage(getErrorMessage(error));
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <>
      <section className="page-heading">
        <div className="sections-page-title">
          <div>
            <h1>Moje sekcije</h1>
          </div>
          <div className="header-actions">
            <button className="button button-secondary sections-refresh" disabled={isLoading || isSaving} type="button" onClick={() => void loadPageData()}>
              ↻ Osveži
            </button>
            {canCreateSection && (
              <button className="button button-primary" type="button" onClick={() => setIsCreateSectionOpen(true)}>
                + Nova sekcija
              </button>
            )}
          </div>
        </div>
      </section>

      {message && (
        <section className="card dashboard-card" role="status" style={{ marginBottom: 22 }}>
          <p>{message}</p>
        </section>
      )}

      {errorMessage && (
        <section className="card dashboard-card" role="alert" style={{ marginBottom: 22 }}>
          <p>{errorMessage}</p>
        </section>
      )}

      {canCreateSection && isCreateSectionOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <section className="card modal-card sections-modal">
            <div className="form-stack">
              <div>
                <p className="eyebrow">Nova sekcija</p>
                <h2>Kreiraj sekciju</h2>
              </div>
            <label className="form-field">
              <span>Naziv sekcije</span>
              <input
                className="input"
                value={newSectionName}
                onChange={(event) => setNewSectionName(event.target.value)}
              />
            </label>
            <label className="form-field">
              <span>Uobičajeno trajanje probe</span>
              <select
                className="input"
                value={newSectionDuration}
                onChange={(event) => setNewSectionDuration(Number(event.target.value))}
              >
                {REHEARSAL_DURATION_OPTIONS.map((minutes) => (
                  <option key={minutes} value={minutes}>
                    {formatRehearsalDuration(minutes)}
                  </option>
                ))}
              </select>
              <small>Automatsko zatvaranje je 30 minuta nakon planiranog kraja.</small>
            </label>
              <div className="sections-modal-actions">
                <button className="button button-secondary" type="button" onClick={() => setIsCreateSectionOpen(false)}>Otkaži</button>
                <button className="button button-primary" disabled={isSaving || !newSectionName.trim()} type="button" onClick={() => { setIsCreateSectionOpen(false); void handleCreateSection(); }}>Kreiraj</button>
              </div>
            </div>
          </section>
        </div>
      )}

      <section className="sections-workspace">
        <section className="card sections-sidebar">
          <div className="header-actions">
            <div className="page-heading" style={{ marginBottom: 0 }}>
              <p className="eyebrow">Sekcije</p>
            </div>
            <label className="sections-inactive-toggle">
              <input
                checked={showInactiveSections}
                type="checkbox"
                onChange={(event) => setShowInactiveSections(event.target.checked)}
              />
              <span>Prikaži neaktivne sekcije</span>
            </label>
          </div>

          {isLoading && <p>Učitavanje sekcija...</p>}

          {!isLoading && displayedSections.length === 0 && (
            <section className="card dashboard-card">
              <p>Nema sekcija za prikaz.</p>
            </section>
          )}

          <div className="sections-list">
            {displayedSections.map((section) => (
              <button
                className={`section-list-item ${selectedSectionId === section.id ? "active" : ""}`}
                key={section.id}
                type="button"
                onClick={() => {
                  setSelectedSectionId(section.id);
                  setActiveDetailTab("members");
                  setIsMemberFormOpen(false);
                  setIsRoleFormOpen(false);
                  void loadSectionDetail(section.id);
                }}
              >
                <span className={`section-status-dot ${section.status === "ACTIVE" ? "active" : "inactive"}`} />
                <span className="section-list-copy">
                  <strong>{section.name}</strong>
                  <small>
                    Umetnički rukovodilac: {section.roles.some((item) => item.role === "UR" && item.status === "ACTIVE") ? "dodeljen" : "nije dodeljen"} · {section.roles.some((item) => item.role === "KOREPETITOR" && item.status === "ACTIVE") ? "korepetitor" : "bez korepetitora"}
                  </small>
                  <small>Proba {formatRehearsalDuration(section.rehearsal_duration_minutes)}</small>
                </span>
                <span className="section-member-count">{selectedSectionId === section.id ? members.length : ""}</span>
              </button>
            ))}
          </div>
        </section>

        {selectedSection && (
          <section className="card sections-detail">
            <section className="sections-detail-header">
              <div className="header-actions">
                <div className="page-heading" style={{ marginBottom: 0 }}>
                  <h1 style={{ fontSize: "1.35rem" }}>{selectedSection.name}</h1>
                  <p>{members.length} aktivnih članova</p>
                </div>
                <div className="header-actions">
                  {canEditSection && (
                      <button
                        className="button button-secondary"
                        disabled={isSaving}
                        type="button"
                        onClick={() => {
                          setActiveDetailTab("settings");
                          setEditedSectionName(selectedSection.name);
                          setEditedSectionDuration(selectedSection.rehearsal_duration_minutes);
                          setIsRenameOpen(true);
                        }}
                      >
                        IZMENI
                      </button>
                  )}
                </div>
              </div>

              {isRenameOpen && canEditSection && (
                <div className="form-stack" style={{ marginTop: 16 }}>
                  <label className="form-field">
                    <span>Naziv sekcije</span>
                    <input
                      autoFocus
                      className="input"
                      value={editedSectionName}
                      onChange={(event) => setEditedSectionName(event.target.value)}
                    />
                  </label>
                  <label className="form-field">
                    <span>Uobičajeno trajanje probe</span>
                    <select
                      className="input member-section-search"
                      value={editedSectionDuration}
                      onChange={(event) => setEditedSectionDuration(Number(event.target.value))}
                    >
                      {REHEARSAL_DURATION_OPTIONS.map((minutes) => (
                        <option key={minutes} value={minutes}>
                          {formatRehearsalDuration(minutes)}
                        </option>
                      ))}
                    </select>
                    <small>Automatsko zatvaranje je 30 minuta nakon planiranog kraja.</small>
                  </label>
                  <div className="header-actions">
                    <button
                      className="button button-secondary"
                      disabled={isSaving}
                      type="button"
                      onClick={() => {
                        setEditedSectionName(selectedSection.name);
                        setEditedSectionDuration(selectedSection.rehearsal_duration_minutes);
                        setIsRenameOpen(false);
                      }}
                    >
                      OTKAŽI
                    </button>
                    <button
                      className="button button-primary"
                      disabled={isSaving || !editedSectionName.trim()}
                      type="button"
                      onClick={() => {
                        setIsRenameOpen(false);
                        void handleUpdateSectionName();
                      }}
                    >
                      SAČUVAJ
                    </button>
                  </div>
                </div>
              )}
            </section>

            <nav className="section-tabs" aria-label="Detalji sekcije">
              <button className={activeDetailTab === "members" ? "active" : ""} type="button" onClick={() => setActiveDetailTab("members")}>Članovi</button>
              <button className={activeDetailTab === "roles" ? "active" : ""} type="button" onClick={() => setActiveDetailTab("roles")}>Uloge</button>
              <button className={activeDetailTab === "repertoire" ? "active" : ""} type="button" onClick={() => setActiveDetailTab("repertoire")}>Repertoar</button>
              <button className={activeDetailTab === "settings" ? "active" : ""} type="button" onClick={() => setActiveDetailTab("settings")}>Podešavanja</button>
            </nav>

            {activeDetailTab === "roles" && <section className="section-tab-panel">
              <div className="page-heading" style={{ marginBottom: 12 }}>
                <p className="eyebrow">Uloge u sekciji</p>
              </div>

              <div className="form-stack">
                <div>
                  <strong>Umetnički rukovodilac</strong>
                  {selectedSection.roles.filter((sectionRole) => sectionRole.role === "UR" && sectionRole.status === "ACTIVE").length === 0 && (
                    <p>Nema dodeljenog umetničkog rukovodioca.</p>
                  )}
                  {selectedSection.roles
                    .filter((sectionRole) => sectionRole.role === "UR" && sectionRole.status === "ACTIVE")
                    .map((sectionRole) => (
                      <div className="header-actions" key={sectionRole.id}>
                        <span>
                          {sectionRole.memberName} · {sectionRole.email ?? "Bez email-a"} ·{" "}
                          {sectionRole.phone ?? "Bez telefona"}
                        </span>
                        {canManageRoles && (
                          <div className="header-actions">
                            <button
                              className="button button-secondary"
                              disabled={isSaving}
                              type="button"
                              onClick={() => void handleToggleRepertoirePermission(sectionRole)}
                            >
                              {sectionRole.can_manage_repertoire
                                ? "UKINI REPERTOAR"
                                : "DOZVOLI REPERTOAR"}
                            </button>
                            <button
                              className="button button-secondary"
                              disabled={isSaving}
                              type="button"
                              onClick={() => void handleDeactivateRole(sectionRole.id)}
                            >
                              UKLONI
                            </button>
                          </div>
                        )}
                      </div>
                    ))}
                </div>

                <div>
                  <div className="section-panel-toolbar">
                    <strong>Korepetitori</strong>
                    {userCanManageAccompanists && !isAccompanistFormOpen && (
                      <button
                        className="button button-primary compact-action"
                        type="button"
                        onClick={() => setIsAccompanistFormOpen(true)}
                      >
                        + Dodaj korepetitora
                      </button>
                    )}
                  </div>
                  {accompanists.length === 0 && <p>Nema dodeljenih korepetitora.</p>}
                  <div className="accompanist-settings-list">
                    {accompanists.map((accompanist) => (
                      <article className="accompanist-settings-row" key={accompanist.id}>
                        <div>
                          <strong>{accompanist.name}</strong>
                          <span>
                            {accompanist.email ?? "Bez email-a"} ·{" "}
                            {accompanist.phone ?? "Bez telefona"}
                          </span>
                        </div>
                        {userCanManageAccompanists && (
                          <div className="header-actions">
                            <button
                              className={`permission-toggle ${
                                accompanist.attendance_enabled ? "allowed" : "denied"
                              }`}
                              disabled={isSaving}
                              type="button"
                              onClick={() =>
                                void manageAccompanist("SET_ATTENDANCE", {
                                  assignment_id: accompanist.id,
                                  attendance_enabled:
                                    !accompanist.attendance_enabled
                                })
                              }
                            >
                              {accompanist.attendance_enabled
                                ? "Prisustvo se beleži"
                                : "Prisustvo se ne beleži"}
                            </button>
                            <button
                              className="button button-secondary"
                              disabled={isSaving}
                              type="button"
                              onClick={() =>
                                void manageAccompanist("DEACTIVATE", {
                                  assignment_id: accompanist.id
                                })
                              }
                            >
                              UKLONI
                            </button>
                          </div>
                        )}
                      </article>
                    ))}
                  </div>

                  {userCanManageAccompanists && isAccompanistFormOpen && (
                    <div className="card dashboard-card compact-accompanist-form">
                      <label className="form-field">
                        <span>Pronađi postojeću osobu</span>
                        <input
                          autoFocus
                          className="input"
                          placeholder="Ime, email ili telefon"
                          value={accompanistSearch}
                          onChange={(event) => setAccompanistSearch(event.target.value)}
                        />
                      </label>
                      {accompanistCandidates.length > 0 && (
                        <div className="accompanist-candidates">
                          {accompanistCandidates.map((candidate) => (
                            <button
                              className={
                                selectedAccompanistPersonId === candidate.personId
                                  ? "selected"
                                  : ""
                              }
                              key={candidate.personId}
                              type="button"
                              onClick={() =>
                                setSelectedAccompanistPersonId(candidate.personId)
                              }
                            >
                              <strong>{candidate.name}</strong>
                              <span>{candidate.email ?? candidate.phone ?? "Bez kontakta"}</span>
                            </button>
                          ))}
                        </div>
                      )}
                      {selectedAccompanistPersonId && (
                        <button
                          className="button button-primary"
                          disabled={isSaving}
                          type="button"
                          onClick={() =>
                            void manageAccompanist("ASSIGN", {
                              person_id: selectedAccompanistPersonId,
                              attendance_enabled: true
                            })
                          }
                        >
                          DODAJ IZABRANU OSOBU
                        </button>
                      )}
                      <div className="compact-divider">ili unesite novu osobu</div>
                      <div className="form-grid">
                        <label className="form-field">
                          <span>Ime *</span>
                          <input
                            className="input"
                            value={newAccompanist.first_name}
                            onChange={(event) =>
                              setNewAccompanist((current) => ({
                                ...current,
                                first_name: event.target.value
                              }))
                            }
                          />
                        </label>
                        <label className="form-field">
                          <span>Prezime *</span>
                          <input
                            className="input"
                            value={newAccompanist.last_name}
                            onChange={(event) =>
                              setNewAccompanist((current) => ({
                                ...current,
                                last_name: event.target.value
                              }))
                            }
                          />
                        </label>
                        <label className="form-field">
                          <span>Email</span>
                          <input
                            className="input"
                            type="email"
                            value={newAccompanist.email}
                            onChange={(event) =>
                              setNewAccompanist((current) => ({
                                ...current,
                                email: event.target.value
                              }))
                            }
                          />
                        </label>
                        <label className="form-field">
                          <span>Telefon</span>
                          <input
                            className="input"
                            value={newAccompanist.phone}
                            onChange={(event) =>
                              setNewAccompanist((current) => ({
                                ...current,
                                phone: event.target.value
                              }))
                            }
                          />
                        </label>
                      </div>
                      <div className="header-actions">
                        <button
                          className="button button-secondary"
                          type="button"
                          onClick={() => setIsAccompanistFormOpen(false)}
                        >
                          OTKAŽI
                        </button>
                        <button
                          className="button button-primary"
                          disabled={
                            isSaving ||
                            !newAccompanist.first_name.trim() ||
                            !newAccompanist.last_name.trim()
                          }
                          type="button"
                          onClick={() =>
                            void manageAccompanist("CREATE_AND_ASSIGN", {
                              ...newAccompanist,
                              attendance_enabled: true
                            })
                          }
                        >
                          SAČUVAJ NOVOG KOREPETITORA
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {canManageRoles && !isRoleFormOpen && (
                <button className="button button-primary compact-action" type="button" onClick={() => setIsRoleFormOpen(true)}>
                  + Dodeli ulogu
                </button>
              )}

              {canManageRoles && isRoleFormOpen && (
                <div className="form-stack" style={{ marginTop: 18 }}>
                  <label className="form-field">
                    <span>Pretraga člana za ulogu</span>
                    <input
                      autoFocus
                      className="input"
                      value={roleSearch}
                      onChange={(event) => setRoleSearch(event.target.value)}
                    />
                  </label>
                  <div className="header-actions">
                    <select
                      className="input"
                      value={selectedRoleName}
                      onChange={(event) => setSelectedRoleName(event.target.value as RoleName)}
                    >
                      <option value="UR">Umetnički rukovodilac</option>
                    </select>
                  </div>
                  {roleCandidates.length > 0 && (
                    <div className="form-stack">
                      {roleCandidates.map((candidate) => {
                        const isSelected = candidate.societyMemberId === selectedRoleMemberId;

                        return (
                          <button
                            className="card dashboard-card"
                            key={candidate.societyMemberId}
                            style={{
                              borderColor: isSelected
                                ? "var(--color-text)"
                                : undefined,
                              cursor: "pointer",
                              textAlign: "left",
                              width: "100%"
                            }}
                            type="button"
                            onClick={() => setSelectedRoleMemberId(candidate.societyMemberId)}
                          >
                            <span>{formatMemberCandidate(candidate)}</span>
                          </button>
                        );
                      })}
                    </div>
                  )}
                  {roleSearchHasRun &&
                    !isRoleSearchLoading &&
                    roleSearch.trim().length >= 2 &&
                    roleCandidates.length === 0 && <p>Nema pronađenih članova za ovu ulogu.</p>}
                  <button
                    className="button button-primary"
                    disabled={isSaving || !selectedRoleMemberId}
                    type="button"
                    onClick={() => void handleAssignSectionRole()}
                  >
                    DODELI ULOGU
                  </button>
                  <button className="button button-secondary" type="button" onClick={() => setIsRoleFormOpen(false)}>Otkaži</button>
                </div>
              )}
            </section>}

            {activeDetailTab === "members" && <section className="section-tab-panel">
              {userCanManageMembers && !isMemberFormOpen && (
                <div className="section-panel-toolbar section-members-action">
                  <button className="button button-primary compact-action" type="button" onClick={() => setIsMemberFormOpen(true)}>+ Dodaj člana</button>
                </div>
              )}

              {userCanManageMembers && isMemberFormOpen && (
                <div className="form-stack" style={{ marginTop: 16 }}>
                  <label className="form-field">
                    <input
                      aria-label="Pretraga člana društva"
                      autoFocus
                      className="input"
                      placeholder="Pretražite po imenu, prezimenu, telefonu ili email-u"
                      value={memberSearch}
                      onChange={(event) => setMemberSearch(event.target.value)}
                    />
                  </label>
                  {memberSearch.trim().length >= 2 && memberCandidates.length > 0 && (
                    <div className="form-stack">
                      {memberCandidates.map((candidate) => {
                        const isSelected = candidate.societyMemberId === selectedMemberId;

                        return (
                          <button
                            className="card dashboard-card"
                            key={candidate.societyMemberId}
                            style={{
                              borderColor: isSelected
                                ? "var(--color-text)"
                                : undefined,
                              cursor: "pointer",
                              textAlign: "left",
                              width: "100%"
                            }}
                            type="button"
                            onClick={() => setSelectedMemberId(candidate.societyMemberId)}
                          >
                            <span>{formatMemberCandidate(candidate)}</span>
                          </button>
                        );
                      })}
                    </div>
                  )}

                  {memberSearchHasRun &&
                    !isMemberSearchLoading &&
                    memberSearch.trim().length >= 2 &&
                    memberCandidates.length === 0 && <p>Nema pronađenih članova.</p>}

                  {selectedMemberCandidate && (
                    <section className="card dashboard-card">
                      <p>Izabrani član</p>
                      <span>{formatMemberCandidate(selectedMemberCandidate)}</span>
                    </section>
                  )}

                  <button
                    className="button button-primary"
                    disabled={isSaving || !selectedMemberId}
                    type="button"
                    onClick={() => void handleAddMemberToSection()}
                  >
                    DODAJ U SEKCIJU
                  </button>
                  <button className="button button-secondary" type="button" onClick={() => setIsMemberFormOpen(false)}>Otkaži</button>
                </div>
              )}

              <div className="section-member-list">
                {members.length === 0 && <p>Nema aktivnih članova u ovoj sekciji.</p>}
                {members.map((member) => (
                  <section
                    className="section-member-row"
                    key={member.memberSectionId}
                    style={{ cursor: userCanManageMembers ?"pointer" : undefined }}
                    onClick={() => void handleOpenMemberEdit(member)}
                  >
                    <div className="header-actions">
                      <div>
                        <p>{member.name}</p>
                        <span>
                          {member.email ?? "Bez email-a"} · {member.phone ?? "Bez telefona"}
                        </span>
                      </div>
                      {userCanManageMembers && (
                        <button
                          className="button button-secondary"
                          disabled={isSaving}
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setConfirmation({ type: "member", member });
                          }}
                        >
                          UKLONI
                        </button>
                      )}
                    </div>

                      {member.guardians.length > 0 && <small>Kontakt staratelja dostupan u detalju člana</small>}
                  </section>
                ))}
              </div>
            </section>}

            {activeDetailTab === "repertoire" && (
              <section className="section-tab-panel">
                {userCanManageRepertoire && !isRepertoireFormOpen && (
                  <div className="section-panel-toolbar section-members-action">
                    <button
                      className="button button-primary compact-action"
                      type="button"
                      onClick={() => setIsRepertoireFormOpen(true)}
                    >
                      + Dodaj numeru
                    </button>
                  </div>
                )}

                {role === "UR" && !userCanManageRepertoire && (
                  <p className="attendance-closed-note">
                    Repertoar možete pregledati. Predsednik daje pravo za kreiranje i izmene.
                  </p>
                )}

                {userCanManageRepertoire && isRepertoireFormOpen && (
                  <div className="card dashboard-card form-stack">
                    <label className="form-field">
                      <span>Naziv numere *</span>
                      <input className="input" value={repertoireName} onChange={(event) => setRepertoireName(event.target.value)} />
                    </label>
                    <div className="form-grid">
                      <label className="form-field">
                        <span>Tip</span>
                        <select className="input" value={repertoireType} onChange={(event) => setRepertoireType(event.target.value as RepertoireItem["item_type"])}>
                          <option value="CHOREOGRAPHY">Igračka koreografija</option>
                          <option value="SONG">Pesma</option>
                          <option value="INSTRUMENTAL">Instrumental</option>
                          <option value="OTHER">Ostalo</option>
                        </select>
                      </label>
                      <label className="form-field">
                        <span>Trajanje u minutima</span>
                        <input className="input" min="1" type="number" value={repertoireDuration} onChange={(event) => setRepertoireDuration(event.target.value)} />
                      </label>
                    </div>
                    <label className="form-field">
                      <span>Opis</span>
                      <textarea className="input" rows={3} value={repertoireDescription} onChange={(event) => setRepertoireDescription(event.target.value)} />
                    </label>
                    <label className="form-field">
                      <span>Napomena za kostim</span>
                      <textarea className="input" rows={2} value={repertoireCostumeNote} onChange={(event) => setRepertoireCostumeNote(event.target.value)} />
                    </label>
                    <div className="header-actions">
                      <button className="button button-secondary" type="button" onClick={() => setIsRepertoireFormOpen(false)}>OTKAŽI</button>
                      <button className="button button-primary" disabled={isSaving || !repertoireName.trim()} type="button" onClick={() => void handleCreateRepertoireItem()}>SAČUVAJ NUMERU</button>
                    </div>
                  </div>
                )}

                <div className="repertoire-list">
                  {repertoireItems.map((item) => (
                    <article className="repertoire-row" key={item.id}>
                      <div>
                        <strong>{item.name}</strong>
                        <span>{formatRepertoireType(item.item_type)} · {item.duration_minutes ? `${item.duration_minutes} min` : "trajanje nije uneto"}</span>
                        {item.costume_note && <small>Kostim: {item.costume_note}</small>}
                      </div>
                      <span className={`attendance-status-badge ${item.status === "ACTIVE" ? "closed" : "cancelled"}`}>
                        {item.status === "ACTIVE" ? "AKTIVNA" : "NEAKTIVNA"}
                      </span>
                      {userCanManageRepertoire && (
                        <button className="button button-secondary" disabled={isSaving} type="button" onClick={() => void handleToggleRepertoireStatus(item)}>
                          {item.status === "ACTIVE" ? "DEAKTIVIRAJ" : "AKTIVIRAJ"}
                        </button>
                      )}
                    </article>
                  ))}
                  {repertoireItems.length === 0 && <p>Nema unetih numera za ovu sekciju.</p>}
                </div>
              </section>
            )}

            {activeDetailTab === "settings" && (
              <section className="section-tab-panel settings-panel">
                <div className="section-duration-settings">
                  <p className="eyebrow">Trajanje probe</p>
                  {canEditSection ? (
                    <>
                      <select
                        className="input"
                        value={editedSectionDuration}
                        onChange={(event) =>
                          setEditedSectionDuration(Number(event.target.value))
                        }
                      >
                        {REHEARSAL_DURATION_OPTIONS.map((minutes) => (
                          <option key={minutes} value={minutes}>
                            {formatRehearsalDuration(minutes)}
                          </option>
                        ))}
                      </select>
                      <button
                        className="button button-primary"
                        disabled={
                          isSaving ||
                          editedSectionDuration ===
                            selectedSection.rehearsal_duration_minutes
                        }
                        type="button"
                        onClick={() => void handleUpdateSectionName()}
                      >
                        Sačuvaj trajanje
                      </button>
                    </>
                  ) : (
                    <strong>
                      {formatRehearsalDuration(
                        selectedSection.rehearsal_duration_minutes
                      )}
                    </strong>
                  )}
                </div>
                <div className="section-status-settings">
                  <p className="eyebrow">Status sekcije</p>
                  <strong>{selectedSection.status === "ACTIVE" ? "Aktivna sekcija" : "Neaktivna sekcija"}</strong>
                  <p>Promena statusa čuva postojeću istoriju sekcije, uloga i članstava.</p>
                  {canChangeSectionStatus && (
                    <button className="button button-secondary danger-action" disabled={isSaving} type="button" onClick={() => void handleToggleSectionStatus()}>
                      {selectedSection.status === "ACTIVE" ? "Deaktiviraj sekciju" : "Aktiviraj sekciju"}
                    </button>
                  )}
                </div>
              </section>
            )}

            {society && editingMemberId && editingPersonId && (
              <section className="card dashboard-card">
                <div className="page-heading" style={{ marginBottom: 12 }}>
                  <p className="eyebrow">Izmena člana</p>
                  <h1 style={{ fontSize: "1.2rem" }}>Sekcije člana</h1>
                </div>
                <UF_MEMBER_FORM
                  mode="edit"
                  societyId={society.id}
                  existingPersonId={editingPersonId}
                  existingMemberId={editingMemberId}
                  values={memberFormValues}
                  functionOptions={[]}
                  sectionOptions={editableSectionOptions}
                  readOnlyPersonFields={{
                    first_name: true,
                    last_name: true,
                    gender: true,
                    birth_date: true,
                    address: true,
                    city: true,
                    postal_code: true,
                    country: true,
                    jmbg: true,
                    passport_number: true,
                    passport_expiry_date: true,
                    email: true,
                    phone: true
                  }}
                  readOnlyMembershipFields={{
                    status: true,
                    start_date: true,
                    membership_fee_required: true,
                    membership_fee_amount: true
                  }}
                  readOnlyGuardianFields={{
                    guardian1: {
                      first_name: true,
                      last_name: true,
                      email: true,
                      phone: true
                    },
                    guardian2: {
                      first_name: true,
                      last_name: true,
                      email: true,
                      phone: true
                    }
                  }}
                  readOnlyFunctions
                  isSubmitting={isSaving}
                  onFieldChange={handleMemberFormFieldChange}
                  onGuardianFieldChange={handleMemberFormGuardianFieldChange}
                  onAddSecondGuardian={() =>
                    setMemberFormValues((currentValues) => ({
                      ...currentValues,
                      showGuardian2: true
                    }))
                  }
                  onRemoveSecondGuardian={() =>
                    setMemberFormValues((currentValues) => ({
                      ...currentValues,
                      showGuardian2: false,
                      guardian2: createInitialMemberFormValues().guardian2
                    }))
                  }
                  onFunctionToggle={() => undefined}
                  onSectionToggle={handleMemberFormSectionToggle}
                  onSubmit={() => void handleSubmitMemberEdit()}
                  onCancel={() => {
                    setEditingMemberId(null);
                    setEditingPersonId(null);
                  }}
                />
              </section>
            )}
          </section>
        )}
      </section>

      {confirmation && (
        <section
          className="card dashboard-card"
          role="dialog"
          aria-modal="true"
          style={{
            bottom: 24,
            boxShadow: "0 24px 60px rgba(15, 23, 42, 0.22)",
            maxWidth: 520,
            position: "fixed",
            right: 24,
            zIndex: 20
          }}
        >
          <div className="form-stack">
            <div>
              <p className="eyebrow">Potvrda</p>
              <strong>Potvrda</strong>
              <p>
                {confirmation.type === "section"
                  ?"Da li ste sigurni da želite da deaktivirate sekciju? Ovom akcijom sekcija postaje neaktivna, svi aktivni članovi u toj sekciji biće deaktivirani u toj sekciji, a dodele umetničkog rukovodioca i korepetitora više neće biti aktivne. Istorija ostaje sačuvana."
                  : "Da li ste sigurni da želite da uklonite ovog člana iz sekcije?"}
              </p>
            </div>
            <div className="header-actions">
              <button
                className="button button-secondary"
                disabled={isSaving}
                type="button"
                onClick={() => setConfirmation(null)}
              >
                OTKAŽI
              </button>
              <button
                className="button button-primary"
                disabled={isSaving}
                type="button"
                onClick={() =>
                  confirmation.type === "section"
                    ?void confirmDeactivateSection(confirmation.section)
                    : void handleToggleMemberStatus(confirmation.member)
                }
              >
                {confirmation.type === "section" ?"DEAKTIVIRAJ" : "UKLONI"}
              </button>
            </div>
          </div>
        </section>
      )}
    </>
  );
}
