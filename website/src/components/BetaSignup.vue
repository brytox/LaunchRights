<script setup>
import { ref, reactive, computed } from 'vue'

// ── Where submissions go ────────────────────────────────────────────────
// Set VITE_FORM_ENDPOINT (see .env.example) to the API's /signup URL — the SAM
// stack in ../api emits it as its ApiUrl output — and the form posts there.
// Leave it unset and the form falls back to opening a pre-filled email to
// BETA_INBOX — so it still works on a plain static host with no backend.
const FORM_ENDPOINT = import.meta.env.VITE_FORM_ENDPOINT || ''
const API_KEY = import.meta.env.VITE_API_KEY || ''
const BETA_INBOX = 'bob@3voltsmax.com'
// ────────────────────────────────────────────────────────────────────────

const useCases = [
  'Remove local admin from a managed fleet',
  'Let standard users run specific admin tools',
  'Compliance / audit evidence (Cyber Essentials, ISO 27001, …)',
  'Replace SAP Privileges / make-me-admin',
  'Cross-platform privilege management (Mac + Windows)',
  'Evaluating / just exploring',
  'Other',
]

const form = reactive({
  name: '',
  organisation: '',
  email: '',
  useCase: '',
  message: '', // optional free-text
  company: '', // honeypot — real people leave this blank
})

const errors = reactive({ name: '', organisation: '', email: '', useCase: '' })
const state = ref('idle') // idle | sending | done | error
const errorMsg = ref('')

const emailOk = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)

function validate() {
  errors.name = form.name.trim() ? '' : 'Please enter your name.'
  errors.organisation = form.organisation.trim() ? '' : 'Please enter your organisation.'
  errors.email = !form.email.trim()
    ? 'Please enter your work email.'
    : emailOk(form.email.trim())
      ? ''
      : 'That doesn’t look like a valid email.'
  errors.useCase = form.useCase ? '' : 'Please choose a use case.'
  return !errors.name && !errors.organisation && !errors.email && !errors.useCase
}

const mailtoFallback = computed(() => {
  const body = [
    `Name: ${form.name}`,
    `Organisation: ${form.organisation}`,
    `Email: ${form.email}`,
    `Use case: ${form.useCase}`,
    `Anything else: ${form.message || '—'}`,
  ].join('\n')
  return (
    `mailto:${BETA_INBOX}` +
    `?subject=${encodeURIComponent('LaunchRights beta — register interest')}` +
    `&body=${encodeURIComponent(body)}`
  )
})

async function submit() {
  if (state.value === 'sending') return
  if (form.company) return // honeypot tripped — silently drop
  if (!validate()) return

  const payload = {
    name: form.name.trim(),
    organisation: form.organisation.trim(),
    email: form.email.trim(),
    useCase: form.useCase,
    message: form.message.trim(),
  }

  // No backend configured → hand off to the user's mail client.
  if (!FORM_ENDPOINT) {
    window.location.href = mailtoFallback.value
    state.value = 'done'
    return
  }

  state.value = 'sending'
  errorMsg.value = ''
  try {
    const headers = { 'Content-Type': 'application/json', Accept: 'application/json' }
    if (API_KEY) headers['x-api-key'] = API_KEY
    const res = await fetch(FORM_ENDPOINT, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })
    if (!res.ok) throw new Error(`Request failed (${res.status})`)
    state.value = 'done'
  } catch (e) {
    state.value = 'error'
    errorMsg.value = 'Something went wrong sending that. Please try again, or email ' + BETA_INBOX + '.'
  }
}
</script>

<template>
  <section id="beta" class="section cta">
    <div class="wrap cta__inner">
      <div class="cta__line" aria-hidden="true">
        <span class="cta__gate">
          <svg viewBox="0 0 24 24"><path d="M12 5l6 9H6z" fill="var(--jade)"/></svg>
        </span>
      </div>

      <p class="eyebrow">Private beta</p>
      <h2 class="h-lg cta__h">Register your interest.<br />Help shape the beta.</h2>
      <p class="lede cta__lede">
        LaunchRights is in private beta with a small group of teams managing Mac and
        Windows fleets. Tell us
        a little about your fleet and how you’d use it, and the LaunchRights team will be in
        touch about early access.
      </p>

      <!-- Success -->
      <div v-if="state === 'done'" class="thanks" role="status">
        <span class="thanks__check" aria-hidden="true">✓</span>
        <h3 class="thanks__h">Thanks — you’re on the list.</h3>
        <p class="thanks__p">
          We’ve got your details and we’ll reach out about a beta place.
        </p>
      </div>

      <!-- Form -->
      <form v-else class="rf" novalidate @submit.prevent="submit">
        <div class="rf__row">
          <div class="field">
            <label for="rf-name">Name</label>
            <input
              id="rf-name" v-model="form.name" type="text" autocomplete="name"
              :class="{ 'is-bad': errors.name }" :aria-invalid="!!errors.name"
              placeholder="Alex Okafor"
            />
            <p v-if="errors.name" class="field__err">{{ errors.name }}</p>
          </div>

          <div class="field">
            <label for="rf-org">Organisation</label>
            <input
              id="rf-org" v-model="form.organisation" type="text" autocomplete="organization"
              :class="{ 'is-bad': errors.organisation }" :aria-invalid="!!errors.organisation"
              placeholder="Acme Ltd"
            />
            <p v-if="errors.organisation" class="field__err">{{ errors.organisation }}</p>
          </div>
        </div>

        <div class="field">
          <label for="rf-email">Work email</label>
          <input
            id="rf-email" v-model="form.email" type="email" autocomplete="email" inputmode="email"
            :class="{ 'is-bad': errors.email }" :aria-invalid="!!errors.email"
            placeholder="alex@acme.com"
          />
          <p v-if="errors.email" class="field__err">{{ errors.email }}</p>
        </div>

        <div class="field">
          <label for="rf-usecase">What would you use it for?</label>
          <div class="select">
            <select
              id="rf-usecase" v-model="form.useCase"
              :class="{ 'is-bad': errors.useCase, 'is-placeholder': !form.useCase }"
              :aria-invalid="!!errors.useCase"
            >
              <option value="" disabled>Choose a use case…</option>
              <option v-for="u in useCases" :key="u" :value="u">{{ u }}</option>
            </select>
          </div>
          <p v-if="errors.useCase" class="field__err">{{ errors.useCase }}</p>
        </div>

        <div class="field">
          <label for="rf-message">Anything else? <span class="field__opt">(optional)</span></label>
          <textarea
            id="rf-message" v-model="form.message" rows="3" maxlength="1000"
            placeholder="Fleet size, MDM you use, timelines, questions…"
          ></textarea>
        </div>

        <!-- honeypot: hidden from humans, catches bots -->
        <div class="hp" aria-hidden="true">
          <label>Company<input v-model="form.company" type="text" tabindex="-1" autocomplete="off" /></label>
        </div>

        <div class="rf__foot">
          <button class="btn rf__submit" type="submit" :disabled="state === 'sending'">
            {{ state === 'sending' ? 'Sending…' : 'Register interest' }}
          </button>
          <p class="rf__fine">
            No spam. We’ll only use your details to talk to you about the LaunchRights beta.
          </p>
        </div>

        <p v-if="state === 'error'" class="rf__err" role="alert">{{ errorMsg }}</p>
      </form>
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
.cta__lede { margin-inline: auto; margin-bottom: 2.6rem; }

/* ---- Form ---- */
.rf { text-align: left; max-width: 560px; margin-inline: auto; }
.rf__row { display: grid; grid-template-columns: 1fr 1fr; gap: 1.1rem; }
.field { margin-bottom: 1.1rem; display: flex; flex-direction: column; gap: 0.45rem; }

.field label {
  font-family: var(--font-mono); font-size: 0.72rem; letter-spacing: 0.1em;
  text-transform: uppercase; color: var(--tx-lo-d);
}
.field input,
.field textarea,
.select select {
  width: 100%;
  font-family: var(--font-body); font-size: 1rem; color: var(--tx-hi-d);
  background: var(--ink-2); border: 1px solid var(--hair-d-2); border-radius: 10px;
  padding: 0.8rem 0.95rem;
  transition: border-color 0.15s ease, background 0.15s ease;
}
.field textarea { resize: vertical; min-height: 3.2rem; line-height: 1.5; }
.field input::placeholder,
.field textarea::placeholder { color: var(--tx-lo-d); opacity: 0.7; }
.field input:hover,
.field textarea:hover,
.select select:hover { border-color: var(--brass); }
.field input:focus-visible,
.field textarea:focus-visible,
.select select:focus-visible { border-color: var(--jade); }
.field input.is-bad,
.select select.is-bad { border-color: var(--deny); }

.field__opt { text-transform: none; letter-spacing: 0; opacity: 0.7; }

.field__err { color: var(--deny); font-size: 0.82rem; margin: 0; }

/* select with custom chevron */
.select { position: relative; }
.select::after {
  content: ""; position: absolute; right: 1rem; top: 50%;
  width: 8px; height: 8px; margin-top: -6px;
  border-right: 1.5px solid var(--tx-lo-d); border-bottom: 1.5px solid var(--tx-lo-d);
  transform: rotate(45deg); pointer-events: none;
}
.select select {
  appearance: none; -webkit-appearance: none; cursor: pointer; padding-right: 2.4rem;
}
.select select.is-placeholder { color: var(--tx-lo-d); }
.select option { color: var(--tx-hi-l); }

/* honeypot */
.hp { position: absolute; left: -9999px; width: 1px; height: 1px; overflow: hidden; }

.rf__foot {
  display: flex; align-items: center; flex-wrap: wrap; gap: 0.9rem 1.3rem;
  margin-top: 1.6rem;
}
.rf__submit { flex: none; }
.rf__submit:disabled { opacity: 0.6; cursor: progress; transform: none; }
.rf__fine { color: var(--tx-lo-d); font-size: 0.82rem; max-width: 30ch; }
.rf__err { color: var(--deny); font-size: 0.9rem; margin-top: 1rem; }

/* ---- Success ---- */
.thanks {
  max-width: 520px; margin: 0.5rem auto 0;
  border: 1px solid var(--hair-d-2); border-radius: var(--radius);
  background: var(--ink-2); padding: clamp(2rem, 5vw, 3rem);
}
.thanks__check {
  display: grid; place-items: center; width: 52px; height: 52px; margin: 0 auto 1.1rem;
  border-radius: 50%; background: rgba(52,214,160,0.14); border: 1px solid var(--jade);
  color: var(--jade); font-size: 1.5rem; line-height: 1;
}
.thanks__h { font-size: 1.5rem; margin-bottom: 0.7rem; }
.thanks__p { color: var(--tx-lo-d); font-size: 0.98rem; }

@media (max-width: 560px) {
  .rf__row { grid-template-columns: 1fr; }
}
</style>
