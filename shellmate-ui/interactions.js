/* ShellMate — Micro-interactions */

// Session item click
document.querySelectorAll('.session-item').forEach(item => {
  item.addEventListener('click', function() {
    document.querySelectorAll('.session-item').forEach(s => s.classList.remove('active'));
    this.classList.add('active');
  });
});

// Tab click
document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', function(e) {
    if (e.target.classList.contains('tab-close')) return;
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    this.classList.add('active');
  });
});

// Tab close
document.querySelectorAll('.tab-close').forEach(btn => {
  btn.addEventListener('click', function(e) {
    e.stopPropagation();
    const tab = this.closest('.tab');
    if (document.querySelectorAll('.tab').length > 1) {
      tab.remove();
    }
  });
});

// Group collapse toggle
document.querySelectorAll('.group-header').forEach(header => {
  header.addEventListener('click', function(e) {
    if (e.target.classList.contains('group-add')) return;
    const group = this.closest('.session-group');
    const sessions = group.querySelector('.group-sessions');
    const arrow = this.querySelector('.group-arrow');
    const isExpanded = !arrow.classList.contains('collapsed');
    if (isExpanded) {
      sessions.style.display = 'none';
      arrow.classList.add('collapsed');
    } else {
      sessions.style.display = '';
      arrow.classList.remove('collapsed');
    }
  });
});

// Transfer progress animation
let progress = 68;
const fill = document.querySelector('.tq-fill');
if (fill) {
  setInterval(() => {
    progress = Math.min(100, progress + Math.random() * 2);
    fill.style.width = progress + '%';
    if (progress >= 100) {
      const badge = document.querySelector('.tq-badge');
      if (badge) {
        badge.style.background = 'var(--green)';
        badge.textContent = '✓';
      }
    }
  }, 400);
}

// Latency ping update
const latency = document.querySelector('.sb-item.latency');
if (latency) {
  setInterval(() => {
    const ms = Math.floor(8 + Math.random() * 18);
    latency.textContent = '⌁ ' + ms + 'ms';
    latency.style.color = ms > 20 ? 'var(--amber)' : 'var(--tm-cyan)';
  }, 5000);
}

// New session button
const newBtn = document.querySelector('.new-session-btn');
if (newBtn) {
  newBtn.addEventListener('click', () => {
    newBtn.style.transform = 'scale(0.97)';
    setTimeout(() => newBtn.style.transform = '', 120);
  });
}

// Keyboard shortcut hints in title
document.addEventListener('keydown', e => {
  if (e.metaKey && e.key === 'f') {
    e.preventDefault();
    const input = document.querySelector('.search-input');
    if (input) { input.focus(); input.select(); }
  }
});
