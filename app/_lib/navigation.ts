import type { TestRole } from "./testRoles";

export type MenuItem = {
  label: string;
  href: string;
  permissionKey: string;
};

export const MENU_ITEMS: MenuItem[] = [
  { label: "Dashboard", href: "/dashboard", permissionKey: "dashboard.view" },
  { label: "Društva", href: "/drustva", permissionKey: "drustva.view" },
  {
    label: "Zahtevi na čekanju",
    href: "/zahtevi-na-cekanju",
    permissionKey: "zahtevi.view"
  },
  {
    label: "Podešavanja sistema",
    href: "/podesavanja-sistema",
    permissionKey: "sistem.settings.view"
  },
  {
    label: "Moje sekcije",
    href: "/moje-sekcije",
    permissionKey: "sekcije.view"
  },
  { label: "Prisustvo", href: "/prisustvo", permissionKey: "prisustvo.view" },
  { label: "Članovi", href: "/clanovi", permissionKey: "clanovi.view" },
  { label: "Finansije", href: "/finansije", permissionKey: "finansije.view" },
  { label: "Garderoba", href: "/garderoba", permissionKey: "garderoba.view" },
  { label: "Izveštaji", href: "/izvestaji", permissionKey: "izvestaji.view" },
  { label: "Koncerti", href: "/koncerti", permissionKey: "koncerti.view" },
  {
    label: "Podešavanja",
    href: "/podesavanja",
    permissionKey: "organizacija.settings.view"
  },
  { label: "Moja deca", href: "/moja-deca", permissionKey: "deca.view" },
  { label: "Moji podaci", href: "/moji-podaci", permissionKey: "profile.view" }
];

export const ROLE_MENU_LABELS: Record<TestRole, string[]> = {
  "Master admin": [
    "Dashboard",
    "Društva",
    "Zahtevi na čekanju",
    "Podešavanja sistema"
  ],
  Predsednik: [
    "Dashboard",
    "Moje sekcije",
    "Prisustvo",
    "Članovi",
    "Finansije",
    "Garderoba",
    "Izveštaji",
    "Koncerti",
    "Podešavanja",
    "Moji podaci"
  ],
  UR: [
    "Dashboard",
    "Moje sekcije",
    "Prisustvo",
    "Članovi",
    "Koncerti",
    "Moji podaci"
  ],
  Blagajnik: [
    "Dashboard",
    "Članovi",
    "Finansije",
    "Izveštaji",
    "Moji podaci"
  ],
  Sekretar: ["Dashboard", "Članovi", "Izveštaji", "Koncerti", "Moji podaci"],
  Član: ["Moje sekcije", "Koncerti", "Moji podaci"],
  Roditelj: ["Moja deca", "Prisustvo", "Finansije", "Moji podaci"]
};

export function getMenuItemsForRole(role: TestRole) {
  const allowedLabels = ROLE_MENU_LABELS[role];

  return allowedLabels
    .map((label) => MENU_ITEMS.find((item) => item.label === label))
    .filter((item): item is MenuItem => Boolean(item));
}
