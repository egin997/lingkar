# Identity operations

## Closed-beta invariant

Public email signup and anonymous signup are disabled in `supabase/config.toml` and must be pushed to
every hosted environment. Removing signup UI is not considered access control. New identities enter
through Supabase Admin invitations issued from a trusted operator environment.

## User flows

1. An operator invites an approved email and redirects it to
   `/auth/confirm?next=/auth/update-password?from=invite`.
2. `/auth/confirm` exchanges a PKCE code or verifies a token hash, writes SSR cookies, and marks the
   response private/non-cacheable.
3. The invited user sets a strong password and completes onboarding.
4. Onboarding records `18plus-v1` and `closed-beta-v1` timestamps without collecting date of birth.
5. Subsequent requests refresh sessions through Next.js `proxy.ts`; protected pages independently
   verify claims and rely on database RLS for row authorization.
6. Password recovery returns the same public response for registered and unregistered emails.

## Authorization matrix

| Resource/action | anon | owner | other user | moderator metadata |
| --- | --- | --- | --- | --- |
| Read `profiles` | yes | yes | yes | yes |
| Insert/update own `profiles` | no | yes | no | own row only |
| Read/update `identity_accounts` | no | own row | own row only | own row only |
| Delete identity rows | no | no | no | no |
| Execute onboarding RPC | no | yes | yes, for own row | own row only |
| Execute private Auth trigger | no | no | no | no |

Moderation authorization intentionally starts in Phase 2. A user-editable metadata claim never
grants broader Identity access.
