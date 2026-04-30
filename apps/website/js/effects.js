/* Canvas particle system for hero background */

(function () {
  'use strict';

  const canvas = document.getElementById('particles');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const PARTICLE_COUNT = 60;
  const CONNECTION_DISTANCE = 120;
  const ACCENT_COLOR = '74, 222, 128'; /* #4ade80 */

  let particles = [];
  let animationId = null;
  let isVisible = true;

  /* ---- Resize canvas to fill hero ---- */
  function resize() {
    const hero = canvas.parentElement;
    if (!hero) return;
    const rect = hero.getBoundingClientRect();
    canvas.width = rect.width * window.devicePixelRatio;
    canvas.height = rect.height * window.devicePixelRatio;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
  }

  /* ---- Particle class ---- */
  function createParticle() {
    const hero = canvas.parentElement;
    if (!hero) return null;
    const rect = hero.getBoundingClientRect();
    return {
      x: Math.random() * rect.width,
      y: Math.random() * rect.height,
      vx: (Math.random() - 0.5) * 0.4,
      vy: (Math.random() - 0.5) * 0.4,
      radius: Math.random() * 2 + 1,
      opacity: Math.random() * 0.5 + 0.2,
    };
  }

  function initParticles() {
    particles = [];
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const p = createParticle();
      if (p) particles.push(p);
    }
  }

  /* ---- Draw and update ---- */
  function draw() {
    const hero = canvas.parentElement;
    if (!hero) return;
    const w = hero.getBoundingClientRect().width;
    const h = hero.getBoundingClientRect().height;

    ctx.clearRect(0, 0, w, h);

    /* Update positions */
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      p.x += p.vx;
      p.y += p.vy;

      /* Wrap around edges */
      if (p.x < 0) p.x = w;
      if (p.x > w) p.x = 0;
      if (p.y < 0) p.y = h;
      if (p.y > h) p.y = 0;

      /* Draw particle with glow */
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${ACCENT_COLOR}, ${p.opacity})`;
      ctx.fill();

      /* Glow ring */
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.radius * 3, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${ACCENT_COLOR}, ${p.opacity * 0.15})`;
      ctx.fill();
    }

    /* Draw connections */
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const a = particles[i];
        const b = particles[j];
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < CONNECTION_DISTANCE) {
          const opacity = (1 - dist / CONNECTION_DISTANCE) * 0.15;
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = `rgba(${ACCENT_COLOR}, ${opacity})`;
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }

    animationId = requestAnimationFrame(draw);
  }

  /* ---- Visibility observer ---- */
  const heroObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        isVisible = entry.isIntersecting;
        if (isVisible && !animationId) {
          draw();
        }
      });
    },
    { threshold: 0 }
  );

  /* ---- Initialize ---- */
  function init() {
    resize();
    initParticles();
    heroObserver.observe(canvas.parentElement);
    draw();
  }

  window.addEventListener('resize', () => {
    resize();
    initParticles();
  });

  init();
})();
