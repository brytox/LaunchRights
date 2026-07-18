<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const scrolled = ref(false)
const open = ref(false)

const links = [
  { href: '#problem', label: 'Why' },
  { href: '#how', label: 'How it works' },
  { href: '#features', label: 'Product' },
  { href: '#compliance', label: 'Compliance' },
]

function onScroll() { scrolled.value = window.scrollY > 12 }
onMounted(() => window.addEventListener('scroll', onScroll, { passive: true }))
onUnmounted(() => window.removeEventListener('scroll', onScroll))
</script>

<template>
  <header class="nav" :class="{ 'nav--solid': scrolled }">
    <div class="wrap nav__inner">
      <a class="brand" href="#top" aria-label="LaunchRights home">
        <svg class="brand__mark" viewBox="0 0 32 32" aria-hidden="true">
          <path d="M6 21h20" stroke="var(--brass)" stroke-width="2" stroke-linecap="round" />
          <path d="M16 6l6 9H10z" fill="var(--jade)" />
        </svg>
        <span class="brand__name">LaunchRights</span>
      </a>

      <nav class="nav__links" :class="{ 'is-open': open }">
        <a v-for="l in links" :key="l.href" :href="l.href" @click="open = false">{{ l.label }}</a>
        <a class="btn nav__cta" href="#demo" @click="open = false">Book a demo</a>
      </nav>

      <button
        class="nav__toggle"
        :aria-expanded="open"
        aria-label="Toggle menu"
        @click="open = !open"
      >
        <span :class="{ 'x': open }"></span>
      </button>
    </div>
  </header>
</template>

<style scoped>
.nav {
  position: sticky;
  top: 0;
  z-index: 50;
  border-bottom: 1px solid transparent;
  transition: background 0.25s ease, border-color 0.25s ease, backdrop-filter 0.25s ease;
}
.nav--solid {
  background: rgba(11, 22, 32, 0.72);
  backdrop-filter: blur(14px);
  border-bottom-color: var(--hair-d);
}
.nav__inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 68px;
}

.brand { display: inline-flex; align-items: center; gap: 0.6rem; }
.brand__mark { width: 26px; height: 26px; }
.brand__name {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1.12rem;
  letter-spacing: -0.02em;
}

.nav__links { display: flex; align-items: center; gap: 2rem; }
.nav__links a {
  font-size: 0.95rem;
  color: var(--tx-lo-d);
  transition: color 0.15s ease;
}
.nav__links a:hover { color: var(--tx-hi-d); }
.nav__cta { color: #1a1204 !important; padding: 0.6rem 1.1rem; font-size: 0.9rem; }

.nav__toggle { display: none; }

@media (max-width: 860px) {
  .nav__links {
    position: fixed;
    inset: 68px 0 auto 0;
    flex-direction: column;
    align-items: stretch;
    gap: 0;
    background: var(--ink-2);
    border-bottom: 1px solid var(--hair-d);
    padding: 0.5rem var(--pad) 1.25rem;
    transform: translateY(-120%);
    transition: transform 0.3s ease;
  }
  .nav__links.is-open { transform: translateY(0); }
  .nav__links a { padding: 0.9rem 0; border-bottom: 1px solid var(--hair-d); }
  .nav__cta { margin-top: 0.9rem; justify-content: center; border-bottom: none !important; }

  .nav__toggle {
    display: inline-flex;
    width: 42px; height: 42px;
    align-items: center; justify-content: center;
    background: transparent; border: 1px solid var(--hair-d-2);
    border-radius: 9px; cursor: pointer;
  }
  .nav__toggle span,
  .nav__toggle span::before,
  .nav__toggle span::after {
    content: "";
    display: block; width: 18px; height: 2px;
    background: var(--tx-hi-d); border-radius: 2px;
    transition: transform 0.25s ease, opacity 0.2s ease;
  }
  .nav__toggle span { position: relative; }
  .nav__toggle span::before { position: absolute; top: -6px; }
  .nav__toggle span::after { position: absolute; top: 6px; }
  .nav__toggle span.x { background: transparent; }
  .nav__toggle span.x::before { transform: translateY(6px) rotate(45deg); }
  .nav__toggle span.x::after { transform: translateY(-6px) rotate(-45deg); }
}
</style>
