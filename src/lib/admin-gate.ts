// Signed, short-lived header the proxy attaches when a request arrived through the secret admin path.
// It is an obscurity layer ONLY — real authorization is always re-checked in lib/auth/authorize.ts.
export const ADMIN_GATE_HEADER = "x-psh-admin-gate";
export const INTERNAL_ADMIN_PREFIX = "/studio-internal";
const MAX_AGE_MS = 30_000;

const enc = new TextEncoder();
async function hmacHex(secret: string, msg: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(msg)));
  return Array.from(sig, (b) => b.toString(16).padStart(2, "0")).join("");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function signGate(secret: string, now = Date.now()): Promise<string> {
  const ts = String(now);
  return `${ts}.${await hmacHex(secret, ts)}`;
}

export async function verifyGate(secret: string, value: string | null | undefined, now = Date.now()): Promise<boolean> {
  if (!value) return false;
  const [ts, mac, ...rest] = value.split(".");
  if (!ts || !mac || rest.length > 0 || !/^\d{10,16}$/.test(ts)) return false;
  const age = now - Number(ts);
  if (age < 0 || age > MAX_AGE_MS) return false;
  return safeEqual(mac, await hmacHex(secret, ts));
}
