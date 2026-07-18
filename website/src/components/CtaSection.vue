<script setup>
const mailto =
  'mailto:hello@launchrights.com?subject=LaunchRights%20demo%20request'
</script>

<template>
  <section id="demo" class="section cta">
    <div class="wrap cta__inner">
      <div class="cta__line" aria-hidden="true">
        <span class="cta__gate">
          <svg viewBox="0 0 24 24"><path d="M12 5l6 9H6z" fill="var(--jade)"/></svg>
        </span>
      </div>

      <p class="eyebrow">Get started</p>
      <h2 class="h-lg cta__h">Take admin off the endpoint.<br />Keep the work on it.</h2>
      <p class="lede cta__lede">
        Book a 30-minute walkthrough with the Jigsaw24 team. We'll map LaunchRights to the
        controls you're being assessed against and show it running on a managed Mac.
      </p>

      <div class="cta__actions">
        <a class="btn" :href="mailto">Book a demo</a>
        <a class="btn btn--ghost" href="mailto:hello@launchrights.com">hello@launchrights.com</a>
      </div>
    </div>
  </section>
</template>

<style scoped>
.cta { background: var(--ink); text-align: center; position: relative; overflow: hidden; }
.cta::before {
  content: ""; position: absolute; inset: 0;
  background: radial-gradient(closest-side at 50% 0%, rgba(52,214,160,0.12), transparent 70%);
  pointer-events: none;
}
.cta__inner { position: relative; max-width: 720px; margin-inline: auto; }

.cta__line {
  position: relative; height: 1px; background: var(--brass);
  opacity: 0.5; margin-bottom: 3rem;
}
.cta__gate {
  position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%);
  width: 40px; height: 40px; display: grid; place-items: center;
  background: var(--ink); border: 1px solid var(--brass); border-radius: 11px;
}
.cta__gate svg { width: 20px; height: 20px; }

.cta__h { margin-bottom: 1.3rem; }
.cta__lede { margin-inline: auto; }
.cta__actions {
  display: flex; justify-content: center; flex-wrap: wrap; gap: 0.9rem; margin-top: 2rem;
}
.cta__actions .btn--ghost { font-family: var(--font-mono); font-weight: 500; font-size: 0.9rem; }
</style>
