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
  CtaSection.vue            "Book a demo" call to action
  SiteFooter.vue            footer
```

## Editing content

Copy lives as plain data arrays/markup inside each component — no CMS. Common edits:

- **Compliance mappings:** `ComplianceSection.vue` → `mappings` array.
- **Features:** `FeatureGrid.vue` → `features` array.
- **Contact email / demo link:** `CtaSection.vue`, `SiteFooter.vue`, `SiteNav.vue`
  (currently `hello@launchrights.com` — change to a real inbox).
- **Framework list:** `TrustStrip.vue` → `frameworks`.

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
