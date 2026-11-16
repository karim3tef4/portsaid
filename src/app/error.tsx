"use client";
export default function ErrorPage({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="mx-auto max-w-xl px-4 py-24 text-center" role="alert">
      <h1 className="text-2xl font-bold text-secondary">حدث خطأ غير متوقع</h1>
      <p className="mt-2 text-ink-muted">Something went wrong. Please try again.</p>
      <button onClick={reset} className="mt-6 rounded-card bg-primary px-5 py-2.5 font-medium text-white">إعادة المحاولة</button>
    </div>
  );
}
