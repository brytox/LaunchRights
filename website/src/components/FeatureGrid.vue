<script setup>
const features = [
  {
    t: 'Privilege per app, not per person',
    d: 'Rights attach to vetted applications, never to accounts. No standing admin means nothing to phish, steal, or escalate.',
    icon: 'app',
  },
  {
    t: 'Code signature enforced',
    d: 'Every launch is re-verified on disk against a Team-ID-pinned requirement. Replace the binary and the elevation simply stops.',
    icon: 'shield',
  },
  {
    t: 'Tamper-proof audit trail',
    d: 'A root-only, append-only record of every allow and deny — timestamp, user, app, signature, outcome. Evidence your auditors can read.',
    icon: 'log',
  },
  {
    t: 'Pre-execution interception',
    d: 'The Endpoint Security engine gates a launch before the process runs — no flash of an unelevated window, no race to win.',
    icon: 'gate',
  },
  {
    t: 'Silent and MDM-native',
    d: 'Ship policy and approvals through Jamf, Intune or Addigy. No end-user prompts, no per-machine setup, no local admin to grant.',
    icon: 'cloud',
  },
  {
    t: 'One policy, two platforms',
    d: 'macOS today, Windows on the roadmap — the same allowlist model and the same audit format across your whole fleet.',
    icon: 'grid',
  },
]

const paths = {
  app: 'M4 7h16M4 12h16M4 17h10',
  shield: 'M12 3l7 3v5c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z',
  log: 'M5 4h11l3 3v13H5zM9 10h7M9 14h7M9 18h4',
  gate: 'M4 16h16M12 4l6 8H6z',
  cloud: 'M7 18a4 4 0 010-8 5 5 0 019.6-1.3A3.5 3.5 0 0117 18z',
  grid: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
}
</script>

<template>
  <section id="features" class="section feats">
    <div class="wrap">
      <div class="feats__head">
        <p class="eyebrow">What you get</p>
        <h2 class="h-lg">Least privilege that survives contact with real work.</h2>
      </div>

      <div class="grid">
        <article class="card" v-for="f in features" :key="f.t">
          <span class="card__icon" aria-hidden="true">
            <svg viewBox="0 0 24 24"><path :d="paths[f.icon]" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </span>
          <h3 class="card__t">{{ f.t }}</h3>
          <p class="card__d">{{ f.d }}</p>
        </article>
      </div>
    </div>
  </section>
</template>

<style scoped>
.feats { background: var(--ink); }
.feats__head { max-width: 52ch; margin-bottom: clamp(2.2rem, 4vw, 3.2rem); }

.grid {
  display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.1rem;
}
.card {
  border: 1px solid var(--hair-d); border-radius: var(--radius);
  padding: 1.7rem 1.6rem; background: var(--ink-2);
  transition: transform 0.18s ease, border-color 0.18s ease;
}
.card:hover { transform: translateY(-4px); border-color: var(--hair-d-2); }
.card__icon {
  display: inline-grid; place-items: center;
  width: 44px; height: 44px; border-radius: 11px;
  background: rgba(200,155,74,0.12); color: var(--brass);
  border: 1px solid rgba(200,155,74,0.35); margin-bottom: 1.2rem;
}
.card__icon svg { width: 22px; height: 22px; }
.card__t { font-size: 1.15rem; margin-bottom: 0.6rem; }
.card__d { color: var(--tx-lo-d); font-size: 0.96rem; }

@media (max-width: 900px) { .grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
</style>
