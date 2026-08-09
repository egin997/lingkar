# Environment contract

| Variable | Scope | Required | Notes |
| --- | --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | browser + server | yes from Phase 1 | HTTPS project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | browser + server | yes from Phase 1 | publishable key; safe only with correct RLS |
| `NEXT_PUBLIC_SITE_URL` | browser + server | yes | canonical app origin |

Local Next.js reads `.env.local`. Cloudflare preview reads `.dev.vars`; production secrets/vars are
set in the Cloudflare dashboard or `wrangler secret put`. Never commit either file. Supabase CLI
config uses `env(NAME)` for any secret value.

Hosted Supabase auth must allow only exact production/staging callback origins. Production email
requires custom SMTP; the local Mailpit service is development-only.
