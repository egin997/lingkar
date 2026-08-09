# Deployment

## Supabase

1. Create isolated dev, staging, and production projects with matching Postgres major versions.
2. Link dev explicitly: `npx supabase link --project-ref <ref>`.
3. Preview with `npx supabase db push --dry-run`, review, then `npx supabase db push`.
4. Push reviewed Auth config with `npx supabase config push --project-ref <ref>`; confirm public and
   anonymous signup remain disabled before issuing invitations.
5. Run pgTAP and database advisors/lint before promotion. Never include seed in production.
6. Configure exact auth redirects, custom SMTP, backups/PITR, network restrictions, and alerts.

The manual `remote-database-audit` GitHub Actions workflow runs the exact linked pgTAP gate on a
Docker-capable hosted runner. Add `SUPABASE_ACCESS_TOKEN` as a repository Actions secret; never put
the token in workflow YAML, logs, committed env files, or pull requests. The workflow is pinned to
the owner-confirmed disposable project ref and performs no reset.

Operator invitations use `auth.admin.inviteUserByEmail` only from a trusted server/operations
environment. Use the `/auth/confirm?next=/auth/update-password?from=invite` redirect and never place
the Supabase secret key in a `NEXT_PUBLIC_*` variable.

## Cloudflare Workers

1. Copy `.dev.vars.example` to `.dev.vars` for local preview.
2. Run `npm run check` and `npm run cf:build`.
3. Run `npm run cf:smoke` to verify `/`, `/api/health`, and required security headers in `workerd`.
4. Run `npm run cf:dry-run` to validate the final Wrangler bundle without deploying it.
5. Configure build variables/secrets in Cloudflare, then run `npm run cf:deploy` from CI.
6. Attach the custom domain, WAF/rate limits, access logs, and rollback policy.

Deployment is not considered verified until the real Worker URL and hosted Supabase migration are
tested. This repository deliberately contains no account credentials.
