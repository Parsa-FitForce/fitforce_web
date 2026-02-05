/* ============================================
   FitForce Landing Page — script.js
   Form handling, animations, nav behavior
   ============================================ */

(function () {
  'use strict';

  // --- Configuration ---
  // Update this after deploying the SAM stack
  var API_URL = '';

  // --- Nav scroll effect ---
  var nav = document.getElementById('nav');
  var scrollThreshold = 10;

  function onScroll() {
    if (window.scrollY > scrollThreshold) {
      nav.classList.add('is-scrolled');
    } else {
      nav.classList.remove('is-scrolled');
    }
  }

  window.addEventListener('scroll', onScroll, { passive: true });

  // --- Scroll animations (IntersectionObserver) ---
  var animatedElements = document.querySelectorAll('[data-animate]');

  if ('IntersectionObserver' in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15 });

    animatedElements.forEach(function (el) {
      observer.observe(el);
    });
  } else {
    // Fallback: show everything
    animatedElements.forEach(function (el) {
      el.classList.add('is-visible');
    });
  }

  // --- Counter animation for stats ---
  var statNumbers = document.querySelectorAll('[data-count]');

  function animateCounter(el) {
    var target = parseInt(el.getAttribute('data-count'), 10);
    var prefix = el.getAttribute('data-prefix') || '';
    var dataSuffix = el.getAttribute('data-suffix') || '';
    var suffix = dataSuffix || el.textContent.replace(/[\d,$]/g, '').trim();
    var duration = 1500;
    var startTime = null;

    function step(timestamp) {
      if (!startTime) startTime = timestamp;
      var progress = Math.min((timestamp - startTime) / duration, 1);
      var eased = 1 - (1 - progress) * (1 - progress);
      var current = Math.floor(eased * target);

      var display = '';
      if (prefix === '$') {
        display = '$' + current.toLocaleString();
      } else {
        display = String(current);
      }
      if (suffix) display += (suffix.charAt(0) === ' ' ? '' : ' ') + suffix;
      el.textContent = display;

      if (progress < 1) {
        requestAnimationFrame(step);
      }
    }

    requestAnimationFrame(step);
  }

  if ('IntersectionObserver' in window) {
    var counterObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          animateCounter(entry.target);
          counterObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.3 });

    statNumbers.forEach(function (el) {
      counterObserver.observe(el);
    });
  }

  // --- Email validation ---
  function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // --- Form submission ---
  function setupForm(formId, emailId, messageId) {
    var form = document.getElementById(formId);
    var emailInput = document.getElementById(emailId);
    var messageEl = document.getElementById(messageId);

    if (!form) return;

    form.addEventListener('submit', function (e) {
      e.preventDefault();

      var email = emailInput.value.trim();
      var btn = form.querySelector('.btn--form');

      // Clear previous messages
      messageEl.textContent = '';
      messageEl.className = 'form__message';

      // Validate
      if (!email || !isValidEmail(email)) {
        messageEl.textContent = 'Please enter a valid email address.';
        messageEl.classList.add('form__message--error');
        emailInput.focus();
        return;
      }

      // Loading state
      btn.classList.add('is-loading');
      btn.disabled = true;

      // If no API URL configured, simulate success (local testing)
      if (!API_URL) {
        setTimeout(function () {
          btn.classList.remove('is-loading');
          btn.disabled = false;
          messageEl.textContent = "You're on the list! We'll be in touch soon.";
          messageEl.classList.add('form__message--success');
          emailInput.value = '';
        }, 800);
        return;
      }

      // Submit to API
      fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email })
      })
        .then(function (res) {
          return res.json().then(function (data) {
            return { status: res.status, data: data };
          });
        })
        .then(function (result) {
          btn.classList.remove('is-loading');
          btn.disabled = false;

          if (result.status >= 200 && result.status < 300) {
            messageEl.textContent = result.data.message || "You're on the list! We'll be in touch soon.";
            messageEl.classList.add('form__message--success');
            emailInput.value = '';
          } else if (result.status === 409) {
            messageEl.textContent = result.data.message || "You're already on the waitlist!";
            messageEl.classList.add('form__message--success');
            emailInput.value = '';
          } else {
            messageEl.textContent = result.data.message || 'Something went wrong. Please try again.';
            messageEl.classList.add('form__message--error');
          }
        })
        .catch(function () {
          btn.classList.remove('is-loading');
          btn.disabled = false;
          messageEl.textContent = 'Network error. Please check your connection and try again.';
          messageEl.classList.add('form__message--error');
        });
    });
  }

  setupForm('hero-form', 'hero-email', 'hero-message');
  setupForm('footer-form', 'footer-email', 'footer-message');

  // --- Smooth scroll for anchor links ---
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener('click', function (e) {
      var targetId = this.getAttribute('href');
      if (targetId === '#') return;
      var target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        var offset = 80; // nav height
        var top = target.getBoundingClientRect().top + window.pageYOffset - offset;
        window.scrollTo({ top: top, behavior: 'smooth' });
      }
    });
  });

})();
