"use client";

export default function GlobalError({ reset }: { reset: () => void }) {
  return (
    <html lang="id">
      <body>
        <main className="shell">
          <section className="hero">
            <p className="eyebrow">Ada gangguan</p>
            <h1>LINGKAR lagi tersendat.</h1>
            <button type="button" onClick={reset}>
              Coba lagi
            </button>
          </section>
        </main>
      </body>
    </html>
  );
}
