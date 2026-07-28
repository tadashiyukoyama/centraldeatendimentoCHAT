import { describe, expect, it, vi } from 'vitest';
import {
  buildSentryOptions,
  scrubSentryEvent,
} from 'dashboard/helper/sentryHelper';

describe('sentryHelper', () => {
  it('removes contact data, credentials, bodies, and URL parameters', () => {
    const event = scrubSentryEvent({
      user: { id: 7, email: 'customer@example.com' },
      message: 'Falha para customer@example.com',
      request: {
        url: 'https://atendimento.example.com/api/v1/contacts?phone=5511999999999',
        data: { message: 'private conversation' },
        cookies: { session: 'secret' },
        headers: {
          Authorization: 'Bearer secret-token',
          Accept: 'application/json',
        },
      },
      extra: {
        contact_email: 'customer@example.com',
        nested: {
          api_key: 'secret',
          phone: '+55 (11) 99999-9999',
          safe: 'value',
        },
      },
      contexts: {
        contact: {
          phone: '+55 (11) 99999-9999',
          referrer: 'https://example.com/private?email=customer@example.com',
        },
      },
      exception: {
        values: [{ value: 'CPF 123.456.789-00 inválido' }],
      },
      breadcrumbs: [
        {
          category: 'xhr',
          data: {
            url: 'https://atendimento.example.com/api/messages?token=secret',
            request_body: 'private message',
            status_code: 500,
          },
        },
      ],
    });

    expect(event.user).toEqual({});
    expect(event.message).toBe('Falha para [Filtered]');
    expect(event.request.url).toBe(
      'https://atendimento.example.com/api/v1/contacts'
    );
    expect(event.request.data).toBeUndefined();
    expect(event.request.cookies).toBeUndefined();
    expect(event.request.headers.Authorization).toBe('[Filtered]');
    expect(event.extra.contact_email).toBe('[Filtered]');
    expect(event.extra.nested).toEqual({
      api_key: '[Filtered]',
      phone: '[Filtered]',
      safe: 'value',
    });
    expect(event.contexts.contact.phone).toBe('[Filtered]');
    expect(event.contexts.contact.referrer).toBe('https://example.com/private');
    expect(event.exception.values[0].value).toBe('CPF [Filtered] inválido');
    expect(event.breadcrumbs[0].data.url).toBe(
      'https://atendimento.example.com/api/messages'
    );
    expect(event.breadcrumbs[0].data.request_body).toBeUndefined();
  });

  it('keeps tracing disabled by default and never enables default PII', () => {
    const browserTracingIntegration = vi.fn();
    const options = buildSentryOptions(
      {
        dsn: 'https://public@example.com/1',
        environment: 'production',
        release: 'a'.repeat(40),
      },
      { app: {}, router: {}, browserTracingIntegration }
    );

    expect(options).toMatchObject({
      dsn: 'https://public@example.com/1',
      environment: 'production',
      release: 'a'.repeat(40),
      sendDefaultPii: false,
      tracesSampleRate: 0,
      integrations: [],
    });
    expect(browserTracingIntegration).not.toHaveBeenCalled();
  });

  it('enables browser tracing only at the configured sample rate', () => {
    const integration = {};
    const browserTracingIntegration = vi.fn(() => integration);
    const router = {};
    const options = buildSentryOptions(
      {
        dsn: 'https://public@example.com/1',
        tracesSampleRate: 0.05,
      },
      { app: {}, router, browserTracingIntegration }
    );

    expect(options.tracesSampleRate).toBe(0.05);
    expect(options.integrations).toEqual([integration]);
    expect(browserTracingIntegration).toHaveBeenCalledWith({ router });
  });
});
