import assert from "node:assert/strict";
import test from "node:test";

import {
  excludePendingMemberships,
  getInvitationStatusLabel,
  getMissingPendingInvitationFields,
  getMissingPendingPersonalFields,
  getPendingCandidateStage,
  isPendingMemberMinor
} from "../../app/_lib/pendingMemberImports.ts";

test("članstvo kandidata u čekanju se ne prikazuje među članovima", () => {
  const members = [{ id: "active-1" }, { id: "pending-1" }];
  const candidates = [candidate({ society_member_id: "pending-1" })];
  assert.deepEqual(excludePendingMemberships(members, candidates), [
    { id: "active-1" }
  ]);
});

function candidate(overrides = {}) {
  return {
    id: "candidate-1",
    profile: { first_name: "Mila", last_name: "Milić", email: "mila@example.com" },
    source_row: 6,
    source_file_name: "import.xlsx",
    created_at: "2026-07-31T10:00:00Z",
    member_invitation_status: null,
    guardian_invitation_status: null,
    invitation_last_saved_at: null,
    draft: {},
    missing_fields: [],
    ...overrides
  };
}

test("statusi poziva imaju stabilne korisničke oznake", () => {
  assert.equal(getInvitationStatusLabel("INVITED"), "Link poslat");
  assert.equal(getInvitationStatusLabel("SUBMITTED"), "Podaci poslati");
  assert.equal(getInvitationStatusLabel(null), "Link nije poslat");
});

test("kandidat bez poziva čeka slanje linka", () => {
  assert.equal(getPendingCandidateStage(candidate()).tone, "not-sent");
});

test("kompletno poslati podaci su spremni za potvrdu", () => {
  const stage = getPendingCandidateStage(candidate({
    member_invitation_status: "SUBMITTED"
  }));

  assert.equal(stage.tone, "submitted");
  assert.equal(stage.label, "Spreman za potvrdu");
});

test("telefon maloletnog člana nije lično blokirajuće polje", () => {
  const stage = getPendingCandidateStage(candidate({
    member_invitation_status: "SUBMITTED",
    draft: { is_minor_member: true },
    missing_fields: ["phone"]
  }));

  assert.equal(stage.tone, "submitted");
});

test("datum rođenja određuje maloletnost i bez sačuvane oznake", () => {
  assert.equal(isPendingMemberMinor({ birth_date: "2015-04-15" }), true);
  assert.equal(isPendingMemberMinor({ birth_date: "1990-04-15" }), false);
});

test("pre slanja linka punoletnom su dovoljni identitet i kontakt", () => {
  assert.deepEqual(getMissingPendingInvitationFields({
    first_name: "Ana",
    last_name: "Anić",
    email: "ana@example.com",
    phone: "060123456"
  }), []);
});

test("pre slanja linka maloletnom su dovoljni dete i kontakt roditelja", () => {
  assert.deepEqual(getMissingPendingInvitationFields({
    first_name: "Mila",
    last_name: "Milić",
    birth_date: "2015-04-15",
    guardian1: {
      first_name: "Ana",
      last_name: "Anić",
      email: "ana@example.com",
      phone: "060123456"
    }
  }), []);
});

test("maloletnom kandidatu se proveravaju podaci prvog staratelja", () => {
  const missing = getMissingPendingPersonalFields({
    is_minor_member: true,
    first_name: "Mila",
    last_name: "Milić",
    gender: "Žensko",
    birth_date: "2015-04-15",
    email: "",
    address: "Glavna 1",
    city: "Novi Sad",
    postal_code: "21000",
    country: "Srbija",
    guardian1: { first_name: "Ana" }
  });

  assert.deepEqual(missing, [
    "prezime roditelja/staratelja",
    "email roditelja/staratelja",
    "telefon roditelja/staratelja"
  ]);
});
