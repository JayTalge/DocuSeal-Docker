# DocuSeal-Docker

Patch sets and a build script for self-hosted [DocuSeal](https://github.com/docusealco/docuseal) instances. This repo contains only patches. The upstream code is not forked: `build.sh` clones an upstream release tag, applies one patch set with `git am` and builds the upstream `Dockerfile`, so the assets are rebuilt with the patched sources.

This is the Corresponding Source of the modified versions running at [sign.jason-talge.de](https://sign.jason-talge.de) (set `jt`) and [contract.dr50.de](https://contract.dr50.de) (set `brand`) (AGPL-3.0, section 13).

| Set | Based on | Used by | Branding |
|---|---|---|---|
| `patches/brand/` | 3.3.4 | contract.dr50.de | at runtime: `BRAND_*` env + a mounted brand pack |
| `patches/jt/` | 3.3.4 | sign.jason-talge.de | compiled in (Jason Talge) |

## Build

GitHub Actions (`.github/workflows/build.yml`) builds every set and publishes `ghcr.io/jaytalge/docuseal-<set>` with the tags `<version>-<commit>`, `<version>` and `latest`:

- daily against the latest DocuSeal release (auto-update), and on every change to `main`
- only after a smoke test (fresh Postgres: `/up`, `/setup`; `brand`: `/healthz/brand`, brand assets; `jt`: theme)
- if the patches do not apply to a new release, the run fails and `latest` stays on the last good image. Fix the patches (see Updating), then the next run publishes
- pull requests are built and tested without publishing

Watchtower can follow `:latest`. For a pinned deployment use `<version>-<commit>`.

Locally:

```sh
./build.sh brand 3.3.4 1     # -> local image docuseal-brand:3.3.4-1
./build.sh jt 3.3.4 1        # -> local image docuseal-jt:3.3.4-1
```

Use the image like `docuseal/docuseal` (same env, volumes and port 3000). The image only exists locally, so set `pull_policy: never` in Compose and exclude it from Watchtower.

## Set `brand`

| Patch | Content |
|---|---|
| 0001 | Runtime branding (`lib/brand.rb`): titles, meta/OG, favicons, PWA manifest, logos in navbar/forms/QR, landing page, mail footer with logo and legal links, PDF logos. Hides the DocuSeal console, "Ask AI" and GitHub links |
| 0002 | Dark daisyUI theme `brand` (`BRAND_THEME=brand`) plus `public/brand-base/brand-dark.css` for hard-coded light classes. PDF pages and the signature canvas stay white |
| 0003 | Hides Pro upsells (plans, console, SMS, SSO settings, pricing links). Pro features stay locked |
| 0004 | Audit trail and signed PDFs: header name, sign reason, PDF creator, band colour |
| 0005 | "Source code" link next to the DocuSeal attribution (`/source` redirects to `BRAND_SOURCE_URL`) |
| 0006 | Generic OpenID Connect login (authorization code + PKCE, no new gems) |
| 0007 | Per-IP rate limit for login and password reset, `TRUSTED_PROXIES` |
| 0008 | Self-check endpoint `/healthz/brand` |

Without any `BRAND_*`/`OIDC_*` variable the image behaves like upstream (light theme, neutral default pack in `public/brand/`).

### Environment

| Variable | Meaning |
|---|---|
| `BRAND_NAME` | Short name (titles, PDF header, mails). Setting it switches the branding on |
| `BRAND_PRODUCT_NAME` | Product name, e.g. "Welcome to …" (default `BRAND_NAME`) |
| `BRAND_COMPANY` | Legal entity in footers and mails |
| `BRAND_TAGLINE`, `BRAND_TITLE`, `BRAND_DESCRIPTION` | Landing page, page title, meta description |
| `BRAND_SUPPORT_EMAIL` | Replaces support@docuseal.com |
| `BRAND_IMPRINT_URL`, `BRAND_PRIVACY_URL`, `BRAND_TERMS_URL` | Footer links on the landing page and in mails (optional) |
| `BRAND_DEFAULT_LOCALE` | Language of pages without an account context (landing page, login), e.g. `de-DE` |
| `BRAND_THEME` | `brand` = dark theme, otherwise upstream light theme |
| `BRAND_THEME_COLOR` | `<meta name="theme-color">` and PWA colour |
| `BRAND_ASSET_VERSION` | Cache buster for `/brand/*` (raise it after changing the pack) |
| `BRAND_PDF_BAND_COLOR` | Hex colour of the audit trail top/bottom band |
| `BRAND_SOURCE_URL` | Corresponding Source link (default: this repo) |
| `BRAND_HEALTHZ_EXPECT` | e.g. `branding,oidc`: what `/healthz/brand` requires |
| `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` | Enable the SSO login (all three required) |
| `OIDC_BUTTON_LABEL` | Button text on the login page |
| `OIDC_SCOPES` | Default `openid email profile` |
| `OIDC_ALLOWED_GROUPS` | Comma separated. Empty = everyone the IdP lets through |
| `OIDC_GROUPS_CLAIM` | Default `groups` |
| `OIDC_CREATE_USERS` | Create users on first login (default `true`) |
| `OIDC_TRUST_EMAIL` | Accept the e-mail without `email_verified=true`. Only if users cannot change their e-mail at the IdP |
| `OIDC_ALLOW_PASSWORD_FOR_SSO_USERS` | Default `false`: SSO-linked users cannot use password login or reset |
| `TRUSTED_PROXIES` | Comma separated IPs/CIDRs of the reverse proxy |
| `LOGIN_RATE_LIMIT`, `LOGIN_RATE_PERIOD_MINUTES` | Default 10 attempts per 5 minutes per IP |

### Brand pack

Mount a directory over `/app/public/brand` (read-only). Files:

| File | Use |
|---|---|
| `logo.svg` | Wordmark for the theme background (navbar, landing, signing form) |
| `logo-light.svg` | Wordmark for light backgrounds |
| `icon.svg` | Square icon for the theme background (template builder, small logo) |
| `favicon.svg`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `og-image.png` | Browser/PWA icons, link preview |
| `pdf-logo.png` | Square logo in the audit trail header (on white) |
| `stamp-logo.png` | Grey diagonal watermark of the signature stamp (506x340) |
| `mail-logo.png` | Optional, logo in the mail footer (on white, ~356x76) |
| `brand.css` | Theme colours: daisyUI variables as HSL triples under `html[data-theme=brand]`, optional `--brand-input`, `--brand-muted` … |

Mount `favicon.ico` over `/app/public/favicon.ico` as well. `/healthz/brand` reports missing files.

### SSO behaviour

- Login button "OIDC_BUTTON_LABEL" below the password form. The flow uses state, nonce and PKCE and checks the ID token signature (JWKS), issuer and audience.
- Users are matched by e-mail and then bound to the IdP subject (`user_configs.oidc_sub`). The same e-mail with a different subject is rejected.
- New users are created on first login only if they are in `OIDC_ALLOWED_GROUPS`. The Community Edition has only the role `admin`, so every user has full rights.
- A linked user who lost the group is archived on the next attempt and reactivated when back in the group. Users archived by an admin stay archived.
- SSO-linked users cannot sign in with a password or reset it; 2FA for them is the IdP's job. Local accounts (emergency admin) keep password + TOTP, and "Force 2FA" in the account settings applies to them.
- Signing links for external signers (`/s/…`, `/d/…`) are not affected.

Redirect URI to register at the IdP: `https://<host>/auth/oidc/callback`. Authentik: OAuth2/OpenID provider, confidential client, grant type *authorization code* (set it explicitly if the provider is created via API), signing key RS256, scopes `openid email profile` (Authentik's `profile` scope includes `groups`).

### Self-check

`GET /healthz/brand` answers JSON `{"ok":true,"checks":{"branding":"ok","oidc":"ok"}}` with 200, or 503 if something in `BRAND_HEALTHZ_EXPECT` is missing. An image without this patch set answers 404. On boot the log shows `[brand] …` and `[oidc] enabled …`, or `[brand] WARN` / `[oidc] WARN`.

## Set `jt`

| Patch | Content |
|---|---|
| 0001 | Branding views: logo, page title, meta/OG/favicons, landing page, PWA manifest, empty mail footer. Hides the DocuSeal Console, "Ask AI" and GitHub/Discord links. `product_name` via initializer |
| 0002 | Own daisyUI theme `jt` (dark navy), builder background follows the theme |
| 0003 | Template builder: own logo, locked Pro field tiles and pricing links removed |
| 0004 | Settings: plans/Pro, Console, SMS and SSO menu items and "learn more" links removed. Support e-mail and some texts changed |
| 0005 | Assets `public/jt/*`, audit trail and stamp logos |
| 0006 | Dark mode fixes, audit trail without docuseal.com, signature preview on white |
| 0007 | "Source code" link to this repo |

Logos and images under `public/jt/` are the Jason Talge brand and are not covered by the AGPL grant for reuse as branding.

## Updating to a new DocuSeal release

1. `./build.sh <set> <new> 1`. If it runs through, test and deploy.
2. If a patch no longer applies:
   ```sh
   git clone --depth 1 --branch <new> https://github.com/docusealco/docuseal.git work && cd work
   git am --3way ../patches/<set>/*.patch   # fix conflicts, git add …, git am --continue
   rm ../patches/<set>/*.patch && git format-patch -o ../patches/<set> <new>..HEAD
   ```
3. Test against a throwaway database before deploying: template editor, a submission, the signing form `/s/…`, the completion page, the e-mails, the audit log PDF, the SSO login and `/healthz/brand`.

## License

DocuSeal is licensed under AGPL-3.0 with additional terms ([LICENSE](LICENSE), [LICENSE_ADDITIONAL_TERMS](LICENSE_ADDITIONAL_TERMS)). The patches are under the same license. As the additional terms require, the "Powered by DocuSeal" attribution stays in all interactive user interfaces. The SSO login is an own implementation for the Community Edition; it does not use or unlock DocuSeal Pro code.
