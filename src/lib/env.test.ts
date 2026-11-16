import { afterEach, describe, expect, it } from "vitest";
import { adminGateSecret, adminPanelPath, publicEnv } from "./env";

const saved = { ...process.env };
afterEach(() => { process.env = { ...saved }; });

describe("adminPanelPath", () => {
  it("is null (admin disabled) when unset or weak", () => {
    delete process.env.ADMIN_PANEL_PATH;
    expect(adminPanelPath()).toBeNull();
    for (const weak of ["admin", "dashboard", "short-secret", "has/slash-aaaaaaaaaaaaaaaa", "has space aaaaaaaaaaaa"]) {
      process.env.ADMIN_PANEL_PATH = weak;
      expect(adminPanelPath()).toBeNull();
    }
  });
  it("accepts a long url-safe slug", () => {
    process.env.ADMIN_PANEL_PATH = "k9Zq-Tn4_vWx8Lp2Rb7d";
    expect(adminPanelPath()).toBe("k9Zq-Tn4_vWx8Lp2Rb7d");
  });
});

describe("adminGateSecret", () => {
  it("requires at least 32 chars", () => {
    process.env.ADMIN_GATE_SECRET = "short";
    expect(adminGateSecret()).toBeNull();
    process.env.ADMIN_GATE_SECRET = "x".repeat(32);
    expect(adminGateSecret()).toBe("x".repeat(32));
  });
});

describe("publicEnv", () => {
  it("throws on missing/invalid Supabase config", () => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    expect(() => publicEnv()).toThrow();
  });
});
