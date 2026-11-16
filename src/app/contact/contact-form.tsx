"use client";
import { useActionState } from "react";
import { submitContact, type ContactState } from "./actions";

export interface ContactLabels { name: string; email: string; subject: string; message: string; send: string; sending: string; success: string; error: string; rate: string; invalid: string }

export function ContactForm({ labels }: { labels: ContactLabels }) {
  const [state, action, pending] = useActionState<ContactState, FormData>(submitContact, { status: "idle" });
  const field = "mt-1 w-full rounded-card border border-line bg-white px-3 py-2.5";
  const err = (k: "name" | "email" | "subject" | "message") => state.fieldErrors?.[k];
  return (
    <form action={action} className="mt-6 space-y-4" noValidate>
      {/* honeypot — hidden from people and assistive tech */}
      <div aria-hidden="true" className="absolute -start-[9999px] h-0 w-0 overflow-hidden">
        <label>Company<input name="company" tabIndex={-1} autoComplete="off" /></label>
      </div>
      <div><label htmlFor="name" className="font-medium">{labels.name}</label>
        <input id="name" name="name" required maxLength={120} autoComplete="name" aria-invalid={err("name")} className={field} /></div>
      <div><label htmlFor="email" className="font-medium">{labels.email}</label>
        <input id="email" name="email" type="email" required maxLength={254} autoComplete="email" dir="ltr" aria-invalid={err("email")} className={field} /></div>
      <div><label htmlFor="subject" className="font-medium">{labels.subject}</label>
        <input id="subject" name="subject" maxLength={200} className={field} /></div>
      <div><label htmlFor="message" className="font-medium">{labels.message}</label>
        <textarea id="message" name="message" required minLength={5} maxLength={5000} rows={6} aria-invalid={err("message")} className={field} /></div>
      <button type="submit" disabled={pending} className="rounded-card bg-primary px-6 py-2.5 font-medium text-white disabled:opacity-60">
        {pending ? labels.sending : labels.send}
      </button>
      <p role="status" aria-live="polite" className={state.status === "success" ? "text-green-700" : "text-red-700"}>
        {state.status === "success" && labels.success}
        {state.status === "error" && labels.error}
        {state.status === "rate" && labels.rate}
        {state.status === "invalid" && labels.invalid}
      </p>
    </form>
  );
}
