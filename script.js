const header = document.querySelector('.site-header');
const menu = document.querySelector('.menu');
const nav = document.querySelector('.nav');
const themeToggle = document.querySelector('.theme-toggle');
const themeLabel = document.querySelector('.theme-toggle__label');
const themeIcon = document.querySelector('.theme-toggle__icon');

const setTheme = (isDark) => {
  document.body.classList.toggle('dark-mode', isDark);
  themeToggle?.setAttribute('aria-pressed', String(isDark));
  themeToggle?.setAttribute('aria-label', isDark ? 'Ativar modo claro' : 'Ativar modo escuro');
  if (themeLabel) themeLabel.textContent = isDark ? 'claro' : 'escuro';
  if (themeIcon) themeIcon.textContent = isDark ? '☀' : '☾';
  try { localStorage.setItem('omdu-theme', isDark ? 'dark' : 'light'); } catch { /* Preferência mantida nesta visita. */ }
};

const setMenu = (open) => {
  nav?.classList.toggle('open', open);
  menu?.setAttribute('aria-expanded', String(open));
  menu?.setAttribute('aria-label', open ? 'Fechar menu' : 'Abrir menu');
};

let savedTheme;
try { savedTheme = localStorage.getItem('omdu-theme'); } catch { /* Usa a preferência do sistema. */ }
setTheme(savedTheme ? savedTheme === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches);

if (header) addEventListener('scroll', () => header.classList.toggle('scrolled', scrollY > 30));
menu?.addEventListener('click', () => setMenu(!nav?.classList.contains('open')));
document.querySelectorAll('.nav a').forEach((link) => link.addEventListener('click', () => setMenu(false)));
themeToggle?.addEventListener('click', () => setTheme(!document.body.classList.contains('dark-mode')));

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && nav?.classList.contains('open')) {
    setMenu(false);
    menu?.focus();
  }
});
document.addEventListener('click', (event) => {
  if (header && !header.contains(event.target)) setMenu(false);
});
window.matchMedia('(min-width: 761px)').addEventListener('change', () => setMenu(false));

// Permite compartilhar o link direto de um integrante sem exigir JavaScript para abrir os cards.
const openArtistFromHash = () => {
  const artist = document.getElementById(location.hash.slice(1));
  if (artist?.matches('details.artist')) {
    artist.open = true;
    artist.scrollIntoView({ block: 'start' });
  }
};
window.addEventListener('hashchange', openArtistFromHash);
openArtistFromHash();

const gallery = document.querySelector('.event-gallery');

if (gallery) {
  const book = gallery.querySelector('.gallery-book');
  const previous = gallery.querySelector('.gallery-prev');
  const next = gallery.querySelector('.gallery-next');
  const status = gallery.querySelector('.gallery-status');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  let pages = [];
  let current = 0;
  let turning = false;
  let pointerStart = null;
  let suppressClickUntil = 0;

  const normalizeManifestItem = (item) => {
    const raw = typeof item === 'string' ? item : item?.src;
    if (!raw || typeof raw !== 'string') return null;

    // Aceita tanto "foto.jpg" quanto "images/gallery/foto.jpg".
    const src = raw.startsWith('images/')
      ? raw.replaceAll('\\', '/')
      : `images/gallery/${raw.replaceAll('\\', '/')}`;

    return { src };
  };

  const updateStatus = () => {
    if (!pages.length) {
      status.textContent = 'Nenhuma foto encontrada';
      book.disabled = true;
      previous.disabled = true;
      next.disabled = true;
      return;
    }

    status.textContent = `Foto ${current + 1} de ${pages.length}`;

    const img = pages[current].querySelector('img');
    book.setAttribute(
      'aria-label',
      `${img?.alt || 'Registro fotográfico'}. Ver próxima foto.`
    );

    const disabled = pages.length < 2;
    book.disabled = disabled;
    previous.disabled = disabled;
    next.disabled = disabled;
  };

  const createGallery = (items) => {
    const images = items
      .map(normalizeManifestItem)
      .filter(Boolean);

    book.innerHTML = '';

    images.forEach(({ src }, index) => {
      const page = document.createElement('span');
      page.className = 'gallery-page';
      page.hidden = index !== 0;

      const img = document.createElement('img');
      img.src = src;
      img.alt = `Registro fotográfico do coletivo em evento — foto ${index + 1}`;
      img.loading = index === 0 ? 'eager' : 'lazy';
      img.decoding = 'async';
      img.draggable = false;

      // Se um arquivo não carregar, ele é removido da galeria automaticamente.
      img.addEventListener('error', () => {
        page.remove();
        pages = [...book.querySelectorAll('.gallery-page')];

        if (!pages.length) {
          current = 0;
          updateStatus();
          return;
        }

        if (current >= pages.length) current = pages.length - 1;
        pages.forEach((p, i) => { p.hidden = i !== current; });
        updateStatus();
      });

      page.appendChild(img);
      book.appendChild(page);
    });

    pages = [...book.querySelectorAll('.gallery-page')];
    current = 0;
    updateStatus();
  };

  const loadGallery = async () => {
    try {
      const response = await fetch('images/gallery/manifest.json', {
        cache: 'no-store'
      });

      if (!response.ok) {
        throw new Error(`Erro HTTP ${response.status}`);
      }

      const manifest = await response.json();

      if (!Array.isArray(manifest)) {
        throw new Error('manifest.json precisa conter uma lista de imagens.');
      }

      createGallery(manifest);
    } catch (error) {
      console.error('Erro ao carregar a galeria:', error);
      status.textContent = 'Não foi possível carregar a galeria.';
      book.disabled = true;
      previous.disabled = true;
      next.disabled = true;
    }
  };

  const turnPage = async (direction) => {
    if (turning || pages.length < 2) return;

    turning = true;
    const destination = (current + direction + pages.length) % pages.length;
    const outgoing = pages[current];
    const incoming = pages[destination];

    incoming.hidden = false;
    outgoing.style.zIndex = '2';
    outgoing.style.transformOrigin =
      direction > 0 ? 'left center' : 'right center';

    try {
      const incomingImg = incoming.querySelector('img');

      if (incomingImg?.decode) {
        await incomingImg.decode().catch(() => {});
      }

      if (!reducedMotion.matches && outgoing.animate) {
        const animation = outgoing.animate(
          [
            { transform: 'rotateY(0deg)', opacity: 1, filter: 'brightness(1)' },
            {
              transform: `rotateY(${direction > 0 ? -55 : 55}deg)`,
              opacity: 1,
              filter: 'brightness(.65)',
              offset: .6
            },
            {
              transform: `rotateY(${direction > 0 ? -100 : 100}deg)`,
              opacity: 0,
              filter: 'brightness(.4)'
            }
          ],
          {
            duration: 520,
            easing: 'cubic-bezier(.22,.61,.36,1)'
          }
        );

        await animation.finished.catch(() => {});
      }
    } finally {
      outgoing.hidden = true;
      outgoing.style.zIndex = '';
      outgoing.style.transformOrigin = '';
      current = destination;
      turning = false;
      updateStatus();
    }
  };

  previous?.addEventListener('click', () => turnPage(-1));
  next?.addEventListener('click', () => turnPage(1));

  book?.addEventListener('click', () => {
    if (Date.now() >= suppressClickUntil) turnPage(1);
  });

  gallery.addEventListener('keydown', (event) => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      turnPage(event.key === 'ArrowRight' ? 1 : -1);
    }
  });

  book?.addEventListener('pointerdown', (event) => {
    if (!event.isPrimary || event.button !== 0) return;

    pointerStart = {
      x: event.clientX,
      y: event.clientY,
      id: event.pointerId
    };

    book.setPointerCapture(event.pointerId);
  });

  book?.addEventListener('pointerup', (event) => {
    if (!pointerStart || event.pointerId !== pointerStart.id) return;

    const dx = event.clientX - pointerStart.x;
    const dy = event.clientY - pointerStart.y;
    pointerStart = null;

    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.3) {
      suppressClickUntil = Date.now() + 500;
      turnPage(dx < 0 ? 1 : -1);
    } else if (Math.abs(dy) > 15) {
      suppressClickUntil = Date.now() + 500;
    }
  });

  book?.addEventListener('pointercancel', () => {
    pointerStart = null;
  });

  loadGallery();
}

