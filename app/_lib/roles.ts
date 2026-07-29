export const APPLICATION_ROLES = [
  "Master admin",
  "Predsednik",
  "UR",
  "Blagajnik",
  "Sekretar",
  "Član",
  "Roditelj"
] as const;

export type ApplicationRole = (typeof APPLICATION_ROLES)[number];
