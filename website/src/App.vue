<script setup>
import SiteNav from './components/SiteNav.vue'
import HeroElevation from './components/HeroElevation.vue'
import TrustStrip from './components/TrustStrip.vue'
import ProblemSection from './components/ProblemSection.vue'
import HowItWorks from './components/HowItWorks.vue'
import FeatureGrid from './components/FeatureGrid.vue'
import ComplianceSection from './components/ComplianceSection.vue'
import BetaSignup from './components/BetaSignup.vue'
import SiteFooter from './components/SiteFooter.vue'
</script>

<template>
  <a class="skip" href="#main">Skip to content</a>
  <SiteNav />
  <main id="main">
    <HeroElevation />
    <TrustStrip />
    <ProblemSection />
    <HowItWorks />
    <FeatureGrid />
    <ComplianceSection />
    <BetaSignup />
  </main>
  <SiteFooter />
</template>

<style scoped>
.skip {
  position: absolute;
  left: -999px;
  top: 0;
  z-index: 100;
  background: var(--brass);
  color: #1a1204;
  padding: 0.6rem 1rem;
  border-radius: 0 0 8px 0;
  font-family: var(--font-display);
  font-weight: 600;
}
.skip:focus { left: 0; }
</style>
