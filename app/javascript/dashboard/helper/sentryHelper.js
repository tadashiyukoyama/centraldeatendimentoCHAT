const FILTERED = '[Filtered]';
const SENSITIVE_KEY_PATTERN =
  /authorization|cookie|token|secret|password|passwd|api[-_]?key|access[-_]?key|csrf|session/i;
const URL_KEY_PATTERN = /^(url|uri|request_url|referer|referrer)$/i;
const EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const BEARER_PATTERN = /\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi;
const PHONE_OR_DOCUMENT_PATTERN = /(^|\W)\+?\d[\d\s().-]{7,}\d(?=\W|$)/g;

const stripUrlDetails = value => {
  if (typeof value !== 'string') return value;

  try {
    const url = new URL(value, window.location.origin);
    url.search = '';
    url.hash = '';
    return url.toString();
  } catch {
    return value.split(/[?#]/, 1)[0];
  }
};

const sanitizeString = value => {
  if (typeof value !== 'string') return value;

  return value
    .replace(BEARER_PATTERN, `Bearer ${FILTERED}`)
    .replace(EMAIL_PATTERN, FILTERED)
    .replace(PHONE_OR_DOCUMENT_PATTERN, (match, prefix) => {
      return `${prefix}${FILTERED}`;
    });
};

const sanitizeValue = (value, depth = 0) => {
  if (depth > 5) return FILTERED;
  if (typeof value === 'string') return sanitizeString(value);
  if (Array.isArray(value)) {
    return value.map(item => sanitizeValue(item, depth + 1));
  }
  if (!value || typeof value !== 'object') return value;

  return Object.entries(value).reduce((result, [key, item]) => {
    if (SENSITIVE_KEY_PATTERN.test(key)) {
      result[key] = FILTERED;
    } else if (URL_KEY_PATTERN.test(key)) {
      result[key] = stripUrlDetails(item);
    } else {
      result[key] = sanitizeValue(item, depth + 1);
    }
    return result;
  }, {});
};

const sanitizeRequest = request => {
  if (!request) return request;

  const sanitized = sanitizeValue(request);
  sanitized.url = stripUrlDetails(sanitized.url);
  delete sanitized.data;
  delete sanitized.cookies;
  delete sanitized.query_string;
  return sanitized;
};

const sanitizeBreadcrumb = breadcrumb => {
  const sanitized = sanitizeValue(breadcrumb);
  if (sanitized?.data?.url) {
    sanitized.data.url = stripUrlDetails(sanitized.data.url);
  }
  if (sanitized?.data) {
    delete sanitized.data.request_body;
    delete sanitized.data.response_body;
  }
  return sanitized;
};

export const scrubSentryEvent = event => {
  const sanitized = {
    ...event,
    user: {},
    message: sanitizeString(event.message),
    request: sanitizeRequest(event.request),
    tags: sanitizeValue(event.tags),
    contexts: sanitizeValue(event.contexts),
    extra: sanitizeValue(event.extra),
    exception: sanitizeValue(event.exception),
  };

  if (event.breadcrumbs) {
    sanitized.breadcrumbs = event.breadcrumbs.map(sanitizeBreadcrumb);
  }

  return sanitized;
};

export const buildSentryOptions = (
  rawConfig,
  { app, router, browserTracingIntegration }
) => {
  const config =
    typeof rawConfig === 'string' ? { dsn: rawConfig } : rawConfig || {};
  const tracesSampleRate = Number(config.tracesSampleRate || 0);

  return {
    app,
    dsn: config.dsn,
    environment: config.environment,
    release: config.release,
    sendDefaultPii: false,
    tracesSampleRate,
    tracePropagationTargets: [window.location.origin],
    maxBreadcrumbs: 30,
    beforeSend: scrubSentryEvent,
    beforeSendTransaction: scrubSentryEvent,
    denyUrls: [
      /^chrome:\/\//i,
      /chrome-extension:/i,
      /extensions\//i,
      /file:\/\//i,
      /safari-web-extension:/i,
      /safari-extension:/i,
    ],
    integrations: tracesSampleRate
      ? [browserTracingIntegration({ router })]
      : [],
    ignoreErrors: [
      'ResizeObserver loop completed with undelivered notifications',
    ],
  };
};
