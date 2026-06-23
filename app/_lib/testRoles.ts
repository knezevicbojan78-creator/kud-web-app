export const TEST_ROLES = [
  "Master admin",
  "Predsednik",
  "UR",
  "Blagajnik",
  "Sekretar",
  "Član",
  "Roditelj"
] as const;

export type TestRole = (typeof TEST_ROLES)[number];

export const TEST_ROLE_STORAGE_KEY = "folkloras-test-role";

export const DEFAULT_TEST_ROLE: TestRole = "Master admin";
