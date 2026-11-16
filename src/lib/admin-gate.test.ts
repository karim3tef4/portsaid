import { describe, expect, it } from "vitest";
import { signGate, verifyGate } from "./admin-gate";

const SECRET = "0123456789abcdef0123456789abcdef";

describe("admin gate header", () => {
  it("accepts a freshly signed value", async () => {
    expect(await verifyGate(SECRET, await signGate(SECRET))).toBe(true);
  });
  it("rejects missing / malformed values", async () => {
    for (const v of [null, undefined, "", "abc", "123.abc", "x.y.z", `${Date.now()}.`]) {
      expect(await verifyGate(SECRET, v)).toBe(false);
    }
  });
  it("rejects a value signed with another secret", async () => {
    expect(await verifyGate(SECRET, await signGate("f".repeat(32)))).toBe(false);
  });
  it("rejects a tampered timestamp", async () => {
    const [ts, mac] = (await signGate(SECRET)).split(".");
    expect(await verifyGate(SECRET, `${Number(ts) + 1}.${mac}`)).toBe(false);
  });
  it("rejects expired and future-dated values", async () => {
    const now = Date.now();
    expect(await verifyGate(SECRET, await signGate(SECRET, now - 31_000), now)).toBe(false);
    expect(await verifyGate(SECRET, await signGate(SECRET, now + 5_000), now)).toBe(false);
    expect(await verifyGate(SECRET, await signGate(SECRET, now - 5_000), now)).toBe(true);
  });
});
