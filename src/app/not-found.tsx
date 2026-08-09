import Link from "next/link";

export default function NotFound() {
  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">404 · di luar lingkaran</p>
        <h1>Halaman ini nggak ada.</h1>
        <p className="lede">Mungkin tautannya sudah berubah atau belum dibuka untuk beta.</p>
        <Link href="/">Balik ke beranda</Link>
      </section>
    </main>
  );
}
