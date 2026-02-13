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
        '<svg class="nav__logo-icon" width="32" height="32" viewBox="0 0 32 32" fill="none" aria-hidden="true">' +
          '<defs><linearGradient id="logo-g" x1="0" y1="0" x2="32" y2="32" gradientUnits="userSpaceOnUse"><stop stop-color="#F97316"/><stop offset=".5" stop-color="#E11D48"/><stop offset="1" stop-color="#7C3AED"/></linearGradient></defs>' +
          '<rect width="32" height="32" rx="9" fill="url(#logo-g)"/>' +
          '<path d="M19 5L10 17.5h5.5L13 27l9.5-13H17L19 5z" fill="#fff" fill-opacity=".95"/>' +
        '</svg>' +
        '<span>FitForce</span>' +
      '</a>' +
      '<button class="nav__hamburger" id="nav-toggle" aria-label="Toggle menu" aria-expanded="false">' +
        '<span class="nav__hamburger-line"></span>' +
        '<span class="nav__hamburger-line"></span>' +
        '<span class="nav__hamburger-line"></span>' +
      '</button>' +
      '<div class="nav__menu" id="nav-menu">' +
        '<a href="' + prefix + '#features" class="nav__link">Features</a>' +
        '<a href="' + prefix + '#how" class="nav__link">How It Works</a>' +
        '<a href="' + prefix + '#faq" class="nav__link">FAQ</a>' +
        '<a href="/blog/" class="nav__link">Blog</a>' +
        '<a href="' + prefix + '#signup" class="btn btn--sm btn--nav">' +
          '<span class="btn__short">Sign Up</span>' +
          '<span class="btn__full">Get Early Access</span>' +
        '</a>' +
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
