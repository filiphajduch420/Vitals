document.addEventListener('DOMContentLoaded', () => {
  const allTabs = document.querySelectorAll('[role="tab"]');
  const allPanels = document.querySelectorAll('[role="tabpanel"]');

  // --- Scroll reveal ---
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -32px 0px'
  });

  function observeActive() {
    document.querySelectorAll('.tab-content.active .reveal:not(.visible)').forEach(el => {
      observer.observe(el);
    });
  }

  // --- Tab switching ---
  function switchTab(id) {
    allPanels.forEach(p => p.classList.remove('active'));

    const panel = document.getElementById('tab-' + id);
    if (panel) panel.classList.add('active');

    allTabs.forEach(t => {
      const isActive = t.dataset.tab === id;
      t.setAttribute('aria-selected', String(isActive));
      t.setAttribute('tabindex', isActive ? '0' : '-1');
    });

    window.scrollTo({ top: 0, behavior: 'smooth' });
    requestAnimationFrame(observeActive);
  }

  document.querySelectorAll('[data-tab]').forEach(el => {
    el.addEventListener('click', e => {
      e.preventDefault();
      if (el.dataset.tab) switchTab(el.dataset.tab);
    });
  });

  // --- Keyboard navigation for tablist ---
  const tabList = document.querySelector('[role="tablist"]');
  if (tabList) {
    tabList.addEventListener('keydown', e => {
      if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
      e.preventDefault();

      const tabs = Array.from(tabList.querySelectorAll('[role="tab"]'));
      const idx = tabs.indexOf(document.activeElement);
      if (idx === -1) return;

      const next = e.key === 'ArrowRight'
        ? (idx + 1) % tabs.length
        : (idx - 1 + tabs.length) % tabs.length;

      tabs[next].focus();
      switchTab(tabs[next].dataset.tab);
    });
  }

  // --- Initial reveal ---
  observeActive();
});
