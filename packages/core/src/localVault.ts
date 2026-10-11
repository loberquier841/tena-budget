const encoder = new TextEncoder();
const decoder = new TextDecoder();
const KDF_ITERATIONS = 310_000;
const ENCRYPTED_PREFIX = "tena:v1:";
const CHECK_TEXT = "TENΛ Budget local vault key check v1";

// Delay constants for failed unlock attempts (in ms)
const FAILED_ATTEMPT_BASE_DELAY = 1000; // 1 second
const FAILED_ATTEMPT_MAX_DELAY = 30000; // 30 seconds

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export interface LocalVaultMetadata {
  id: "primary";
  version: 1;
  kdf: "PBKDF2-SHA-256";
  iterations: number;
  salt: string;
  checkIv: string;
  checkCiphertext: string;
  createdAt: Date;
  migrationState: "pending" | "complete";
  failedAttempts?: number;
  lastFailedAttempt?: number;
}

let activeKey: CryptoKey | undefined;

function webCrypto(): Crypto {
  if (!globalThis.crypto?.subtle || !globalThis.crypto.getRandomValues) throw new Error("LOCAL_VAULT_CRYPTO_UNAVAILABLE");
  return globalThis.crypto;
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, character => character.charCodeAt(0));
}

function randomBytes(size: number): Uint8Array {
  return webCrypto().getRandomValues(new Uint8Array(size));
}

function asBufferSource(bytes: Uint8Array): ArrayBuffer { return bytes.slice().buffer as ArrayBuffer; }

async function deriveKey(passphrase: string, salt: Uint8Array, iterations: number): Promise<CryptoKey> {
  const material = await webCrypto().subtle.importKey("raw", encoder.encode(passphrase), "PBKDF2", false, ["deriveKey"]);
  return webCrypto().subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", salt: asBufferSource(salt), iterations }, material,
    { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"],
  );
}

function requirePassphrase(passphrase: string): void {
  if (passphrase.trim().length < 12) throw new Error("LOCAL_VAULT_PASSPHRASE_TOO_SHORT");
}

export async function createLocalVault(passphrase: string): Promise<{ metadata: LocalVaultMetadata; key: CryptoKey }> {
  requirePassphrase(passphrase);
  const salt = randomBytes(16);
  const key = await deriveKey(passphrase, salt, KDF_ITERATIONS);
  const checkIv = randomBytes(12);
  const checkCiphertext = await webCrypto().subtle.encrypt({ name: "AES-GCM", iv: asBufferSource(checkIv) }, key, encoder.encode(CHECK_TEXT));
  return {
    key,
    metadata: {
      id: "primary", version: 1, kdf: "PBKDF2-SHA-256", iterations: KDF_ITERATIONS,
      salt: toBase64(salt), checkIv: toBase64(checkIv), checkCiphertext: toBase64(new Uint8Array(checkCiphertext)),
       failedAttempts: 0,
       lastFailedAttempt: 0,
      createdAt: new Date(), migrationState: "pending",
       failedAttempts: 0,
       lastFailedAttempt: 0,
       failedAttempts: 0,
    },
  };
}

export async function unlockLocalVault(metadata: LocalVaultMetadata, passphrase: string): Promise<CryptoKey> {
  requirePassphrase(passphrase);
  if (metadata.version !== 1 || metadata.kdf !== "PBKDF2-SHA-256" || metadata.iterations < 100_000) throw new Error("LOCAL_VAULT_METADATA_UNSUPPORTED");
  const key = await deriveKey(passphrase, fromBase64(metadata.salt), metadata.iterations);
  try {
    const clear = await webCrypto().subtle.decrypt({ name: "AES-GCM", iv: asBufferSource(fromBase64(metadata.checkIv)) }, key, asBufferSource(fromBase64(metadata.checkCiphertext)));
    if (decoder.decode(clear) !== CHECK_TEXT) throw new Error("invalid key check");
  } catch {
    throw new Error("LOCAL_VAULT_PASSWORD_INVALID");
  }
  return key;
}

export function activateLocalVault(key: CryptoKey): void { activeKey = key; }
export function lockLocalVault(): void { activeKey = undefined; }
export function isLocalVaultUnlocked(): boolean { return activeKey !== undefined; }

export async function encryptLocalValue(value: unknown, context?: string): Promise<string> {
  if (!activeKey) throw new Error("LOCAL_VAULT_LOCKED");
  const iv = randomBytes(12);
  const algorithm: AesGcmParams = { name: "AES-GCM", iv: asBufferSource(iv) };
  if (context) algorithm.additionalData = encoder.encode(context);
  const ciphertext = await webCrypto().subtle.encrypt(algorithm, activeKey, encoder.encode(JSON.stringify(value)));
  return `${ENCRYPTED_PREFIX}${toBase64(iv)}:${toBase64(new Uint8Array(ciphertext))}`;
}

export async function decryptLocalValue<T>(value: unknown, context?: string): Promise<T> {
  if (typeof value !== "string" || !value.startsWith(ENCRYPTED_PREFIX)) return value as T;
  if (!activeKey) throw new Error("LOCAL_VAULT_LOCKED");
  const [iv, ciphertext, ...rest] = value.slice(ENCRYPTED_PREFIX.length).split(":");
  if (!iv || !ciphertext || rest.length) throw new Error("LOCAL_VAULT_CIPHERTEXT_INVALID");
  try {
    const algorithm: AesGcmParams = { name: "AES-GCM", iv: asBufferSource(fromBase64(iv)) };
    if (context) algorithm.additionalData = encoder.encode(context);
    const clear = await webCrypto().subtle.decrypt(algorithm, activeKey, asBufferSource(fromBase64(ciphertext)));
    return JSON.parse(decoder.decode(clear)) as T;
  } catch {
    throw new Error("LOCAL_VAULT_DATA_AUTHENTICATION_FAILED");
  }
}

export function isEncryptedLocalValue(value: unknown): boolean {
  return typeof value === "string" && value.startsWith(ENCRYPTED_PREFIX);
}
