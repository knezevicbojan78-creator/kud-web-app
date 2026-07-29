import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export type RegistrationStatus = "PENDING" | "APPROVED" | "REJECTED";

export type PresidentRegistration = {
  id: string;
  societyName: string;
  address: string;
  city: string;
  postalCode: string | null;
  country: string;
  PIB: string;
  registrationNumber: string;
  bankAccount: string | null;
  presidentFirstName: string;
  presidentLastName: string;
  presidentGender: string | null;
  presidentPhone: string;
  presidentEmail: string;
  password: string | null;
  confirmPassword: string | null;
  licenseType: string | null;
  licensePrice: number | null;
  StatReg: RegistrationStatus;
  createdAt: string;
  approvedAt: string | null;
  approvedByEmail: string | null;
  rejectionReason: string | null;
  rejectedAt: string | null;
  presidentUserId: string | null;
  societyId: string | null;
  requestedLicensePlanId: string | null;
  requestedLicenseKind: "MONTHLY" | "ANNUAL" | null;
  baseCurrency: string;
  membershipFeeAmount: number | null;
  chargeableMonths: number[];
};

export type PresidentRegistrationInsert = Omit<PresidentRegistration, "id"> & {
  StatReg: "PENDING";
};

export type PublicLicensePlan = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  monthly_price: number | null;
  annual_price: number | null;
  currency: string;
  active_member_limit: number | null;
  active_section_limit: number | null;
};

export type PermissionSettingsFunction = {
  id: string;
  name: string;
  is_president: boolean;
  assignment_count: number;
};

export type PermissionSettingsRule = {
  permission_key: string;
  module_key: string;
  label: string;
  description: string | null;
  action_type: string;
  allowed_scopes: string[];
  is_sensitive: boolean;
  requires_reason: boolean;
  is_enabled: boolean;
  current_scope: string | null;
  is_locked: boolean;
};

export type PermissionSettingsData = {
  society_id: string;
  actor_member_id: string;
  selected_function_id: string;
  functions: PermissionSettingsFunction[];
  rules: PermissionSettingsRule[];
};

export type PermissionFunctionMember = {
  society_member_id: string;
  display_name: string;
  active_function_names: string[];
  individual_override_count: number;
};

export type PermissionMemberRule = {
  permission_key: string;
  module_key: string;
  label: string;
  action_type: string;
  allowed_scopes: string[];
  is_sensitive: boolean;
  requires_reason: boolean;
  override_effect: "INHERIT" | "ALLOW" | "DENY";
  override_scope: string | null;
  effective_scopes: string[];
  effective_is_locked: boolean;
  effective_source_names: string[];
};

export type PermissionMemberConfiguration = {
  society_member_id: string;
  display_name: string;
  active_function_names: string[];
  rules: PermissionMemberRule[];
};

export type Society = {
  id: string;
  name: string;
  address: string;
  city: string;
  postal_code: string | null;
  country: string;
  pib: string;
  registration_number: string;
  bank_account: string | null;
  license_type: string | null;
  license_price: number | null;
  status: "ONBOARDING" | "ACTIVE" | "SUSPENDED";
  base_currency?: string;
  default_membership_fee_amount?: number | null;
  finance_start_month?: string | null;
  payment_instructions?: string | null;
  finance_last_reminder_at?: string | null;
  finance_last_reminder_by_user_id?: string | null;
};

export type SocietyInsert = Omit<Society, "id">;

export type MasterSocietySummary = {
  id: string;
  name: string;
  city: string;
  pib: string;
  registration_number: string;
  license_type: string | null;
  status: "ONBOARDING" | "ACTIVE" | "SUSPENDED";
  active_member_count: number;
  inactive_member_count: number;
  active_section_count: number;
  inactive_section_count: number;
  registered_at: string | null;
};

export type MasterDashboardData = {
  active_society_count: number;
  suspended_society_count: number;
  pending_registration_count: number;
  expiring_license_count: number;
  license_distribution: Array<{
    license_type: string;
    society_count: number;
  }>;
  recent_actions: Array<{
    id: string;
    action: string;
    entity_type: string;
    society_id: string | null;
    society_name: string | null;
    reason: string | null;
    result: "SUCCESS" | "FAILED";
    created_at: string;
  }>;
};

export type PresidentDashboardData = {
  account_type: "PRESIDENT";
  society_id: string;
  society_name: string;
  society_status: "ACTIVE";
  license_type: string;
  active_member_count: number;
  active_section_count: number;
  current_license_valid_until: string | null;
};

export type ApplicationMembership = {
  society_id: string;
  society_name: string;
  society_status: "ACTIVE" | "SUSPENDED";
  society_member_id: string;
  person_id: string;
  member_status: "ACTIVE" | "GUARDIAN";
  is_guardian?: boolean;
  functions: string[];
};

export type ApplicationContext = {
  account_type: "MASTER_ADMIN" | "SOCIETY_USER";
  user_id: string;
  email: string;
  is_master_admin: boolean;
  memberships: ApplicationMembership[];
};

export type MasterLicensePrice = {
  id: string;
  code: string;
  name: string;
  monthly_price: number;
  annual_price: number;
  currency: "EUR";
  active_member_limit: number;
  active_section_limit: number;
  updated_at: string;
};

export type MasterLicenseManagement = {
  plans: Array<{
    id: string;
    code: string;
    name: string;
    description: string | null;
    monthly_price: number;
    annual_price: number;
    currency: "EUR";
    active_member_limit: number;
    active_section_limit: number;
  }>;
  periods: Array<{
    id: string;
    plan_name: string;
    source: "PAID" | "PROMOTIONAL";
    billing_cycle: "MONTHLY" | "ANNUAL" | "PROMOTIONAL";
    duration_months: number;
    valid_from: string;
    valid_until: string;
    price_snapshot: number;
    currency_snapshot: string;
    member_limit: number | null;
    section_limit: number | null;
    promotion_reason: string | null;
    internal_note: string | null;
    created_at: string;
    paid_on: string | null;
    payment_method: "BANK_TRANSFER" | "CASH" | "OTHER" | null;
    payment_reference: string | null;
    payment_status: "RECORDED" | "VOIDED" | null;
  }>;
  promotion_used: boolean;
};

export type MasterSocietyDetail = {
  society: Society;
  counts: {
    active_members: number;
    inactive_members: number;
    active_sections: number;
    inactive_sections: number;
  };
  registration: {
    id: string;
    president_name: string;
    president_email: string;
    president_phone: string;
    approved_at: string | null;
  } | null;
  current_license: {
    id: string;
    plan_name: string;
    source: "PAID" | "PROMOTIONAL";
    billing_cycle: "MONTHLY" | "ANNUAL" | "PROMOTIONAL";
    duration_months: number;
    valid_from: string;
    valid_until: string;
    member_limit: number | null;
    section_limit: number | null;
  } | null;
  active_suspension: {
    id: string;
    reason_type: "LICENSE_EXPIRED" | "ADMINISTRATIVE" | "OTHER";
    reason: string;
    suspended_at: string;
  } | null;
  recent_audit: Array<{
    id: string;
    action: string;
    entity_type: string;
    reason: string | null;
    result: "SUCCESS" | "FAILED";
    created_at: string;
  }>;
};

export type Person = {
  id: string;
  first_name: string;
  last_name: string;
  gender: string | null;
  address: string | null;
  city: string | null;
  postal_code: string | null;
  country: string | null;
  jmbg: string | null;
  passport_number: string | null;
  passport_expiry_date: string | null;
  parental_travel_consent: boolean;
  parental_travel_consent_valid_until: string | null;
  nationality: string | null;
  passport_issuing_country: string | null;
  email: string | null;
  phone: string | null;
  shoe_size: number | null;
  birth_date: string | null;
  user_id: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type PersonInsert = Omit<
  Person,
  "id" | "country" | "nationality" | "passport_issuing_country" | "parental_travel_consent" | "parental_travel_consent_valid_until" | "created_at" | "updated_at"
> & {
  id?: string;
  country?: string | null;
  nationality?: string | null;
  passport_issuing_country?: string | null;
  parental_travel_consent?: boolean;
  parental_travel_consent_valid_until?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type SocietyMember = {
  id: string;
  society_id: string;
  person_id: string;
  user_id: string | null;
  status: string;
  start_date: string | null;
  funkcija: string | null;
  membership_fee_required: boolean;
  membership_fee_amount: number | null;
  created_at: string | null;
  updated_at: string | null;
};

export type WardrobeCategory = {
  id: string; society_id: string; name: string; code: string | null;
  is_footwear: boolean; is_active: boolean; sort_order: number;
};
export type WardrobeItem = {
  id: string; society_id: string; category_id: string; category_name: string;
  is_footwear: boolean; name: string; internal_code: string | null;
  age_group: "CHILD" | "ADULT" | "UNIVERSAL";
  gender_group: "MALE" | "FEMALE" | "UNISEX";
  shoe_size: number | null; total_quantity: number;
  assigned_quantity: number; unavailable_quantity: number; available_quantity: number;
  repertoire_names: string[]; note: string | null; is_active: boolean;
};
export type WardrobeKit = {
  id: string; society_id: string; name: string; internal_code: string | null;
  age_group: "CHILD" | "ADULT" | "UNIVERSAL";
  gender_group: "MALE" | "FEMALE" | "UNISEX";
  note: string | null; is_active: boolean;
  items: Array<{ wardrobe_item_id: string; name: string; shoe_size: number | null; quantity: number }>;
};
export type WardrobeAssignmentItem = {
  id: string; wardrobe_item_id: string; kit_id: string | null;
  item_name: string; kit_name: string | null; shoe_size: number | null;
  issued_quantity: number; returned_quantity: number; laundry_quantity: number;
  repair_quantity: number; lost_quantity: number; damaged_quantity: number;
};
export type WardrobeAssignment = {
  id: string; assignment_type: "MEMBER" | "LUGGAGE" | "EXTERNAL_LOAN" | "PLATFORM_LOAN";
  assigned_member_id: string | null; member_name: string | null;
  event_id: string | null; event_title: string | null; title: string | null;
  issued_at: string; due_date: string | null;
  status: "OPEN" | "PARTIALLY_RETURNED" | "RETURNED" | "OVERDUE" | "CANCELLED";
  note: string | null; items: WardrobeAssignmentItem[];
};
export type WardrobeWorkspace = {
  society_id: string; actor_member_id: string | null; is_manager: boolean;
  access?: { scope: "SOCIETY" | "SELF_AND_CHILDREN" | "CHILDREN"; can_manage: boolean };
  settings: { return_days_after_event: number; reminder_days_before_due: number };
  categories: WardrobeCategory[]; items: WardrobeItem[]; kits: WardrobeKit[];
  assignments: WardrobeAssignment[];
  members: Array<{ id: string; person_id: string; name: string; shoe_size: number | null }>;
  events: Array<{ id: string; title: string; return_at: string | null }>;
  repertoire: Array<{ id: string; name: string }>;
};
export type WardrobeRepair = {
  id: string; society_id: string; wardrobe_item_id: string;
  assignment_item_id: string | null; item_name: string; member_name: string | null;
  quantity: number; assignee_type: "MEMBER" | "GUARDIAN" | "SOCIETY_PERSON" | "EXTERNAL";
  assigned_member_id: string | null; assigned_name: string | null;
  external_name: string | null; external_contact: string | null;
  description: string; due_date: string | null;
  status: "WAITING_HANDOVER" | "HANDED_OVER" | "IN_PROGRESS" | "COMPLETED" | "RETURNED_TO_WARDROBE" | "UNREPAIRABLE";
  cost: number | null; note: string | null; created_at: string;
};
export type WardrobeLossCase = {
  id: string; assignment_item_id: string; assignment_id: string;
  assignment_title: string; item_name: string; member_name: string;
  quantity: number; status: "OPEN" | "REPLACEMENT_PENDING" | "RESOLVED";
  resolution_type: "RETURNED" | "REPLACED" | "FINANCIAL" | "WRITTEN_OFF" | "OTHER" | null;
  replacement_accepted_quantity: number; resolution_note: string | null;
  created_at: string; resolved_at: string | null;
};
export type WardrobeLuggage = {
  id: string; assignment_id: string; name: string; assignment_title: string;
  event_title: string | null; responsible_member_id: string; responsible_name: string;
  status: "PACKED" | "ISSUED" | "RETURNED" | "INCOMPLETE"; note: string | null;
  handovers: Array<{
    id: string; previous_member_id: string | null; new_member_id: string;
    previous_name: string | null; new_name: string; condition_note: string | null;
    created_at: string;
  }>;
};
export type WardrobeOperations = {
  repairs: WardrobeRepair[]; loss_cases: WardrobeLossCase[]; luggage: WardrobeLuggage[];
};
export type WardrobeLoan = {
  id: string; assignment_id: string; owner_society_id: string;
  loan_type: "EXTERNAL" | "PLATFORM"; recipient_society_id: string | null;
  recipient_name?: string; owner_name?: string;
  external_recipient_name: string | null; external_responsible_name: string | null;
  external_contact: string | null;
  assignment_title: string; responsible_member_name: string;
  event_title: string | null; due_date: string | null;
  assignment_status?: string;
  status: "ISSUED" | "RECEIVED" | "RETURN_PENDING" | "RETURNED" | "CANCELLED";
  issued_at: string; received_at: string | null; return_announced_at: string | null;
  returned_at: string | null; note: string | null;
  items: Array<{
    assignment_item_id: string; item_name: string; shoe_size: number | null;
    issued_quantity: number; returned_quantity: number; remaining_quantity: number;
  }>;
};
export type WardrobeLoanWorkspace = {
  platform_societies: Array<{ id: string; name: string; city: string | null }>;
  owned: WardrobeLoan[]; received: WardrobeLoan[];
};
export type WardrobeNotification = {
  id: string; society_id: string; society_member_id: string | null;
  person_id: string | null; assignment_id: string | null; repair_id: string | null;
  notification_type: string; title: string; body: string;
  scheduled_for: string; read_at: string | null;
};
export type WardrobeNotificationCenter = {
  unread_count: number; notifications: WardrobeNotification[];
};

export type SocietyMemberInsert = Omit<
  SocietyMember,
  | "id"
  | "status"
  | "funkcija"
  | "membership_fee_required"
  | "created_at"
  | "updated_at"
> & {
  id?: string;
  status?: string;
  funkcija?: string | null;
  membership_fee_required?: boolean;
  created_at?: string | null;
  updated_at?: string | null;
};

export type MemberStatusHistory = {
  id: string;
  society_member_id: string;
  status: string;
  effective_date: string;
  note: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type MemberStatusHistoryInsert = Omit<
  MemberStatusHistory,
  "id" | "note" | "created_at" | "updated_at"
> & {
  id?: string;
  note?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type SocietyMemberFunction = {
  id: string;
  society_id: string;
  name: string;
  is_system: boolean;
  is_active: boolean;
  sort_order: number;
  created_at: string | null;
  updated_at: string | null;
};

export type SocietyMemberFunctionInsert = Omit<
  SocietyMemberFunction,
  "id" | "is_system" | "is_active" | "sort_order" | "created_at" | "updated_at"
> & {
  id?: string;
  is_system?: boolean;
  is_active?: boolean;
  sort_order?: number;
  created_at?: string | null;
  updated_at?: string | null;
};

export type SocietyMemberFunctionAssignment = {
  id: string;
  society_id: string;
  society_member_id: string;
  function_id: string;
  created_at: string | null;
};

export type SocietyMemberFunctionAssignmentInsert = Omit<
  SocietyMemberFunctionAssignment,
  "id" | "created_at"
> & {
  id?: string;
  created_at?: string | null;
};

export type Section = {
  id: string;
  society_id: string;
  name: string;
  rehearsal_duration_minutes: number;
  status: string;
  created_at: string | null;
  updated_at: string | null;
};

export type SectionInsert = Omit<
  Section,
  "id" | "rehearsal_duration_minutes" | "status" | "created_at" | "updated_at"
> & {
  id?: string;
  rehearsal_duration_minutes?: number;
  status?: string;
  created_at?: string | null;
  updated_at?: string | null;
};

export type MemberSection = {
  id: string;
  society_id: string;
  section_id: string;
  society_member_id: string;
  status: string;
  created_at: string | null;
  updated_at: string | null;
};

export type MemberSectionInsert = Omit<
  MemberSection,
  "id" | "status" | "created_at" | "updated_at"
> & {
  id?: string;
  status?: string;
  created_at?: string | null;
  updated_at?: string | null;
};

export type MemberSectionHistory = {
  id: string;
  member_section_id: string;
  society_id: string;
  section_id: string;
  society_member_id: string;
  old_status: string | null;
  new_status: string;
  effective_date: string;
  changed_by_user_id: string | null;
  note: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type MemberSectionHistoryInsert = Omit<
  MemberSectionHistory,
  "id" | "effective_date" | "changed_by_user_id" | "note" | "created_at" | "updated_at"
> & {
  id?: string;
  effective_date?: string;
  changed_by_user_id?: string | null;
  note?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type SectionRoleAssignment = {
  id: string;
  society_id: string;
  section_id: string;
  society_member_id: string;
  role: string;
  status: string;
  can_manage_repertoire: boolean;
  created_at: string | null;
  updated_at: string | null;
};

export type SectionRoleAssignmentInsert = Omit<
  SectionRoleAssignment,
  "id" | "status" | "can_manage_repertoire" | "created_at" | "updated_at"
> & {
  id?: string;
  status?: string;
  can_manage_repertoire?: boolean;
  created_at?: string | null;
  updated_at?: string | null;
};

export type SectionAccompanist = {
  id: string;
  society_id: string;
  section_id: string;
  person_id: string;
  attendance_enabled: boolean;
  status: "ACTIVE" | "INACTIVE";
  active_from: string;
  active_until: string | null;
  created_by_user_id: string | null;
  updated_by_user_id: string | null;
  created_at: string;
  updated_at: string;
};

export type SocietyEventStatus =
  | "DRAFT" | "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED" | "COMPLETED";
export type SocietyEvent = {
  id: string; society_id: string; event_type: "CONCERT" | "TRIP"; title: string;
  description: string | null; status: SocietyEventStatus; organizer_name: string | null;
  organizer_contact: string | null; responsible_member_id: string | null;
  country: string; city: string | null; venue_name: string | null; address: string | null;
  meeting_point: string | null; meeting_at: string | null; departure_at: string | null;
  return_at: string | null; confirmation_deadline: string | null; transport_type: string | null;
  transport_company: string | null; accommodation: string | null; meals_note: string | null;
  has_participation_fee: boolean; default_participation_fee_amount: number | null;
  currency: string; payment_due_date: string | null; fee_note: string | null;
  created_by_user_id: string | null; created_by_society_member_id: string | null;
  created_by_role: string; submitted_at: string | null; reviewed_at: string | null;
  reviewed_by_user_id: string | null; reviewed_by_society_member_id: string | null;
  rejection_reason: string | null; cancelled_at: string | null; cancellation_reason: string | null;
  completed_at: string | null; created_at: string; updated_at: string;
};
export type EventSection = { id: string; event_id: string; section_id: string; added_by_user_id: string | null; added_by_society_member_id: string | null; created_at: string };
export type EventParticipant = { id: string; event_id: string; person_id: string; society_member_id: string | null; participation_status: "PLANNED" | "CONFIRMED" | "DECLINED" | "CANCELLED" | "ATTENDED" | "ABSENT"; participation_fee_amount: number | null; fee_is_overridden: boolean; note: string | null; added_by_user_id: string | null; added_by_society_member_id: string | null; created_at: string; updated_at: string };
export type FinanceSearchEntity = {
  entity_type: "PERSON" | "GUARDIAN";
  entity_id: string;
  display_name: string;
  subtitle: string | null;
  related_count: number;
  open_obligation_count: number;
  overdue_obligation_count: number;
};
export type FinanceProfilePerson = {
  person_id: string;
  society_member_id: string | null;
  name: string;
  email: string | null;
  phone: string | null;
  member_status: string | null;
  membership_fee_mode: "STANDARD" | "CUSTOM" | "EXEMPT" | null;
  membership_fee_amount: number | null;
};
export type FinanceOpenObligation = {
  id: string;
  person_id: string;
  type: "MEMBERSHIP_FEE" | "EVENT_FEE";
  title: string;
  original_amount: number;
  current_amount: number;
  paid_amount: number;
  remaining_amount: number;
  currency: string;
  due_date: string;
  is_overdue: boolean;
  status: "OPEN" | "PARTIALLY_PAID";
  event_id: string | null;
};
export type FinanceProfile = {
  entity: { type: "PERSON" | "GUARDIAN"; id: string; name: string; email: string | null };
  people: FinanceProfilePerson[];
  open_obligations: FinanceOpenObligation[];
  credits: Array<{ person_id: string; currency: string; amount: number }>;
  payments: Array<{
    id: string; receipt_number: string; amount: number; currency: string;
    payment_method: "CASH" | "BANK_TRANSFER"; status: "POSTED" | "VOIDED";
    recorded_at: string; recorded_by_member_id: string | null;
  }>;
  refunds: FinanceRefund[];
};
export type FinancePayment = {
  id: string;
  society_id: string;
  receipt_year: number;
  receipt_sequence: number;
  receipt_number: string;
  amount: number;
  currency: string;
  payment_method: "CASH" | "BANK_TRANSFER";
  status: "POSTED" | "VOIDED";
  recorded_by_user_id: string | null;
  recorded_by_society_member_id: string | null;
  recorded_at: string;
  voided_by_user_id: string | null;
  voided_by_society_member_id: string | null;
  voided_at: string | null;
  void_reason: string | null;
};
export type FinanceRefund = {
  id: string;
  person_id: string;
  refund_number: string;
  amount: number;
  currency: string;
  refund_method: "CASH" | "BANK_TRANSFER";
  status: "POSTED" | "VOIDED";
  reason: string;
  recorded_at: string;
  voided_at: string | null;
  void_reason: string | null;
};

export type FinanceMembershipSettings = {
  society_id: string;
  currency: string;
  standard_amount: number | null;
  finance_start_month: string | null;
  effective_from: string;
  chargeable_months: number[];
};

export type FinanceMemberFeeSetting = {
  society_member_id: string;
  person_id: string;
  display_name: string;
  fee_mode: "STANDARD" | "CUSTOM" | "EXEMPT";
  fee_amount: number | null;
  currency: string;
  effective_from: string | null;
};
export type EventParticipantSection = { id: string; event_participant_id: string; event_section_id: string; created_at: string };
export type RepertoireItem = { id: string; society_id: string; name: string; item_type: "CHOREOGRAPHY" | "SONG" | "INSTRUMENTAL" | "OTHER"; duration_minutes: number | null; description: string | null; costume_note: string | null; status: "ACTIVE" | "INACTIVE"; created_by_user_id: string | null; created_by_society_member_id: string | null; created_at: string; updated_at: string };
export type RepertoireItemSection = { id: string; repertoire_item_id: string; section_id: string; created_at: string };
export type EventAppearance = { id: string; event_id: string; title: string; starts_at: string | null; ends_at: string | null; country: string; city: string | null; venue_name: string | null; address: string | null; performance_order: number; note: string | null; created_at: string; updated_at: string };
export type EventAppearanceRepertoire = { id: string; event_appearance_id: string; event_section_id: string; repertoire_item_id: string; performance_order: number; note: string | null; created_at: string };
export type EventRepertoireParticipant = { id: string; event_appearance_repertoire_id: string; event_participant_id: string; created_at: string };
export type PersonDataChangeRequest = { id: string; society_id: string; person_id: string; event_id: string | null; current_values: Record<string, unknown>; proposed_changes: Record<string, unknown>; status: "PENDING" | "APPROVED" | "REJECTED"; requested_by_user_id: string | null; requested_by_society_member_id: string | null; requested_by_role: string; requested_at: string; reviewed_by_user_id: string | null; reviewed_by_society_member_id: string | null; reviewed_at: string | null; rejection_reason: string | null; created_at: string; updated_at: string };

export type AttendanceStatus = "ABSENT" | "PRESENT";
export type AttendanceSessionStatus = "OPEN" | "CLOSED" | "CANCELLED";

export type AttendanceSession = {
  id: string;
  society_id: string;
  section_id: string;
  status: AttendanceSessionStatus;
  opened_at: string;
  opened_by_user_id: string | null;
  opened_by_role: string;
  closed_at: string | null;
  closed_by_user_id: string | null;
  closed_by_role: string | null;
  cancelled_at: string | null;
  cancelled_by_user_id: string | null;
  cancelled_by_role: string | null;
  planned_end_at: string;
  auto_close_at: string;
  close_type: "MANUAL" | "AUTOMATIC" | null;
  created_at: string;
  updated_at: string;
};

export type AttendanceSessionInsert = Omit<
  AttendanceSession,
  "id" | "status" | "opened_at" | "planned_end_at" | "auto_close_at" |
    "close_type" | "closed_at" | "closed_by_user_id" |
    "closed_by_role" | "cancelled_at" | "cancelled_by_user_id" |
    "cancelled_by_role" | "created_at" | "updated_at"
> & {
  id?: string;
  status?: AttendanceSessionStatus;
  opened_at?: string;
  planned_end_at?: string;
  auto_close_at?: string;
  close_type?: "MANUAL" | "AUTOMATIC" | null;
  closed_at?: string | null;
  closed_by_user_id?: string | null;
  closed_by_role?: string | null;
  cancelled_at?: string | null;
  cancelled_by_user_id?: string | null;
  cancelled_by_role?: string | null;
  created_at?: string;
  updated_at?: string;
};

export type AttendanceRecord = {
  id: string;
  attendance_session_id: string;
  society_member_id: string | null;
  person_id: string;
  participant_type: "MEMBER" | "ACCOMPANIST";
  role_label: string | null;
  status: AttendanceStatus;
  updated_at: string;
  updated_by_user_id: string | null;
  updated_by_role: string;
};

export type AttendanceRecordInsert = Omit<
  AttendanceRecord,
  "id" | "status" | "updated_at"
> & {
  id?: string;
  status?: AttendanceStatus;
  updated_at?: string;
};

export type AttendanceRecordHistory = {
  id: string;
  attendance_record_id: string;
  old_status: AttendanceStatus | null;
  new_status: AttendanceStatus;
  changed_at: string;
  changed_by_user_id: string | null;
  changed_by_role: string;
  session_status_at_change: AttendanceSessionStatus;
  reason: string | null;
};

export type AttendanceRecordHistoryInsert = Omit<
  AttendanceRecordHistory,
  "id" | "changed_at"
> & {
  id?: string;
  changed_at?: string;
};

export type PersonGuardian = {
  id: string;
  child_person_id: string;
  guardian_person_id: string;
  relationship: string | null;
  is_primary: boolean | null;
  created_at: string | null;
  updated_at: string | null;
};

export type PersonGuardianInsert = Omit<
  PersonGuardian,
  "id" | "relationship" | "is_primary" | "created_at" | "updated_at"
> & {
  id?: string;
  relationship?: string | null;
  is_primary?: boolean | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type UserOnboardingState = {
  id: string;
  user_id: string;
  society_id: string;
  president_reg_id: string | null;
  president_profile_completed: boolean;
  president_permissions_bootstrapped: boolean;
  completed_at: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type UserOnboardingStateInsert = Omit<
  UserOnboardingState,
  | "id"
  | "president_reg_id"
  | "president_profile_completed"
  | "president_permissions_bootstrapped"
  | "completed_at"
  | "created_at"
  | "updated_at"
> & {
  id?: string;
  president_reg_id?: string | null;
  president_profile_completed?: boolean;
  president_permissions_bootstrapped?: boolean;
  completed_at?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

export type PresidentChangeRequest = {
  id: string;
  society_id: string;
  current_president_member_id: string;
  current_president_person_id: string;
  new_president_member_id: string;
  new_president_person_id: string;
  status: string;
  requested_by_user_id: string | null;
  requested_at: string | null;
  reviewed_by_user_id: string | null;
  reviewed_by_email: string | null;
  reviewed_at: string | null;
  rejection_reason: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type PresidentChangeRequestInsert = Omit<
  PresidentChangeRequest,
  | "id"
  | "status"
  | "requested_by_user_id"
  | "requested_at"
  | "reviewed_by_user_id"
  | "reviewed_by_email"
  | "reviewed_at"
  | "rejection_reason"
  | "created_at"
  | "updated_at"
> & {
  id?: string;
  status?: string;
  requested_by_user_id?: string | null;
  requested_at?: string | null;
  reviewed_by_user_id?: string | null;
  reviewed_by_email?: string | null;
  reviewed_at?: string | null;
  rejection_reason?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
};

type Database = {
  public: {
    Tables: {
      PresidentReg: {
        Row: PresidentRegistration;
        Insert: PresidentRegistrationInsert;
        Update: Partial<Omit<PresidentRegistration, "id">>;
        Relationships: [];
      };
      societies: {
        Row: Society;
        Insert: SocietyInsert;
        Update: Partial<Omit<Society, "id">>;
        Relationships: [];
      };
      people: {
        Row: Person;
        Insert: PersonInsert;
        Update: Partial<Omit<Person, "id">>;
        Relationships: [];
      };
      society_members: {
        Row: SocietyMember;
        Insert: SocietyMemberInsert;
        Update: Partial<Omit<SocietyMember, "id">>;
        Relationships: [];
      };
      society_fee_month_rule_history: {
        Row: {
          id: string; society_id: string; month_number: number; is_chargeable: boolean;
          effective_from: string; reason: string; changed_by_user_id: string | null;
          changed_by_society_member_id: string | null; created_at: string;
        };
        Insert: {
          id?: string; society_id: string; month_number: number; is_chargeable: boolean;
          effective_from: string; reason: string; changed_by_user_id?: string | null;
          changed_by_society_member_id?: string | null; created_at?: string;
        };
        Update: never;
        Relationships: [];
      };
      member_status_history: {
        Row: MemberStatusHistory;
        Insert: MemberStatusHistoryInsert;
        Update: Partial<Omit<MemberStatusHistory, "id">>;
        Relationships: [];
      };
      society_member_functions: {
        Row: SocietyMemberFunction;
        Insert: SocietyMemberFunctionInsert;
        Update: Partial<Omit<SocietyMemberFunction, "id">>;
        Relationships: [];
      };
      society_member_function_assignments: {
        Row: SocietyMemberFunctionAssignment;
        Insert: SocietyMemberFunctionAssignmentInsert;
        Update: Partial<Omit<SocietyMemberFunctionAssignment, "id">>;
        Relationships: [];
      };
      sections: {
        Row: Section;
        Insert: SectionInsert;
        Update: Partial<Omit<Section, "id">>;
        Relationships: [];
      };
      member_sections: {
        Row: MemberSection;
        Insert: MemberSectionInsert;
        Update: Partial<Omit<MemberSection, "id">>;
        Relationships: [];
      };
      member_section_history: {
        Row: MemberSectionHistory;
        Insert: MemberSectionHistoryInsert;
        Update: Partial<Omit<MemberSectionHistory, "id">>;
        Relationships: [];
      };
      section_role_assignments: {
        Row: SectionRoleAssignment;
        Insert: SectionRoleAssignmentInsert;
        Update: Partial<Omit<SectionRoleAssignment, "id">>;
        Relationships: [];
      };
      attendance_sessions: {
        Row: AttendanceSession;
        Insert: AttendanceSessionInsert;
        Update: Partial<Omit<AttendanceSession, "id">>;
        Relationships: [];
      };
      attendance_records: {
        Row: AttendanceRecord;
        Insert: AttendanceRecordInsert;
        Update: Partial<Omit<AttendanceRecord, "id">>;
        Relationships: [];
      };
      section_accompanists: {
        Row: SectionAccompanist;
        Insert: Partial<SectionAccompanist> &
          Pick<SectionAccompanist, "society_id" | "section_id" | "person_id">;
        Update: Partial<Omit<SectionAccompanist, "id">>;
        Relationships: [];
      };
      attendance_record_history: {
        Row: AttendanceRecordHistory;
        Insert: AttendanceRecordHistoryInsert;
        Update: never;
        Relationships: [];
      };
      society_events: {
        Row: SocietyEvent;
        Insert: Partial<SocietyEvent> & Pick<SocietyEvent, "society_id" | "event_type" | "title" | "created_by_role">;
        Update: Partial<SocietyEvent>;
        Relationships: [];
      };
      event_sections: {
        Row: EventSection;
        Insert: Partial<EventSection> & Pick<EventSection, "event_id" | "section_id">;
        Update: Partial<EventSection>;
        Relationships: [];
      };
      event_participants: {
        Row: EventParticipant;
        Insert: Partial<EventParticipant> & Pick<EventParticipant, "event_id" | "person_id">;
        Update: Partial<EventParticipant>;
        Relationships: [];
      };
      event_participant_sections: {
        Row: EventParticipantSection;
        Insert: Partial<EventParticipantSection> & Pick<EventParticipantSection, "event_participant_id" | "event_section_id">;
        Update: Partial<EventParticipantSection>;
        Relationships: [];
      };
      repertoire_items: {
        Row: RepertoireItem;
        Insert: Partial<RepertoireItem> & Pick<RepertoireItem, "society_id" | "name">;
        Update: Partial<RepertoireItem>;
        Relationships: [];
      };
      repertoire_item_sections: {
        Row: RepertoireItemSection;
        Insert: Partial<RepertoireItemSection> & Pick<RepertoireItemSection, "repertoire_item_id" | "section_id">;
        Update: Partial<RepertoireItemSection>;
        Relationships: [];
      };
      event_appearances: {
        Row: EventAppearance;
        Insert: Partial<EventAppearance> & Pick<EventAppearance, "event_id" | "title">;
        Update: Partial<EventAppearance>;
        Relationships: [];
      };
      event_appearance_repertoire: {
        Row: EventAppearanceRepertoire;
        Insert: Partial<EventAppearanceRepertoire> & Pick<EventAppearanceRepertoire, "event_appearance_id" | "event_section_id" | "repertoire_item_id">;
        Update: Partial<EventAppearanceRepertoire>;
        Relationships: [];
      };
      event_repertoire_participants: {
        Row: EventRepertoireParticipant;
        Insert: Partial<EventRepertoireParticipant> & Pick<EventRepertoireParticipant, "event_appearance_repertoire_id" | "event_participant_id">;
        Update: Partial<EventRepertoireParticipant>;
        Relationships: [];
      };
      person_data_change_requests: {
        Row: PersonDataChangeRequest;
        Insert: Partial<PersonDataChangeRequest> & Pick<PersonDataChangeRequest, "society_id" | "person_id" | "proposed_changes" | "requested_by_role">;
        Update: Partial<PersonDataChangeRequest>;
        Relationships: [];
      };
      person_guardians: {
        Row: PersonGuardian;
        Insert: PersonGuardianInsert;
        Update: Partial<Omit<PersonGuardian, "id">>;
        Relationships: [];
      };
      user_onboarding_state: {
        Row: UserOnboardingState;
        Insert: UserOnboardingStateInsert;
        Update: Partial<Omit<UserOnboardingState, "id">>;
        Relationships: [];
      };
      president_change_requests: {
        Row: PresidentChangeRequest;
        Insert: PresidentChangeRequestInsert;
        Update: Partial<Omit<PresidentChangeRequest, "id">>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      auth_get_bootstrap_status: {
        Args: Record<never, never>;
        Returns: {
          master_admin_active: boolean;
          master_admin_registration_available: boolean;
        };
      };
      auth_get_session_context: {
        Args: Record<never, never>;
        Returns: {
          authenticated: boolean;
          user_id?: string;
          email?: string;
          email_confirmed: boolean;
          is_allowed_master_email?: boolean;
          is_master_admin: boolean;
          aal: "aal1" | "aal2";
          requires_master_mfa?: boolean;
        };
      };
      auth_bootstrap_master_admin: {
        Args: Record<never, never>;
        Returns: {
          master_admin_active: boolean;
          user_id: string;
          email: string;
          aal: "aal2";
        };
      };
      auth_submit_president_request: {
        Args: {
          p_society_name: string;
          p_address: string;
          p_city: string;
          p_country: string;
          p_pib: string;
          p_registration_number: string;
          p_president_first_name: string;
          p_president_last_name: string;
          p_president_email: string;
          p_president_phone: string;
          p_requested_license_plan_id: string;
          p_requested_license_kind: "MONTHLY" | "ANNUAL";
        };
        Returns: { request_id: string; status: "PENDING" };
      };
      auth_get_public_license_plans: {
        Args: Record<never, never>;
        Returns: PublicLicensePlan[];
      };
      master_admin_approve_president_request: {
        Args: {
          p_request_id: string;
          p_license_plan_id: string;
          p_license_kind: "MONTHLY" | "ANNUAL" | "PROMOTIONAL_3" | "PROMOTIONAL_6" | "PROMOTIONAL_12";
          p_paid_on?: string | null;
          p_payment_method?: "BANK_TRANSFER" | "CASH" | "OTHER" | null;
          p_payment_reference?: string | null;
          p_reason?: string | null;
        };
        Returns: {
          request_id: string;
          society_id: string;
          president_email: string;
          society_name: string;
          license_assignment_id: string;
          status: "APPROVED";
        };
      };
      master_admin_get_president_requests: {
        Args: {
          p_status?: RegistrationStatus | null;
          p_request_id?: string | null;
        };
        Returns: PresidentRegistration[];
      };
      auth_activate_approved_president: {
        Args: Record<never, never>;
        Returns: {
          request_id: string;
          society_id: string;
          society_name: string;
          onboarding_required: true;
        };
      };
      auth_get_login_destination: {
        Args: Record<never, never>;
        Returns: {
          account_type: "MASTER_ADMIN" | "PRESIDENT" | "SOCIETY_USER" | "PENDING_ACTIVATION";
          destination: string;
          society_id?: string;
          onboarding_completed?: boolean;
        };
      };
      auth_get_account_activation: {
        Args: Record<never, never>;
        Returns: {
          person_name: string;
          completed: boolean;
          memberships: Array<{
            id: string;
            society_name: string;
            status: string;
            decision: "ACCEPTED" | "REJECTED" | null;
          }>;
          guardian_links: Array<{
            id: string;
            child_name: string;
            relationship: string;
            societies: string[];
            decision: "ACCEPTED" | "REJECTED" | null;
          }>;
        };
      };
      auth_complete_account_activation: {
        Args: {
          p_decisions: Array<{ kind: string; id: string; decision: string }>;
        };
        Returns: { completed: boolean; has_access: boolean };
      };
      auth_get_application_context: {
        Args: Record<never, never>;
        Returns: ApplicationContext;
      };
      auth_get_society_workspace: {
        Args: { p_society_id: string };
        Returns: {
          society: Society;
          actor_society_member_id: string;
          functions: string[];
          sections: Array<Section & {
            roles: Array<SectionRoleAssignment & {
              memberName: string;
              email: string | null;
              phone: string | null;
            }>;
          }>;
        };
      };
      auth_get_sections_workspace: {
        Args: { p_society_id: string };
        Returns: {
          society: Society;
          actor_society_member_id: string;
          access: {
            can_create: boolean;
            can_change_status: boolean;
            can_manage_roles: boolean;
          };
          sections: Array<Section & {
            access: {
              can_edit: boolean;
              can_manage_members: boolean;
              can_manage_roles: boolean;
              can_manage_repertoire: boolean;
              can_manage_accompanists: boolean;
            };
            roles: Array<SectionRoleAssignment & {
              memberName: string;
              email: string | null;
              phone: string | null;
            }>;
          }>;
        };
      };
      auth_get_section_detail: {
        Args: { p_section_id: string };
        Returns: {
          members: Array<{
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
          }>;
          accompanists: Array<SectionAccompanist & {
            name: string;
            email: string | null;
            phone: string | null;
          }>;
          repertoire: RepertoireItem[];
        };
      };
      auth_get_attendance_workspace: {
        Args: { p_society_id: string; p_section_id?: string | null };
        Returns: {
          society: Society;
          actor_society_member_id: string;
          sections: Array<Section & {
            access: {
              can_open: boolean;
              can_record_open: boolean;
              can_close: boolean;
              can_cancel: boolean;
              can_edit_closed: boolean;
            };
          }>;
          session: AttendanceSession | null;
          members: Array<AttendanceRecord & {
            name: string;
            gender: Person["gender"];
            participantType: "MEMBER" | "ACCOMPANIST";
            roleLabel: string | null;
          }>;
        };
      };
      auth_get_attendance_history: {
        Args: {
          p_society_id: string;
          p_section_id?: string | null;
          p_status?: "ALL" | "CLOSED" | "CANCELLED";
          p_date_from?: string | null;
          p_date_to?: string | null;
          p_session_id?: string | null;
        };
        Returns: {
          sections: Section[];
          sessions: Array<AttendanceSession & {
            sectionName: string;
            presentCount: number;
            absentCount: number;
            accompanistPresentCount: number;
            accompanistAbsentCount: number;
          }>;
          detail_members: Array<AttendanceRecord & {
            name: string;
            participantType: "MEMBER" | "ACCOMPANIST";
            roleLabel: string | null;
          }>;
          can_edit_detail: boolean;
        };
      };
      auth_get_events_workspace: {
        Args: { p_society_id: string; p_event_id?: string | null };
        Returns: {
          society: Society;
          actor_society_member_id: string;
          access: { can_create: boolean; can_manage_fee: boolean };
          sections: Section[];
          events: Array<SocietyEvent & {
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
          }>;
          repertoire: RepertoireItem[];
          repertoire_section_links: RepertoireItemSection[];
          detail: null | {
            event_sections: EventSection[];
            participants: Array<EventParticipant & {
              name: string;
              person: Person;
            }>;
            participant_section_links: EventParticipantSection[];
            appearances: EventAppearance[];
            program: EventAppearanceRepertoire[];
            performer_links: EventRepertoireParticipant[];
          };
        };
      };
      auth_search_event_people: {
        Args: { p_event_id: string; p_query: string };
        Returns: Person[];
      };
      auth_list_event_section_candidates: {
        Args: { p_event_section_id: string };
        Returns: Array<{ member: SocietyMember; person: Person }>;
      };
      auth_get_finance_workspace: {
        Args: { p_society_id: string };
        Returns: {
          society: Society;
          actor_society_member_id: string;
          access: {
            can_search_society: boolean;
            can_record_payment: boolean;
            can_use_credit: boolean;
            can_view_audit: boolean;
            can_record_refund: boolean;
            can_void_payment: boolean;
            can_void_refund: boolean;
          };
          initial_entity: FinanceSearchEntity;
        };
      };
      auth_get_president_dashboard: {
        Args: Record<never, never>;
        Returns: PresidentDashboardData;
      };
      auth_get_president_members_page: {
        Args: Record<never, never>;
        Returns: {
          society: Society;
          functions: SocietyMemberFunction[];
          sections: Section[];
          members: Array<{
            id: string;
            person_id: string;
            first_name: string;
            last_name: string;
            birth_date: string | null;
            email: string | null;
            phone: string | null;
            status: "ACTIVE" | "INACTIVE";
            start_date: string;
          }>;
        };
      };
      auth_get_members_page: {
        Args: Record<never, never>;
        Returns: {
          society: Society;
          access: {
            can_create: boolean;
            can_manage_functions: boolean;
            can_manage_sections: boolean;
          };
          functions: SocietyMemberFunction[];
          sections: Section[];
          members: Array<{
            id: string;
            person_id: string;
            first_name: string;
            last_name: string;
            birth_date: string | null;
            email: string | null;
            phone: string | null;
            status: "ACTIVE" | "INACTIVE";
            start_date: string;
          }>;
        };
      };
      auth_can_bulk_import_members: {
        Args: { p_society_id?: string | null };
        Returns: boolean;
      };
      auth_lookup_person_for_member: {
        Args: {
          p_society_id: string;
          p_email?: string | null;
          p_jmbg?: string | null;
          p_passport_number?: string | null;
        };
        Returns: {
          person: Person | null;
          already_member: boolean;
        };
      };
      auth_get_president_member_detail: {
        Args: { p_society_member_id: string };
        Returns: {
          member: SocietyMember;
          person: Person;
          guardians: Array<{
            link: PersonGuardian;
            person: Person;
          }>;
          function_ids: string[];
          section_ids: string[];
        };
      };
      auth_get_member_detail: {
        Args: { p_society_member_id: string };
        Returns: {
          member: SocietyMember;
          person: Person;
          guardians: Array<{
            link: PersonGuardian;
            person: Person;
          }>;
          function_ids: string[];
          section_ids: string[];
          access: {
            can_view_sensitive: boolean;
            can_view_guardians: boolean;
            can_edit_basic: boolean;
            can_edit_sensitive: boolean;
            can_change_status: boolean;
            can_manage_guardians: boolean;
            can_manage_sections: boolean;
            can_manage_functions: boolean;
          };
        };
      };
      auth_update_society_member: {
        Args: {
          p_society_member_id: string;
          p_profile: Record<string, string | number | boolean | null>;
          p_guardians?: Array<
            Record<string, string | boolean | null>
          >;
          p_function_ids?: string[];
          p_section_ids?: string[];
        };
        Returns: {
          society_member_id: string;
          updated: boolean;
        };
      };
      auth_update_my_profile: {
        Args: { p_profile: Record<string, string | number | null> };
        Returns: Person;
      };
      auth_get_wardrobe_workspace: {
        Args: { p_society_id: string };
        Returns: WardrobeWorkspace;
      };
      auth_get_wardrobe_page: {
        Args: { p_society_id: string };
        Returns: WardrobeWorkspace;
      };
      auth_wardrobe_save_category: {
        Args: { p_society_id: string; p_category: Record<string, unknown> };
        Returns: string;
      };
      auth_wardrobe_save_item: {
        Args: { p_society_id: string; p_item: Record<string, unknown> };
        Returns: string;
      };
      auth_wardrobe_get_item_repertoire: {
        Args: { p_society_id: string; p_wardrobe_item_id: string };
        Returns: string[];
      };
      auth_get_wardrobe_operations: {
        Args: { p_society_id: string };
        Returns: WardrobeOperations;
      };
      auth_wardrobe_save_kit: {
        Args: { p_society_id: string; p_kit: Record<string, unknown> };
        Returns: string;
      };
      auth_wardrobe_create_assignment: {
        Args: { p_society_id: string; p_assignment: Record<string, unknown> };
        Returns: string;
      };
      auth_wardrobe_record_return: {
        Args: { p_society_id: string; p_assignment_id: string; p_returns: Array<Record<string, unknown>>; p_note?: string | null };
        Returns: string;
      };
      auth_wardrobe_save_settings: {
        Args: { p_society_id: string; p_return_days: number; p_reminder_days: number };
        Returns: WardrobeWorkspace["settings"];
      };
      auth_wardrobe_update_repair: {
        Args: { p_society_id: string; p_repair_id: string; p_changes: Record<string, unknown> };
        Returns: WardrobeRepair;
      };
      auth_wardrobe_resolve_loss: {
        Args: {
          p_society_id: string; p_loss_case_id: string;
          p_resolution: "RETURNED" | "REPLACED" | "FINANCIAL" | "WRITTEN_OFF" | "OTHER";
          p_note: string; p_replacement_quantity?: number;
        };
        Returns: WardrobeLossCase;
      };
      auth_wardrobe_handover_luggage: {
        Args: { p_society_id: string; p_luggage_id: string; p_new_member_id: string; p_condition_note: string };
        Returns: WardrobeLuggage;
      };
      auth_get_wardrobe_loans: {
        Args: { p_society_id: string };
        Returns: WardrobeLoanWorkspace;
      };
      auth_wardrobe_create_loan: {
        Args: { p_society_id: string; p_loan: Record<string, unknown> };
        Returns: string;
      };
      auth_wardrobe_transition_loan: {
        Args: { p_society_id: string; p_loan_id: string; p_action: "CONFIRM_RECEIPT" | "ANNOUNCE_RETURN" | "CONFIRM_RETURN"; p_note?: string | null };
        Returns: WardrobeLoan;
      };
      auth_get_wardrobe_notifications: {
        Args: { p_society_id: string };
        Returns: WardrobeNotificationCenter;
      };
      auth_wardrobe_mark_notification_read: {
        Args: { p_society_id: string; p_notification_id: string };
        Returns: string;
      };
      auth_create_society_member: {
        Args: {
          p_society_id: string;
          p_profile: Record<string, string | number | boolean | null>;
          p_guardians?: Array<
            Record<string, string | boolean | null>
          >;
          p_function_ids?: string[];
          p_section_ids?: string[];
        };
        Returns: {
          society_member_id: string;
          person_id: string;
          reused_person: boolean;
        };
      };
      auth_manage_section: {
        Args: {
          p_action: string;
          p_payload: Record<string, string | number | boolean | null>;
        };
        Returns: {
          success: boolean;
          id: string | null;
        };
      };
      auth_search_society_members: {
        Args: {
          p_society_id: string;
          p_query: string;
          p_section_id?: string | null;
          p_exclude_active_section?: boolean;
          p_exclude_active_role?: string | null;
        };
        Returns: Array<{
          societyMemberId: string;
          personId: string;
          name: string;
          email: string | null;
          phone: string | null;
        }>;
      };
      auth_manage_event: {
        Args: {
          p_action: string;
          p_payload: {
            [key: string]:
              | string
              | number
              | boolean
              | null
              | string[];
          };
        };
        Returns: {
          success: boolean;
          id: string | null;
        };
      };
      auth_get_president_onboarding: {
        Args: Record<never, never>;
        Returns: {
          society: {
            id: string;
            name: string;
            address: string;
            city: string;
            postal_code: string | null;
            country: string;
            pib: string;
            registration_number: string;
            bank_account: string | null;
            license_type: string | null;
            status: string;
          };
          president: {
            first_name: string;
            last_name: string;
            email: string;
            phone: string;
          };
          state: {
            society_profile_completed: boolean;
            president_profile_completed: boolean;
            completed: boolean;
          };
        };
      };
      auth_save_president_society_onboarding: {
        Args: { p_society: Record<string, unknown> };
        Returns: { society_id: string; society_profile_completed: true };
      };
      auth_complete_president_onboarding: {
        Args: { p_profile: Record<string, unknown> };
        Returns: {
          society_id: string;
          person_id: string;
          society_member_id: string;
          license_period_id: string;
          completed: true;
        };
      };
      auth_permissions_get_settings: {
        Args: { p_function_id?: string | null };
        Returns: PermissionSettingsData;
      };
      auth_permissions_save_function_rules: {
        Args: {
          p_function_id: string;
          p_changes: Array<{ permission_key: string; enabled: boolean; scope_key: string | null }>;
          p_reason: string;
        };
        Returns: PermissionSettingsData;
      };
      auth_permissions_list_function_members: {
        Args: { p_function_id: string; p_query?: string };
        Returns: PermissionFunctionMember[];
      };
      auth_permissions_get_member_configuration: {
        Args: { p_target_member_id: string };
        Returns: PermissionMemberConfiguration;
      };
      auth_permissions_save_member_overrides: {
        Args: {
          p_target_member_id: string;
          p_changes: Array<{
            permission_key: string;
            effect: "INHERIT" | "ALLOW" | "DENY";
            scope_key: string | null;
          }>;
          p_reason: string;
        };
        Returns: PermissionMemberConfiguration;
      };
      auth_manage_section_accompanist: {
        Args: {
          p_action: "ASSIGN" | "CREATE_AND_ASSIGN" | "SET_ATTENDANCE" | "DEACTIVATE";
          p_payload: Record<string, string | boolean | null>;
        };
        Returns: SectionAccompanist;
      };
      auth_search_accompanist_people: {
        Args: {
          p_society_id: string;
          p_section_id: string;
          p_query: string;
        };
        Returns: Array<{
          personId: string;
          name: string;
          email: string | null;
          phone: string | null;
        }>;
      };
      open_attendance_session: {
        Args: {
          p_society_id: string;
          p_section_id: string;
          p_actor_role: string;
          p_actor_user_id?: string | null;
        };
        Returns: string;
      };
      set_attendance_status: {
        Args: {
          p_record_id: string;
          p_new_status: string;
          p_actor_role: string;
          p_reason?: string | null;
          p_actor_user_id?: string | null;
        };
        Returns: AttendanceRecord;
      };
      close_attendance_session: {
        Args: {
          p_session_id: string;
          p_actor_role: string;
          p_actor_user_id?: string | null;
        };
        Returns: AttendanceSession;
      };
      cancel_attendance_session: {
        Args: {
          p_session_id: string;
          p_actor_role: string;
          p_actor_user_id?: string | null;
        };
        Returns: AttendanceSession;
      };
      submit_event: { Args: { p_event_id: string; p_actor_role: string; p_actor_user_id?: string | null; p_actor_member_id?: string | null }; Returns: SocietyEvent };
      approve_event: { Args: { p_event_id: string; p_actor_user_id?: string | null; p_actor_member_id?: string | null }; Returns: SocietyEvent };
      reject_event: { Args: { p_event_id: string; p_reason: string; p_actor_user_id?: string | null; p_actor_member_id?: string | null }; Returns: SocietyEvent };
      cancel_event: { Args: { p_event_id: string; p_reason: string; p_actor_role: string; p_actor_user_id?: string | null; p_actor_member_id?: string | null }; Returns: SocietyEvent };
      finance_cancel_event: { Args: { p_event_id: string; p_reason: string; p_actor_member_id: string }; Returns: SocietyEvent };
      finance_cancel_event_section: { Args: { p_event_section_id: string; p_reason: string; p_actor_member_id: string }; Returns: { cancelled_obligations: number; removed_unconfirmed_participants: number } };
      complete_event: { Args: { p_event_id: string; p_actor_role: string; p_actor_user_id?: string | null; p_actor_member_id?: string | null }; Returns: SocietyEvent };
      set_event_participant_status: { Args: { p_event_participant_id: string; p_new_status: string; p_actor_role: string }; Returns: EventParticipant };
      finance_set_event_participant_status: { Args: { p_event_participant_id: string; p_new_status: string; p_reason: string; p_actor_member_id: string }; Returns: EventParticipant };
      finance_search_entities: { Args: { p_society_id: string; p_query: string; p_actor_member_id: string; p_limit?: number }; Returns: FinanceSearchEntity[] };
      finance_get_actor_context: { Args: Record<never, never>; Returns: { society_id: string; society_member_id: string; role: "Predsednik" | "Blagajnik" } | null };
      finance_get_membership_settings: { Args: { p_society_id: string; p_actor_member_id: string }; Returns: FinanceMembershipSettings };
      finance_update_membership_settings: { Args: {
        p_society_id: string; p_standard_amount: number; p_chargeable_months: number[];
        p_reason: string; p_actor_member_id: string;
      }; Returns: FinanceMembershipSettings };
      finance_list_member_fee_settings: { Args: {
        p_society_id: string; p_query: string; p_only_nonstandard: boolean; p_actor_member_id: string;
      }; Returns: FinanceMemberFeeSetting[] };
      finance_set_member_fee: { Args: {
        p_society_member_id: string; p_fee_mode: "STANDARD" | "CUSTOM" | "EXEMPT";
        p_custom_amount: number | null; p_reason: string; p_actor_user_id: string | null;
        p_actor_member_id: string;
      }; Returns: unknown };
      finance_get_entity_profile: { Args: { p_society_id: string; p_entity_type: "PERSON" | "GUARDIAN"; p_entity_id: string; p_actor_member_id?: string | null }; Returns: FinanceProfile };
      finance_list_entity_refunds: { Args: { p_society_id: string; p_entity_type: "PERSON" | "GUARDIAN"; p_entity_id: string; p_actor_member_id?: string | null }; Returns: FinanceRefund[] };
      master_admin_get_society_summaries: { Args: Record<never, never>; Returns: MasterSocietySummary[] };
      master_admin_get_dashboard: { Args: Record<never, never>; Returns: MasterDashboardData };
      master_admin_get_license_prices: { Args: Record<never, never>; Returns: MasterLicensePrice[] };
      master_admin_update_license_price: { Args: {
        p_license_plan_id: string; p_monthly_price: number; p_annual_price: number;
        p_reason: string; p_actor_user_id?: string | null; p_actor_email?: string | null;
      }; Returns: MasterLicensePrice };
      master_admin_get_license_management: { Args: { p_society_id: string }; Returns: MasterLicenseManagement };
      master_admin_grant_license: { Args: {
        p_society_id: string; p_license_plan_id: string;
        p_license_kind: "MONTHLY" | "ANNUAL" | "PROMOTIONAL_3" | "PROMOTIONAL_6" | "PROMOTIONAL_12";
        p_requested_start?: string | null; p_paid_on?: string | null;
        p_payment_method?: "BANK_TRANSFER" | "CASH" | "OTHER" | null;
        p_payment_reference?: string | null; p_reason?: string | null;
        p_internal_note?: string | null; p_allow_repeat_promotion?: boolean;
        p_actor_user_id?: string | null; p_actor_email?: string | null;
      }; Returns: { license_period_id: string; payment_id: string | null; valid_from: string; valid_until: string; plan_name: string; source: string } };
      master_admin_get_society_detail: { Args: { p_society_id: string }; Returns: MasterSocietyDetail };
      master_admin_update_society: { Args: {
        p_society_id: string;
        p_values: {
          name: string;
          address: string;
          city: string;
          postal_code: string | null;
          country: string;
          pib: string;
          registration_number: string;
          bank_account: string | null;
        };
      }; Returns: Society };
      master_admin_reject_president_request: { Args: {
        p_request_id: string;
        p_reason: string;
      }; Returns: {
        request_id: string;
        status: "REJECTED";
        reason: string | null;
      } };
      master_admin_set_society_status: { Args: {
        p_society_id: string; p_new_status: "ACTIVE" | "SUSPENDED"; p_reason: string;
        p_actor_user_id?: string | null; p_actor_email?: string | null;
      }; Returns: { society_id: string; old_status: string; new_status: string; suspension_id: string } };
      finance_record_payment: { Args: {
        p_society_id: string; p_amount: number; p_currency: string;
        p_payment_method: "CASH" | "BANK_TRANSFER";
        p_allocations: Array<{ obligation_id: string; amount: number }>;
        p_credit_to_person_id: string | null; p_credit_use_person_id: string | null;
        p_credit_use_amount: number; p_actor_user_id: string | null;
        p_actor_member_id: string;
      }; Returns: FinancePayment };
      finance_void_payment: { Args: {
        p_payment_id: string; p_reason: string; p_actor_user_id: string | null;
        p_actor_member_id: string;
      }; Returns: FinancePayment };
      finance_record_refund: { Args: {
        p_society_id: string; p_person_id: string; p_amount: number; p_currency: string;
        p_refund_method: "CASH" | "BANK_TRANSFER"; p_reason: string; p_actor_member_id: string;
      }; Returns: FinanceRefund };
      finance_void_refund: { Args: {
        p_refund_id: string; p_reason: string; p_actor_member_id: string;
      }; Returns: FinanceRefund };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};

let supabaseClient: SupabaseClient<Database> | null = null;

export function getSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      "Supabase podešavanja nisu pronađena. Podesite NEXT_PUBLIC_SUPABASE_URL i NEXT_PUBLIC_SUPABASE_ANON_KEY."
    );
  }

  if (!supabaseClient) {
    supabaseClient = createClient<Database>(supabaseUrl, supabaseAnonKey);
  }

  return supabaseClient;
}
