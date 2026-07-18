<script setup>
// The signature: one app token travels from Standard, through the gold gate
// (signature check), up to Elevated — turning jade/verified. Approved apps sit
// above the line; unapproved are held below.
</script>

<template>
  <section id="top" class="hero">
    <div class="wrap hero__inner">
      <div class="hero__copy">
        <p class="eyebrow">Endpoint privilege management · macOS · Windows soon</p>
        <h1 class="h-xl">
          The app gets admin.<br />
          <span class="hl">The user never does.</span>
        </h1>
        <p class="lede">
          LaunchRights runs specific, IT-approved applications with elevated rights on
          managed Macs — every launch verified by code signature and written to a
          tamper-proof audit log. Remove local admin from your fleet without removing
          anyone's ability to work.
        </p>
        <div class="hero__actions">
          <a class="btn" href="#demo">Book a demo</a>
          <a class="btn btn--ghost" href="#how">See how it works</a>
        </div>
        <p class="hero__note">
          Deployed by MDM · built for Jamf, Intune &amp; Addigy
        </p>
      </div>

      <!-- Signature visual -->
      <div class="panel" role="img"
           aria-label="Diagram: an approved app is lifted from the standard-user zone, through a signature-check gate, into the elevated zone; an unapproved app is held below the privilege line.">
        <div class="panel__grid" aria-hidden="true"></div>

        <span class="zlabel zlabel--top">ELEVATED · root</span>
        <span class="zlabel zlabel--bot">STANDARD · user</span>

        <!-- privilege line -->
        <div class="pline" aria-hidden="true">
          <span class="pline__tag">privilege line</span>
        </div>
        <div class="shaft" aria-hidden="true"></div>

        <!-- the gate -->
        <div class="gate" aria-hidden="true">
          <span class="gate__ring"></span>
          <svg viewBox="0 0 24 24"><path d="M6 12l4 4 8-8" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
        </div>

        <!-- resting elevated tokens (context) -->
        <div class="tok tok--ok" style="left:24%; top:16%">
          <span class="tok__glyph"></span>
          <span class="tok__chk">✓</span>
        </div>
        <div class="tok tok--ok" style="left:70%; top:22%">
          <span class="tok__glyph"></span>
          <span class="tok__chk">✓</span>
        </div>

        <!-- held-below (denied) token -->
        <div class="tok tok--deny" style="left:72%; top:80%">
          <span class="tok__glyph"></span>
          <span class="tok__tag">not approved</span>
        </div>

        <!-- the hero token: animates the full journey -->
        <div class="tok tok--hero" aria-hidden="true">
          <span class="tok__glyph"></span>
          <span class="tok__chk tok__chk--anim">✓</span>
        </div>
        <span class="verify-tip" aria-hidden="true">signature&nbsp;✓</span>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hero { position: relative; overflow: hidden; padding-block: clamp(3.5rem, 7vw, 6.5rem); }
.hero::before {
  /* ambient brass glow rising from the gate side */
  content: "";
  position: absolute;
  right: -10%; top: 20%;
  width: 55%; height: 90%;
  background: radial-gradient(closest-side, rgba(200,155,74,0.14), transparent 70%);
  pointer-events: none;
}
.hero__inner {
  position: relative;
  display: grid;
  grid-template-columns: 1.05fr 1fr;
  gap: clamp(2rem, 5vw, 4.5rem);
  align-items: center;
}

.hero__copy h1 { margin-bottom: 1.4rem; }
.hl { color: var(--jade); }
.hero__actions { display: flex; flex-wrap: wrap; gap: 0.9rem; margin: 2rem 0 1.1rem; }
.hero__note {
  font-family: var(--font-mono);
  font-size: 0.78rem;
  letter-spacing: 0.04em;
  color: var(--tx-lo-d);
}

/* ---------- Panel ---------- */
.panel {
  position: relative;
  aspect-ratio: 5 / 4.4;
  min-height: 380px;
  border: 1px solid var(--hair-d-2);
  border-radius: var(--radius);
  background: linear-gradient(180deg, #0d1e28, #0a151d);
  overflow: hidden;
  box-shadow: 0 40px 80px -40px rgba(0,0,0,0.7);
}
.panel__grid {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(var(--hair-d) 1px, transparent 1px),
    linear-gradient(90deg, var(--hair-d) 1px, transparent 1px);
  background-size: 34px 34px;
  mask-image: radial-gradient(circle at 55% 45%, #000 55%, transparent 100%);
  opacity: 0.5;
}

/* zone bands */
.panel::after {
  content: "";
  position: absolute; left: 0; right: 0; top: 0; height: 55%;
  background: linear-gradient(180deg, rgba(52,214,160,0.07), transparent);
  pointer-events: none;
}
.zlabel {
  position: absolute; left: 18px;
  font-family: var(--font-mono);
  font-size: 0.66rem; letter-spacing: 0.16em;
}
.zlabel--top { top: 16px; color: var(--jade); }
.zlabel--bot { bottom: 16px; color: var(--tx-lo-d); }

/* privilege line */
.pline {
  position: absolute; left: 0; right: 0; top: 55%;
  height: 0; border-top: 1px dashed var(--brass);
  opacity: 0.85;
}
.pline__tag {
  position: absolute; left: 18px; top: -9px;
  background: var(--ink); padding: 0 8px;
  font-family: var(--font-mono); font-size: 0.62rem;
  letter-spacing: 0.14em; color: var(--brass);
}
.shaft {
  position: absolute; left: 50%; top: 14%; bottom: 14%;
  width: 1px; transform: translateX(-0.5px);
  background: linear-gradient(180deg, rgba(52,214,160,0.35), rgba(200,155,74,0.35));
  opacity: 0.5;
}

/* gate */
.gate {
  position: absolute; left: 50%; top: 55%;
  width: 40px; height: 40px; margin: -20px 0 0 -20px;
  display: grid; place-items: center;
  border-radius: 11px;
  background: rgba(200,155,74,0.14);
  border: 1px solid var(--brass);
  color: var(--brass);
  z-index: 3;
}
.gate svg { width: 20px; height: 20px; }
.gate__ring {
  position: absolute; inset: -6px;
  border-radius: 14px; border: 1px solid var(--brass);
  opacity: 0; animation: ring 3.4s ease-out 1.4s infinite;
}
@keyframes ring {
  0% { opacity: 0.5; transform: scale(0.85); }
  70%,100% { opacity: 0; transform: scale(1.5); }
}

/* tokens */
.tok {
  position: absolute; z-index: 2;
  width: 46px; margin-left: -23px;
  display: grid; justify-items: center; gap: 6px;
}
.tok__glyph {
  width: 40px; height: 40px; border-radius: 11px;
  background: var(--ink-3);
  border: 1px solid var(--hair-d-2);
  background-image: radial-gradient(circle at 30% 30%, rgba(255,255,255,0.14), transparent 60%);
  transition: background 0.3s ease, border-color 0.3s ease;
}
.tok__chk {
  font-size: 0.8rem; color: var(--jade); line-height: 1;
}
.tok__tag, .verify-tip {
  font-family: var(--font-mono); font-size: 0.6rem; letter-spacing: 0.08em;
  white-space: nowrap;
}
.tok--ok .tok__glyph { border-color: var(--jade); background: rgba(52,214,160,0.16); }
.tok--deny .tok__glyph { border-color: var(--deny); background: rgba(224,135,103,0.14); }
.tok--deny .tok__tag { color: var(--deny); }

/* the animated hero token */
.tok--hero {
  left: 50%; top: 78%;
  animation: lift 4.6s cubic-bezier(.65,0,.35,1) 0.7s forwards;
}
.tok--hero .tok__glyph { animation: verify 4.6s ease 0.7s forwards; }
.tok__chk--anim { opacity: 0; transform: scale(0.4); animation: chk 4.6s ease 0.7s forwards; }

.verify-tip {
  position: absolute; left: 50%; top: 55%;
  transform: translate(28px, -30px);
  color: var(--brass); background: var(--ink);
  padding: 3px 7px; border: 1px solid var(--brass); border-radius: 6px;
  opacity: 0; animation: tip 4.6s ease 0.7s forwards; z-index: 4;
}

@keyframes lift {
  0%   { top: 78%; }
  30%  { top: 57%; }
  46%  { top: 57%; }   /* pause at the gate = verifying */
  100% { top: 16%; }
}
@keyframes verify {
  0%,46%   { background: var(--ink-3); border-color: var(--hair-d-2); }
  62%,100% { background: rgba(52,214,160,0.16); border-color: var(--jade); }
}
@keyframes chk {
  0%,52% { opacity: 0; transform: scale(0.4); }
  68%,100% { opacity: 1; transform: scale(1); }
}
@keyframes tip {
  0%,26% { opacity: 0; }
  34%,46% { opacity: 1; }
  56%,100% { opacity: 0; }
}

@media (max-width: 860px) {
  .hero__inner { grid-template-columns: 1fr; }
  .panel { order: -1; max-width: 460px; margin-inline: auto; width: 100%; }
}
@media (prefers-reduced-motion: reduce) {
  /* land on the story's end-state without motion */
  .tok--hero { top: 16%; }
  .tok--hero .tok__glyph { background: rgba(52,214,160,0.16); border-color: var(--jade); }
  .tok__chk--anim { opacity: 1; transform: scale(1); }
  .verify-tip, .gate__ring { display: none; }
}
</style>
