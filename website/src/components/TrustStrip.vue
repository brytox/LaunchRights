<script setup>
const frameworks = [
  'Cyber Essentials',
  'ISO 27001',
  'NIST 800-53',
  'CIS Controls v8',
  'SOC 2',
  'PCI DSS 4.0',
]
</script>

<template>
  <section class="strip">
    <div class="wrap strip__inner">
      <p class="strip__label">Maps to the controls your auditors ask about</p>
      <ul class="strip__list">
        <li v-for="f in frameworks" :key="f">{{ f }}</li>
      </ul>
    </div>
  </section>
</template>

<style scoped>
.strip { border-block: 1px solid var(--hair-d); background: var(--ink-2); }
.strip__inner {
  display: flex; align-items: center; flex-wrap: wrap;
  gap: 1rem 2.4rem; padding-block: 1.4rem;
}
.strip__label {
  font-family: var(--font-mono); font-size: 0.72rem;
  letter-spacing: 0.12em; color: var(--tx-lo-d); text-transform: uppercase;
}
.strip__list {
  list-style: none; margin: 0; padding: 0;
  display: flex; flex-wrap: wrap; gap: 0.8rem 2rem;
}
.strip__list li {
  font-family: var(--font-display); font-weight: 600; font-size: 0.95rem;
  color: var(--tx-hi-d); position: relative; padding-left: 1rem;
}
.strip__list li::before {
  content: ""; position: absolute; left: 0; top: 50%;
  width: 5px; height: 5px; margin-top: -2.5px; border-radius: 50%;
  background: var(--brass);
}
</style>
