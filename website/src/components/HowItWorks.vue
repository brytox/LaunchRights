<script setup>
const steps = [
  {
    k: 'Approve',
    d: 'Add an application to the allowlist with the code-signature rule it must satisfy. The list is root-owned — standard users can\'t touch it — and shipped by your MDM.',
  },
  {
    k: 'Launch',
    d: 'A standard user opens the app exactly as they always would. No sudo, no prompt, no separate admin password to hand out.',
  },
  {
    k: 'Verify',
    d: 'Before anything runs, LaunchRights re-checks the app on disk against your rule. Swap the binary for something else and the elevation is refused.',
  },
  {
    k: 'Elevate & log',
    d: 'The approved app runs with admin rights. The decision — who, what, when, and the signature it matched — is appended to the tamper-proof audit log.',
  },
]
</script>

<template>
  <section id="how" class="section how on-paper">
    <div class="wrap">
      <div class="how__head">
        <p class="eyebrow">How it works</p>
        <h2 class="h-lg">Four steps across the privilege line.</h2>
        <p class="lede">
          One daemon makes every decision as root and trusts nothing it's told. The
          sequence is the same whether it runs as a launch observer or an Endpoint
          Security extension.
        </p>
      </div>

      <ol class="steps">
        <li v-for="(s, i) in steps" :key="s.k" class="step">
          <span class="step__num">{{ String(i + 1).padStart(2, '0') }}</span>
          <div class="step__body">
            <h3 class="step__k">{{ s.k }}</h3>
            <p class="step__d">{{ s.d }}</p>
          </div>
        </li>
      </ol>

      <figure class="log">
        <figcaption class="log__cap">audit.log · root-only, append-only</figcaption>
        <pre class="log__line"><span class="c-dim">2026-07-18T09:14:22Z</span>  <span class="c-ok">ELEVATED</span>  user=<span class="c-key">j.okafor</span>  app=<span class="c-key">com.corp.NetConfig</span>  sig=<span class="c-ok">team:ABCDE12345 ✓</span></pre>
        <pre class="log__line"><span class="c-dim">2026-07-18T09:16:05Z</span>  <span class="c-deny">DENIED</span>    user=<span class="c-key">j.okafor</span>  app=<span class="c-key">com.unknown.Installer</span>  sig=<span class="c-deny">requirement not met</span></pre>
      </figure>
    </div>
  </section>
</template>

<style scoped>
.how__head { max-width: 60ch; margin-bottom: clamp(2.5rem, 5vw, 3.5rem); }
.how__head .lede { color: var(--tx-lo-l); }

.steps {
  list-style: none; margin: 0; padding: 0;
  display: grid; grid-template-columns: repeat(2, 1fr);
  gap: 1px; background: var(--hair-l-2);
  border: 1px solid var(--hair-l-2); border-radius: var(--radius); overflow: hidden;
}
.step {
  background: var(--paper-2);
  padding: clamp(1.5rem, 3vw, 2.3rem);
  display: flex; gap: 1.1rem;
}
.step__num {
  font-family: var(--font-mono); font-size: 0.85rem; font-weight: 500;
  color: var(--brass); padding-top: 0.35rem; flex: none;
}
.step__k { font-size: 1.25rem; margin-bottom: 0.5rem; }
.step__d { color: var(--tx-lo-l); font-size: 0.98rem; }

.log {
  margin: clamp(2rem, 4vw, 3rem) 0 0;
  background: var(--ink); border-radius: var(--radius);
  border: 1px solid var(--ink-3);
  padding: 1.2rem 1.3rem; overflow-x: auto;
}
.log__cap {
  font-family: var(--font-mono); font-size: 0.68rem; letter-spacing: 0.12em;
  color: var(--tx-lo-d); text-transform: uppercase; margin-bottom: 0.9rem;
}
.log__line {
  font-family: var(--font-mono); font-size: 0.82rem; margin: 0 0 0.5rem;
  color: var(--tx-hi-d); white-space: pre;
}
.log__line:last-child { margin-bottom: 0; }
.c-dim { color: var(--tx-lo-d); }
.c-key { color: #cfe3dd; }
.c-ok { color: var(--jade); }
.c-deny { color: var(--deny); }

@media (max-width: 720px) {
  .steps { grid-template-columns: 1fr; }
}
</style>
