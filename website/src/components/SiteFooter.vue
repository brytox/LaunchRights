<script setup>
const year = 2026
const cols = [
  {
    h: 'Product',
    links: [
      { t: 'Why LaunchRights', href: '#problem' },
      { t: 'How it works', href: '#how' },
      { t: 'Features', href: '#features' },
      { t: 'Compliance', href: '#compliance' },
    ],
  },
  {
    h: 'Platforms',
    links: [
      { t: 'macOS — available', href: '#features' },
      { t: 'Windows — available', href: '#features' },
    ],
  },
  {
    h: 'Beta',
    links: [
      { t: 'Request beta access', href: '#beta' },
    ],
  },
]
</script>

<template>
  <footer class="foot">
    <div class="wrap foot__inner">
      <div class="foot__brand">
        <a class="brand" href="#top" aria-label="LaunchRights home">
          <svg class="brand__mark" viewBox="0 0 32 32" aria-hidden="true">
            <path d="M6 21h20" stroke="var(--brass)" stroke-width="2" stroke-linecap="round" />
            <path d="M16 6l6 9H10z" fill="var(--jade)" />
          </svg>
          <span class="brand__name">LaunchRights</span>
        </a>
        <p class="foot__tag">
          Endpoint privilege management for managed Mac and Windows fleets. The app gets
          admin — the user never does.
        </p>
      </div>

      <nav class="foot__cols">
        <div class="foot__col" v-for="c in cols" :key="c.h">
          <h4 class="foot__h">{{ c.h }}</h4>
          <ul>
            <li v-for="l in c.links" :key="l.t"><a :href="l.href">{{ l.t }}</a></li>
          </ul>
        </div>
      </nav>
    </div>

    <div class="wrap foot__base">
      <span>© {{ year }} LaunchRights</span>
      <span class="foot__mono">macOS · Windows</span>
    </div>
  </footer>
</template>

<style scoped>
.foot { border-top: 1px solid var(--hair-d); background: var(--ink-2); }
.foot__inner {
  display: grid; grid-template-columns: 1.2fr 2fr; gap: clamp(2rem, 5vw, 4rem);
  padding-block: clamp(3rem, 6vw, 4.5rem);
}
.brand { display: inline-flex; align-items: center; gap: 0.6rem; }
.brand__mark { width: 24px; height: 24px; }
.brand__name { font-family: var(--font-display); font-weight: 700; font-size: 1.05rem; }
.foot__tag { margin-top: 1rem; color: var(--tx-lo-d); font-size: 0.95rem; max-width: 34ch; }

.foot__cols { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1.5rem; }
.foot__h {
  font-family: var(--font-mono); font-size: 0.7rem; letter-spacing: 0.14em;
  text-transform: uppercase; color: var(--tx-lo-d); margin-bottom: 1rem;
}
.foot__col ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.65rem; }
.foot__col a { color: var(--tx-hi-d); font-size: 0.92rem; transition: color 0.15s ease; }
.foot__col a:hover { color: var(--brass); }

.foot__base {
  display: flex; justify-content: space-between; flex-wrap: wrap; gap: 0.5rem;
  padding-block: 1.4rem; border-top: 1px solid var(--hair-d);
  font-size: 0.82rem; color: var(--tx-lo-d);
}
.foot__mono { font-family: var(--font-mono); letter-spacing: 0.06em; }

@media (max-width: 780px) {
  .foot__inner { grid-template-columns: 1fr; }
  .foot__cols { grid-template-columns: repeat(2, 1fr); }
}
</style>
