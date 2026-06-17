/* ============================================
   FitForce — Shared Nav Component (nav.js)
   Single source of truth for nav across all pages.
   Include via <script src="/nav.js"></script>
   ============================================ */

(function () {
  'use strict';

  var isHome = (location.pathname === '/' || location.pathname === '/index.html');
  var prefix = isHome ? '' : '/';

  // --- Render nav HTML ---
  var placeholder = document.getElementById('nav');
  if (!placeholder) return;

  placeholder.className = 'nav';
  placeholder.innerHTML =
    '<div class="container nav__inner">' +
      '<a href="' + prefix + '" class="nav__logo">' +
        '<svg class="nav__logo-icon" width="32" height="32" viewBox="0 0 512 512" fill="none" aria-hidden="true">' +
          '<defs><linearGradient id="logo-g" x1="0" y1="0" x2="512" y2="512" gradientUnits="userSpaceOnUse"><stop stop-color="#F97316"/><stop offset=".5" stop-color="#E11D48"/><stop offset="1" stop-color="#7C3AED"/></linearGradient></defs>' +
          '<rect x="20" y="20" width="472" height="472" rx="100" fill="url(#logo-g)"/>' +
          '<rect x="20" y="20" width="472" height="472" rx="100" fill="#06001a" opacity="0.18"/>' +
          '<path d="M148,260 L256,152 L364,260" stroke="#fff" stroke-width="52" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.95"/>' +
          '<path d="M148,360 L256,252 L364,360" stroke="#fff" stroke-width="42" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.5"/>' +
        '</svg>' +
        '<span>FitForce</span>' +
      '</a>' +
      '<button class="nav__hamburger" id="nav-toggle" aria-label="Toggle menu" aria-expanded="false">' +
        '<span class="nav__hamburger-line"></span>' +
        '<span class="nav__hamburger-line"></span>' +
        '<span class="nav__hamburger-line"></span>' +
      '</button>' +
      '<div class="nav__menu" id="nav-menu">' +
        '<a href="' + prefix + '#mcp" class="nav__link">AI Apps</a>' +
        '<a href="' + prefix + '#features" class="nav__link">Features</a>' +
        '<a href="' + prefix + '#how" class="nav__link">How It Works</a>' +
        '<a href="' + prefix + '#faq" class="nav__link">FAQ</a>' +
        '<a href="/blog/" class="nav__link">Blog</a>' +
        '<a href="' + prefix + '#signup" class="btn btn--sm btn--nav">' +
          '<span class="btn__short">Sign Up</span>' +
          '<span class="btn__full">Get Early Access</span>' +
        '</a>' +
        '<a href="https://app.fitforce.com" class="btn btn--sm btn--nav-outline">Open App</a>' +
      '</div>' +
    '</div>';

  // --- Scroll effect ---
  function onScroll() {
    if (window.scrollY > 10) {
      placeholder.classList.add('is-scrolled');
    } else {
      placeholder.classList.remove('is-scrolled');
    }
  }
  window.addEventListener('scroll', onScroll, { passive: true });

  // --- Mobile menu toggle ---
  var toggle = document.getElementById('nav-toggle');
  var menu = document.getElementById('nav-menu');

  function closeMenu() {
    menu.classList.remove('is-open');
    toggle.classList.remove('is-active');
    toggle.setAttribute('aria-expanded', 'false');
  }

  toggle.addEventListener('click', function () {
    var isOpen = menu.classList.toggle('is-open');
    toggle.classList.toggle('is-active', isOpen);
    toggle.setAttribute('aria-expanded', String(isOpen));
  });

  menu.querySelectorAll('.nav__link, .btn--nav').forEach(function (link) {
    link.addEventListener('click', closeMenu);
  });

  document.addEventListener('click', function (e) {
    if (!placeholder.contains(e.target)) {
      closeMenu();
    }
  });

  // --- Smooth scroll for anchor links (homepage only) ---
  if (isHome) {
    menu.querySelectorAll('a[href^="#"]').forEach(function (link) {
      link.addEventListener('click', function (e) {
        var targetId = this.getAttribute('href');
        if (targetId === '#') return;
        var target = document.querySelector(targetId);
        if (target) {
          e.preventDefault();
          var top = target.getBoundingClientRect().top + window.pageYOffset - 80;
          window.scrollTo({ top: top, behavior: 'smooth' });
        }
      });
    });
  }
})();
