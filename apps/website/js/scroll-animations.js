/* Scroll-triggered animations and navigation behavior */

(function () {
  'use strict';

  /* ---- IntersectionObserver for reveal animations ---- */
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          revealObserver.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: '-50px' }
  );

  document.querySelectorAll('.reveal').forEach((el) => {
    revealObserver.observe(el);
  });

  /* ---- Navigation scroll state ---- */
  const nav = document.querySelector('.nav');
  let lastScrollY = 0;
  let ticking = false;

  function updateNav() {
    if (window.scrollY > 50) {
      nav.classList.add('nav--scrolled');
    } else {
      nav.classList.remove('nav--scrolled');
    }
    ticking = false;
  }

  window.addEventListener('scroll', () => {
    if (!ticking) {
      window.requestAnimationFrame(updateNav);
      ticking = true;
    }
  }, { passive: true });

  /* ---- Mobile menu toggle ---- */
  const hamburger = document.querySelector('.nav__hamburger');
  const menu = document.querySelector('.nav__menu');
  const menuLinks = menu ? menu.querySelectorAll('.nav__link') : [];

  function toggleMenu() {
    const isOpen = menu.classList.toggle('nav__menu--open');
    hamburger.classList.toggle('nav__hamburger--active', isOpen);
    hamburger.setAttribute('aria-expanded', isOpen);
    document.body.style.overflow = isOpen ? 'hidden' : '';
  }

  function closeMenu() {
    menu.classList.remove('nav__menu--open');
    hamburger.classList.remove('nav__hamburger--active');
    hamburger.setAttribute('aria-expanded', 'false');
    document.body.style.overflow = '';
  }

  if (hamburger && menu) {
    hamburger.addEventListener('click', toggleMenu);

    menuLinks.forEach((link) => {
      link.addEventListener('click', closeMenu);
    });

    /* Close menu when tapping outside */
    document.addEventListener('click', (e) => {
      if (
        menu.classList.contains('nav__menu--open') &&
        !menu.contains(e.target) &&
        !hamburger.contains(e.target)
      ) {
        closeMenu();
      }
    });

    /* Close menu on Escape key */
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && menu.classList.contains('nav__menu--open')) {
        closeMenu();
        hamburger.focus();
      }
    });
  }
})();
