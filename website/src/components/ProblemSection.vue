<script setup>
const stats = [
  { n: '0', label: 'standing admin accounts to defend' },
  { n: '1', label: 'signature check on every launch' },
  { n: '100%', label: 'of elevations written to the audit log' },
]
</script>

<template>
  <section id="problem" class="section prob">
    <div class="wrap prob__inner">
      <div class="prob__head">
        <p class="eyebrow">The problem</p>
        <h2 class="h-lg">Local admin is the shortcut that keeps costing you.</h2>
      </div>
      <div class="prob__body">
        <p>
          Making people local admins is the quickest way to stop help-desk tickets — and
          the quickest way to fail an audit. Every admin account is one ransomware click,
          one unsigned installer, one unreviewable change away from an incident.
        </p>
        <p>
          Take admin away and the tickets come straight back: the design suite won't
          update, the VPN client won't install, the engineer can't run their tool.
          Teams end up trading security against productivity — and productivity usually wins.
        </p>
        <p class="prob__turn">
          LaunchRights ends the trade-off. Privilege attaches to the <em>app</em>, verified
          and audited — never to the person.
        </p>
      </div>
    </div>

    <div class="wrap stats">
      <div class="stat" v-for="s in stats" :key="s.label">
        <span class="stat__n">{{ s.n }}</span>
        <span class="stat__l">{{ s.label }}</span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.prob { background: var(--ink); }
.prob__inner {
  display: grid; grid-template-columns: 0.9fr 1.1fr;
  gap: clamp(1.5rem, 5vw, 4rem); align-items: start;
}
.prob__body p { color: var(--tx-lo-d); font-size: 1.08rem; margin-bottom: 1.1rem; }
.prob__turn { color: var(--tx-hi-d) !important; font-size: 1.18rem !important; }
.prob__turn em { color: var(--jade); font-style: normal; }

.stats {
  display: grid; grid-template-columns: repeat(3, 1fr);
  gap: 1.25rem; margin-top: clamp(2.5rem, 6vw, 4rem);
}
.stat {
  border: 1px solid var(--hair-d); border-radius: var(--radius);
  padding: 1.6rem 1.5rem; background: var(--ink-2);
  border-top: 2px solid var(--brass);
}
.stat__n {
  display: block; font-family: var(--font-display); font-weight: 700;
  font-size: clamp(2.4rem, 5vw, 3.4rem); line-height: 1; color: var(--tx-hi-d);
  letter-spacing: -0.03em;
}
.stat__l {
  display: block; margin-top: 0.7rem; color: var(--tx-lo-d); font-size: 0.95rem;
  max-width: 24ch;
}

@media (max-width: 780px) {
  .prob__inner { grid-template-columns: 1fr; }
  .stats { grid-template-columns: 1fr; }
}
</style>
