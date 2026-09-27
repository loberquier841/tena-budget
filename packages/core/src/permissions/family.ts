
import { can, assertCan, Role, requiresOwnerConfirmation } from "./permissions";

// Logique famille / invitation / devices - 100% serveur

export interface FamilyMemberRow {
  userId: string;
  familyId: string;
  role: Role;
}

export function createFamily(ownerUserId: string, name: string) {
  // owner devient owner
  const familyId = `fam_${Date.now()}`;
  const member: FamilyMemberRow = { userId: ownerUserId, familyId, role: "owner" };
  return { familyId, member };
}

export function generateInvitationCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sans O0I1
  let code = "";
  for (let i=0;i<6;i++) code += chars[Math.floor(Math.random()*chars.length)];
  return code;
}

export interface Invitation {
  id: string;
  familyId: string;
  code: string;
  role: Role;
  createdByUserId: string;
  expiresAt: Date;
  usedAt?: Date;
}

export function createInvitation(familyId: string, createdByUserId: string, role: Role, creatorRole: Role): Invitation {
  assertCan(creatorRole, "family:delete" as any); // seul owner/admin peut inviter - on vérifie
  if (role === "owner") throw new Error("INVITE_OWNER_FORBIDDEN: on ne peut inviter owner");
  if (!can(creatorRole, "budget:write")) throw new Error("PERMISSION_DENIED: invitation");
  return {
    id: `inv_${Date.now()}`,
    familyId,
    code: generateInvitationCode(),
    role,
    createdByUserId,
    expiresAt: new Date(Date.now() + 7*24*60*60*1000), // 7 jours
  };
}

export function validateInvitationCode(code: string, invitations: Invitation[]): Invitation {
  const inv = invitations.find(i => i.code === code);
  if (!inv) throw new Error("INVITATION_NOT_FOUND");
  if (inv.usedAt) throw new Error("INVITATION_ALREADY_USED");
  if (inv.expiresAt < new Date()) throw new Error("INVITATION_EXPIRED");
  return inv;
}

// === LIMITE 3 APPAREILS ===

export interface DeviceRow {
  id: string;
  familyId: string;
  userId: string;
  lastSeenAt: Date;
}

export const MAX_DEVICES_PER_USER = 3;

export function canRegisterDevice(existingDevices: DeviceRow[], userId: string, familyId: string): { allowed: boolean; reason?: string } {
  const userDevices = existingDevices.filter(d => d.userId === userId && d.familyId === familyId);
  if (userDevices.length >= MAX_DEVICES_PER_USER) {
    return { allowed: false, reason: `DEVICE_LIMIT_REACHED: ${userDevices.length}/${MAX_DEVICES_PER_USER}` };
  }
  return { allowed: true };
}

export function registerDevice(existingDevices: DeviceRow[], input: { familyId: string; userId: string }): DeviceRow[] {
  const check = canRegisterDevice(existingDevices, input.userId, input.familyId);
  if (!check.allowed) throw new Error(check.reason);
  const newDevice: DeviceRow = { id: `dev_${Date.now()}`, familyId: input.familyId, userId: input.userId, lastSeenAt: new Date() };
  return [...existingDevices, newDevice];
}

export function revokeDevice(devices: DeviceRow[], deviceId: string, requesterRole: Role, requesterUserId: string): DeviceRow[] {
  const target = devices.find(d => d.id === deviceId);
  if (!target) throw new Error("DEVICE_NOT_FOUND");
  // owner peut révoquer tout, user peut révoquer ses propres devices
  if (requesterRole !== "owner" && target.userId !== requesterUserId) {
    throw new Error("PERMISSION_DENIED: revoke device");
  }
  return devices.filter(d => d.id !== deviceId);
}
