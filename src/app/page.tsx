import Link from "next/link";

import { getFoundationStatus } from "@/modules/system/application/get-foundation-status";

export default function Home() {
  const foundation = getFoundationStatus();

  return (
    <main className="shell">
      <nav className="nav" aria-label="Navigasi utama">
        <Link className="wordmark" href="/" aria-label="LINGKAR beranda">
          lingkar<span>.</span>
        </Link>
        <span className="beta-pill">closed beta · 18+</span>
      </nav>

      <section className="hero" aria-labelledby="hero-title">
        <p className="eyebrow">Indonesia-first · community-first</p>
        <h1 id="hero-title">
          Bukan tempat pamer ke semua orang.
          <span> Tempat nyambung sama orang yang tepat.</span>
        </h1>
        <p className="lede">
          LINGKAR dibangun untuk obrolan yang punya konteks: komunitas kecil,
          reputasi yang relevan, dan feed yang tetap lo kendalikan.
        </p>
        <div className="promise-row" aria-label="Prinsip produk">
          <span>Tanpa AI-slop</span>
          <span>Moderasi kuat</span>
          <span>Kontrol feed</span>
        </div>
        <div className="hero-actions">
          <Link className="button-primary" href="/auth/sign-in">Masuk dengan undangan</Link>
          <span>Pendaftaran publik belum dibuka.</span>
        </div>
      </section>

      <section className="foundation" aria-labelledby="foundation-title">
        <div>
          <p className="eyebrow">{foundation.phase}</p>
          <h2 id="foundation-title">Fondasi dulu. Fitur menyusul.</h2>
        </div>
        <ol className="gate-list">
          {foundation.gates.map((gate) => (
            <li key={gate.id}>
              <span aria-hidden="true">{gate.status === "ready" ? "✓" : "○"}</span>
              <div>
                <strong>{gate.label}</strong>
                <small>{gate.evidence}</small>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <footer>
        <p>LINGKAR belum menerima pendaftaran publik.</p>
        <Link href="/api/health">status sistem</Link>
      </footer>
    </main>
  );
}
