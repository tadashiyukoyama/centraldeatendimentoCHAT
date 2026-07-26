export const showBadgeOnFavicon = () => {
  const favicons = document.querySelectorAll('.favicon');

  favicons.forEach(favicon => {
    const normalHref =
      favicon.dataset.normalHref || favicon.getAttribute('href');
    favicon.dataset.normalHref = normalHref;
    const badgeURL = new URL(normalHref, window.location.origin);
    const size = favicon.getAttribute('sizes');
    badgeURL.pathname = badgeURL.pathname.replace(
      /favicon-(?:badge-)?\d+x\d+\.png$/,
      `favicon-badge-${size}.png`
    );
    favicon.href = badgeURL.toString();
  });
};

export const initFaviconSwitcher = () => {
  const favicons = document.querySelectorAll('.favicon');

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      favicons.forEach(favicon => {
        const normalHref = favicon.dataset.normalHref;
        if (normalHref) favicon.href = normalHref;
      });
    }
  });
};
