# LaunchRights — marketing & compliance site

A single-page Vue 3 + Vite site that sells the value and compliance advantages of
LaunchRights. Dark, engineered aesthetic; the signature motif is the **elevation
line** — approved apps lifted from *Standard* to *Elevated* through a signature-check
gate.

## Run

```bash
npm install
npm run dev        # local dev server (hot reload)
npm run build      # production build -> dist/
npm run preview    # serve the production build locally
```

## Structure

```
index.html                  fonts + meta + favicon
src/style.css               design tokens (ink / brass / jade), type, base
src/App.vue                 page composition
src/components/
  SiteNav.vue               sticky nav + responsive menu
  HeroElevation.vue         hero + the animated elevation-line signature
  TrustStrip.vue            compliance-framework strip
  ProblemSection.vue        the local-admin problem + stat tiles
  HowItWorks.vue            4-step sequence + mono audit-log sample
  FeatureGrid.vue           six product capabilities
  ComplianceSection.vue     framework → control → how-it-maps matrix
  BetaSignup.vue            "Register your interest" beta form (name / org / email / use case)
  SiteFooter.vue            footer
```

## Editing content

Copy lives as plain data arrays/markup inside each component — no CMS. Common edits:

- **Compliance mappings:** `ComplianceSection.vue` → `mappings` array.
- **Features:** `FeatureGrid.vue` → `features` array.
- **Beta form:** `BetaSignup.vue`. Edit the `useCases` array for the dropdown options.
- **Framework list:** `TrustStrip.vue` → `frameworks`.

## Beta signup form

`BetaSignup.vue` collects **name, organisation, work email, and use case** and is the
site's single call to action (`#beta`). Two ways to receive submissions, set at the top
of the component:

- **`FORM_ENDPOINT`** — a URL that accepts a JSON `POST` (Formspree, Basin, a Cloudflare
  Worker, your own API). When set, the form posts there and shows an inline success state.
  Keeps the site fully static — no server of your own required.
- **Fallback (default):** leave `FORM_ENDPOINT` empty and the form opens a pre-filled
  email to **`BETA_INBOX`** (`beta@launchrights.com`) so it works with zero backend.
  Change `BETA_INBOX` to your real beta inbox.

Includes client-side validation and a hidden honeypot field for basic bot filtering.

## Design notes

- Palette encodes meaning: **brass** = the gate / authority, **jade** = verified /
  elevated. Deliberately not the security-vendor red-on-black.
- Type: Space Grotesk (display) · IBM Plex Sans (body) · JetBrains Mono (data/logs),
  loaded from Google Fonts in `index.html`.
- Accessibility: skip link, visible focus rings, `prefers-reduced-motion` respected
  (the hero animation lands on its final state without motion).

## Deploy

Static output — `npm run build` emits `dist/`, deployable to any static host
(Netlify, Vercel, Cloudflare Pages, S3+CloudFront, GitHub Pages). Point
`launchrights.com` at it. No server or environment variables required.

> Compliance copy states LaunchRights *supports* the named controls and produces
> evidence for them; it is not itself a certification. Keep that framing if you edit.
