<script setup>
const mappings = [
  {
    fw: 'Cyber Essentials',
    body: 'NCSC · User access control',
    ref: 'Restrict administrative privileges',
    how: 'Remove day-to-day admin rights across the fleet while approved privileged apps keep running. Evidence the control directly from the audit log.',
  },
  {
    fw: 'ISO/IEC 27001:2022',
    body: 'Annex A · 8.2',
    ref: 'Privileged access rights',
    how: 'Grant privilege per application on least-privilege terms, with every use attributable and reviewable — the review evidence 8.2 asks for.',
  },
  {
    fw: 'NIST SP 800-53',
    body: 'AC-6 · AU-2',
    ref: 'Least privilege · Audit events',
    how: 'No standing admin to grant or track. Each elevation is a discrete, audited event with full attribution of who ran what, and when.',
  },
  {
    fw: 'CIS Controls v8',
    body: 'Safeguards 5.4 · 6.8',
    ref: 'Restrict admin to dedicated use',
    how: 'Eliminate standing local-admin accounts and scope elevation to specific, signed applications instead of whole user sessions.',
  },
  {
    fw: 'SOC 2',
    body: 'Trust Services · CC6.1 / CC6.3',
    ref: 'Logical access · least privilege',
    how: 'Access is limited to least privilege and continuously logged, giving your auditor a clean, timestamped access record.',
  },
  {
    fw: 'PCI DSS v4.0',
    body: 'Requirement 7',
    ref: 'Least privilege by role',
    how: 'Restrict elevated access to only what a role\'s approved applications require — nothing standing, nothing shared.',
  },
]
</script>

<template>
  <section id="compliance" class="section comp on-paper">
    <div class="wrap">
      <div class="comp__head">
        <p class="eyebrow">Compliance</p>
        <h2 class="h-lg">Turn "remove local admin" from a finding into a fixed control.</h2>
        <p class="lede">
          Nearly every framework asks the same thing: least privilege, admin rights
          restricted, privileged use logged. LaunchRights answers all three the same way —
          per-app elevation, verified and audited. Here's where it lands.
        </p>
      </div>

      <div class="matrix">
        <article class="row" v-for="m in mappings" :key="m.fw">
          <div class="row__fw">
            <h3 class="row__name">{{ m.fw }}</h3>
            <span class="row__body">{{ m.body }}</span>
          </div>
          <div class="row__ref">
            <span class="tag">{{ m.ref }}</span>
          </div>
          <p class="row__how">{{ m.how }}</p>
        </article>
      </div>

      <p class="comp__note">
        LaunchRights supports these controls and produces the evidence for them — it isn't a
        certification in itself. Use it alongside your existing GRC process.
      </p>
    </div>
  </section>
</template>

<style scoped>
.comp__head { max-width: 62ch; margin-bottom: clamp(2.4rem, 5vw, 3.4rem); }
.comp__head .lede { color: var(--tx-lo-l); }

.matrix {
  border: 1px solid var(--hair-l-2); border-radius: var(--radius); overflow: hidden;
  background: var(--paper-2);
}
.row {
  display: grid;
  grid-template-columns: 0.9fr 1fr 1.6fr;
  gap: clamp(1rem, 3vw, 2.2rem);
  align-items: center;
  padding: clamp(1.3rem, 2.6vw, 1.8rem) clamp(1.3rem, 3vw, 2rem);
  border-top: 1px solid var(--hair-l);
}
.row:first-child { border-top: none; }
.row__name { font-size: 1.12rem; }
.row__body {
  display: block; margin-top: 0.35rem;
  font-family: var(--font-mono); font-size: 0.72rem; letter-spacing: 0.06em;
  color: var(--tx-lo-l);
}
.tag {
  display: inline-block;
  font-family: var(--font-mono); font-size: 0.74rem;
  color: #6a5320; background: rgba(200,155,74,0.16);
  border: 1px solid rgba(200,155,74,0.5); border-radius: 7px;
  padding: 0.35rem 0.65rem;
}
.row__how { color: var(--tx-lo-l); font-size: 0.98rem; }

.comp__note {
  margin-top: 1.4rem; font-size: 0.9rem; color: var(--tx-lo-l);
  border-left: 2px solid var(--brass); padding-left: 0.9rem; max-width: 70ch;
}

@media (max-width: 820px) {
  .row { grid-template-columns: 1fr; gap: 0.7rem; align-items: start; }
  .row__ref { order: 3; }
}
</style>
