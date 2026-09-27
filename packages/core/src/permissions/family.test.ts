
import { describe, it, expect } from "vitest";
import { createInvitation, validateInvitationCode, generateInvitationCode, canRegisterDevice, registerDevice, MAX_DEVICES_PER_USER } from "./family";

describe("Invitations", () => {
  it("génère un code 6 chars sans ambiguïté", () => {
    const code = generateInvitationCode();
    expect(code).toMatch(/^[A-Z0-9]{6}$/);
  });
  it("crée invitation admin", () => {
    const inv = createInvitation("fam1", "owner1", "admin", "owner");
    expect(inv.role).toBe("admin");
    expect(inv.code.length).toBe(6);
  });
  it("refuse invitation owner", () => {
    expect(() => createInvitation("fam1", "owner1", "owner" as any, "owner")).toThrow();
  });
  it("valide code ok", () => {
    const inv = createInvitation("fam1", "owner1", "member", "owner");
    const found = validateInvitationCode(inv.code, [inv]);
    expect(found.id).toBe(inv.id);
  });
  it("refuse code expiré", () => {
    const inv = createInvitation("fam1", "owner1", "member", "owner");
    inv.expiresAt = new Date(Date.now() - 1000);
    expect(() => validateInvitationCode(inv.code, [inv])).toThrow("EXPIRED");
  });
});

describe("Devices limite 3", () => {
  it("autorise 3 appareils", () => {
    let devices: any[] = [];
    for (let i=0;i<3;i++) {
      devices = registerDevice(devices, { familyId: "fam1", userId: "u1" });
    }
    expect(devices.length).toBe(3);
    const check = canRegisterDevice(devices, "u1", "fam1");
    expect(check.allowed).toBe(false);
  });
  it("refuse 4ème appareil", () => {
    let devices: any[] = [];
    for (let i=0;i<3;i++) devices = registerDevice(devices, { familyId: "fam1", userId: "u1" });
    expect(() => registerDevice(devices, { familyId: "fam1", userId: "u1" })).toThrow("DEVICE_LIMIT");
  });
});
