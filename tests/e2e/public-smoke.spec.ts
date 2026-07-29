import { expect, test } from "@playwright/test";

test("stranica za prijavu je dostupna", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByPlaceholder("ime@email.com")).toBeVisible();
  await expect(page.getByPlaceholder("Unesite lozinku")).toBeVisible();
  await expect(page.getByRole("button", { name: "Prijavi se" })).toBeVisible();
});

test("zaštićena stranica vraća neprijavljenog korisnika na prijavu", async ({
  page
}) => {
  await page.goto("/clanovi");
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("button", { name: "Prijavi se" })).toBeVisible();
  await expect(page.locator("nav")).toHaveCount(0);
});

test("javna dopuna podataka je izolovana od glavnog menija", async ({
  page
}) => {
  await page.goto("/dopuna-podataka/codex-nepostojeci-test-token");
  await expect(page.getByText("Učitavanje obrasca...")).toBeVisible();
  await expect(page.locator("nav")).toHaveCount(0);
});
