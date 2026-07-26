import { initFaviconSwitcher, showBadgeOnFavicon } from '../faviconHelper';

describe('faviconHelper', () => {
  beforeEach(() => {
    document.head.innerHTML = `
      <link class="favicon" sizes="32x32" href="/brand-assets/acelerachat/pwa/favicon-32x32.png">
    `;
  });

  it('keeps the branded asset directory when adding the badge', () => {
    showBadgeOnFavicon();

    expect(document.querySelector('.favicon').href).toContain(
      '/brand-assets/acelerachat/pwa/favicon-badge-32x32.png'
    );
  });

  it('restores the exact normal favicon URL', () => {
    const favicon = document.querySelector('.favicon');
    showBadgeOnFavicon();
    initFaviconSwitcher();
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'visible',
    });

    document.dispatchEvent(new Event('visibilitychange'));

    expect(favicon.getAttribute('href')).toBe(
      '/brand-assets/acelerachat/pwa/favicon-32x32.png'
    );
  });
});
