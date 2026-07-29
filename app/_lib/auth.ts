import { getSupabaseClient } from "./supabaseClient";

export const MASTER_ADMIN_EMAIL = "knezevic.bojan78@gmail.com";

export type AuthBootstrapStatus = {
  master_admin_active: boolean;
  master_admin_registration_available: boolean;
};

export type AuthSessionContext = {
  authenticated: boolean;
  user_id?: string;
  email?: string;
  email_confirmed: boolean;
  is_allowed_master_email?: boolean;
  is_master_admin: boolean;
  aal: "aal1" | "aal2";
  requires_master_mfa?: boolean;
};

export async function getAuthBootstrapStatus() {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase.rpc("auth_get_bootstrap_status");

  if (error) {
    throw error;
  }

  return data as AuthBootstrapStatus;
}

export async function getAuthSessionContext() {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase.rpc("auth_get_session_context");

  if (error) {
    throw error;
  }

  return data as AuthSessionContext;
}
