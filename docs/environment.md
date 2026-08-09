# Environment contract

| Variable | Scope | Required | Notes |
| --- | --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | browser + server | yes from Phase 1 | HTTPS project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | browser + server | yes from Phase 1 | publishable key; safe only with correct RLS |
| `SUPABASE_SECRET_KEY` | server only | yes from Phase 2 | prefer `sb_secret_*`; legacy service-role is migration fallback only |
| `NEXT_PUBLIC_SITE_URL` | browser + server | yes | canonical app origin |
| `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` | server only | yes in shared/multi-instance environments | stable 32-byte base64 key; never expose as `NEXT_PUBLIC_*` |

Local Next.js reads `.env.local`. Cloudflare preview reads `.dev.vars`; production secrets/vars are
set in the Cloudflare dashboard or `wrangler secret put`. Never commit either file. Supabase CLI
config uses `env(NAME)` for any secret value.

Hosted Supabase auth must allow only exact production/staging callback origins. Production email
requires custom SMTP; the local Mailpit service is development-only. Public signup and anonymous
signup must remain disabled. Invitations are issued only from a trusted operator environment with a
Supabase secret key; that key belongs only in the server runtime and never in its client bundle.

Phase 1 callback contract:

- invite and recovery redirect to `/auth/confirm` using PKCE code or `token_hash` + `type`;
- authenticated invite acceptance continues to `/auth/update-password` and then `/onboarding`;
- production and staging use separate exact callback allowlists;
- any response that refreshes Auth cookies is `private, no-store`.
