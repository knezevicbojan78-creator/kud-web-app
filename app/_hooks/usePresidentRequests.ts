"use client";

import { useEffect, useMemo, useState } from "react";

import {
  getSupabaseClient,
  type PresidentRegistration,
  type RegistrationStatus
} from "../_lib/supabaseClient";

type UsePresidentRequestsOptions = {
  status: RegistrationStatus;
  searchFields: ReadonlyArray<keyof PresidentRegistration>;
  loadErrorMessage: string;
  rlsErrorMessage?: string;
};

function isRlsError(error: { code?: string; message: string }) {
  const message = error.message.toLowerCase();
  return error.code === "42501" ||
    message.includes("row-level security") ||
    message.includes("permission denied");
}

export function usePresidentRequests({
  status,
  searchFields,
  loadErrorMessage,
  rlsErrorMessage
}: UsePresidentRequestsOptions) {
  const [requests, setRequests] = useState<PresidentRegistration[]>([]);
  const [query, setQuery] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    async function loadRequests() {
      setIsLoading(true);
      setErrorMessage("");

      try {
        const { data, error } = await getSupabaseClient().rpc(
          "master_admin_get_president_requests",
          { p_status: status }
        );

        if (error) {
          setErrorMessage(
            rlsErrorMessage && isRlsError(error)
              ? rlsErrorMessage
              : loadErrorMessage
          );
          setRequests([]);
          return;
        }

        setRequests(data ?? []);
      } catch (error) {
        setErrorMessage(
          error instanceof Error
            ? error.message
            : "Došlo je do greške pri učitavanju zahteva."
        );
      } finally {
        setIsLoading(false);
      }
    }

    void loadRequests();
  }, [loadErrorMessage, rlsErrorMessage, status]);

  const visibleRequests = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase("sr-Latn");
    if (!normalizedQuery) return requests;

    return requests.filter((request) =>
      searchFields
        .map((field) => request[field] ?? "")
        .join(" ")
        .toLocaleLowerCase("sr-Latn")
        .includes(normalizedQuery)
    );
  }, [query, requests, searchFields]);

  return {
    requests,
    visibleRequests,
    query,
    setQuery,
    isLoading,
    errorMessage
  };
}
