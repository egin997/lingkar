import Link from "next/link";
import type { ReactNode } from "react";

interface AuthShellProps {
  readonly eyebrow: string;
  readonly title: string;
  readonly description: string;
  readonly message?: string | null;
  readonly children: ReactNode;
}

export function AuthShell({
  eyebrow,
  title,
  description,
  message,
  children,
}: AuthShellProps) {
  return (
    <main className="auth-shell">
      <nav className="auth-nav" aria-label="Navigasi autentikasi">
        <Link className="wordmark" href="/" aria-label="LINGKAR beranda">
          lingkar<span>.</span>
        </Link>
        <span className="beta-pill">undangan saja · 18+</span>
      </nav>
      <section className="auth-card" aria-labelledby="auth-title">
        <p className="eyebrow">{eyebrow}</p>
        <h1 id="auth-title">{title}</h1>
        <p className="lede">{description}</p>
        {message ? <p className="form-message" role="status">{message}</p> : null}
        {children}
      </section>
    </main>
  );
}
