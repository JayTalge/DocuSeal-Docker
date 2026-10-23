# DocuSeal-Docker

Patch set and build script for the self-hosted [DocuSeal](https://github.com/docusealco/docuseal) instance at [sign.jason-talge.de](https://sign.jason-talge.de). This repo contains only the patches in `patches/`. The upstream code is not forked: `build.sh` clones an upstream release tag, applies the patches with `git am` and builds the upstream `Dockerfile`, so the assets are rebuilt with the patched sources.

This is the Corresponding Source of the modified version running there (AGPL-3.0, section 13).

## Build

```sh
./build.sh 3.3.3 jt4      # -> local image docuseal-jt:3.3.3-jt4
```

Then use the image like `docuseal/docuseal` (same env, volumes and port 3000). The image only exists locally, so set `pull_policy: never` in Compose.

## Patches

Based on DocuSeal **3.3.3**.

| Patch | Content |
|---|---|
| 0001 | Branding views: logo, page title, meta/OG/favicons, landing page, PWA manifest, empty mail footer. Hides the DocuSeal Console, "Ask AI" and GitHub/Discord links in the navbar and settings. `product_name` is set by an initializer |
| 0002 | Own daisyUI theme `jt` (dark navy) in `tailwind.config.js`, `data-theme="jt"` in all layouts. The template builder background is `hsl(var(--b1))` instead of the hard-coded `#faf7f5` |
| 0003 | Template builder: own logo, locked Pro field tiles (phone, QES) and docuseal.com pricing/blog links removed |
| 0004 | Settings: plans/Pro, Console, SMS and SSO menu items and the "learn more" links to DocuSeal Cloud removed. Support e-mail and some de/en texts changed |
| 0005 | Assets: `public/jt/*` (logos, favicons, `jt-theme.css` dark fixes, `jt-theme-light.css`), audit trail and signature stamp logos |
| 0006 | Dark mode fixes found in testing. Audit trail PDF header/creator/sign reason without docuseal.com. Signature preview on white. Neutral Pro texts |
| 0007 | "Source code" link to this repo next to the DocuSeal attribution |

`public/jt/jt-theme.css` corrects hard-coded light Tailwind classes (`bg-white`, `bg-gray-*`, pastel alerts …). PDF pages and the signature canvas stay white on purpose. Keep each selector on one line: a line break between `:not()` parts is a descendant combinator.

## Updating to a new DocuSeal release

1. `./build.sh <new> jt1`. If it runs through, test and deploy.
2. If a patch no longer applies:
   ```sh
   git clone --depth 1 --branch <new> https://github.com/docusealco/docuseal.git work && cd work
   git am --3way ../patches/*.patch   # fix conflicts, git add …, git am --continue
   rm ../patches/*.patch && git format-patch -o ../patches <new>..HEAD
   ```
3. Test against a throwaway database before deploying. Check the template editor, a submission, the signing form `/s/…`, the completion page, the e-mails and the audit log PDF.

## License

DocuSeal is licensed under AGPL-3.0 with additional terms ([LICENSE](LICENSE), [LICENSE_ADDITIONAL_TERMS](LICENSE_ADDITIONAL_TERMS)). The patches are under the same license. As the additional terms require, the "Powered by DocuSeal" attribution stays in all interactive user interfaces. Logos and images under `public/jt/` are the Jason Talge brand and are not covered by the AGPL grant for reuse as branding.
