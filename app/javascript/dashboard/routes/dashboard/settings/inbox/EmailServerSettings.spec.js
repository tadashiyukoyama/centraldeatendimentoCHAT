import ImapSettings from './ImapSettings.vue';
import SmtpSettings from './SmtpSettings.vue';

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('email server credential handling', () => {
  it('never copies a persisted IMAP password into component state', () => {
    const context = {
      inbox: {
        imap_enabled: true,
        imap_address: 'imap.hostinger.com',
        imap_port: 993,
        imap_login: 'support@example.com',
        imap_password: 'must-not-be-read',
        imap_password_set: true,
        imap_enable_ssl: true,
        imap_authentication: 'login',
      },
    };

    ImapSettings.methods.setDefaults.call(context);

    expect(context.password).toBe('');
    expect(context.passwordConfigured).toBe(true);
  });

  it('preserves the configured IMAP password by omitting it from updates', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const context = {
      inbox: { id: 16 },
      isIMAPEnabled: true,
      address: 'imap.hostinger.com',
      port: 993,
      login: 'support@example.com',
      password: '',
      passwordConfigured: true,
      isSSLEnabled: true,
      authMechanism: 'login',
      $store: { dispatch },
      $t: key => key,
    };

    await ImapSettings.methods.updateInbox.call(context);

    expect(dispatch).toHaveBeenCalledWith('inboxes/updateInboxIMAP', {
      id: 16,
      formData: false,
      channel: {
        imap_enabled: true,
        imap_address: 'imap.hostinger.com',
        imap_port: 993,
        imap_login: 'support@example.com',
        imap_enable_ssl: true,
        imap_authentication: 'login',
      },
    });
  });

  it('never copies a persisted SMTP password into component state', () => {
    const context = {
      inbox: {
        smtp_enabled: true,
        smtp_address: 'smtp.hostinger.com',
        smtp_port: 465,
        smtp_login: 'support@example.com',
        smtp_password: 'must-not-be-read',
        smtp_password_set: true,
        smtp_domain: 'example.com',
        smtp_enable_starttls_auto: false,
        smtp_enable_ssl_tls: true,
        smtp_openssl_verify_mode: 'peer',
        smtp_authentication: 'login',
      },
    };

    SmtpSettings.methods.setDefaults.call(context);

    expect(context.password).toBe('');
    expect(context.passwordConfigured).toBe(true);
  });

  it('preserves the configured SMTP password by omitting it from updates', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const context = {
      inbox: { id: 16 },
      isSMTPEnabled: true,
      address: 'smtp.hostinger.com',
      port: 465,
      login: 'support@example.com',
      password: '',
      passwordConfigured: true,
      domain: 'example.com',
      ssl: true,
      starttls: false,
      openSSLVerifyMode: 'peer',
      authMechanism: 'login',
      $store: { dispatch },
      $t: key => key,
    };

    await SmtpSettings.methods.updateInbox.call(context);

    expect(dispatch).toHaveBeenCalledWith('inboxes/updateInboxSMTP', {
      id: 16,
      channel: {
        smtp_enabled: true,
        smtp_address: 'smtp.hostinger.com',
        smtp_port: 465,
        smtp_login: 'support@example.com',
        smtp_domain: 'example.com',
        smtp_enable_ssl_tls: true,
        smtp_enable_starttls_auto: false,
        smtp_openssl_verify_mode: 'peer',
        smtp_authentication: 'login',
      },
    });
  });
});
