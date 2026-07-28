namespace :acelerachat do
  namespace :public_content do
    desc 'Validate legal facts, account, author, collisions, and pending content changes without mutation'
    task check: :environment do
      result = Acelerachat::PublicContent::SyncService.new(mode: :check).call
      puts JSON.pretty_generate(mode: result.mode, documents: result.document_count, actions: result.actions)
    end

    desc 'Synchronize the repository-managed AceleraChat help and legal content in one transaction'
    task sync: :environment do
      result = Acelerachat::PublicContent::SyncService.new(mode: :sync).call
      puts JSON.pretty_generate(mode: result.mode, documents: result.document_count, actions: result.actions)
    end
  end

  namespace :brand do
    desc 'Audit the public profile, canonical links, content package, assets, legacy egress, and disabled control plane'
    task audit: :environment do
      puts JSON.pretty_generate(Acelerachat::BrandAudit.new.call)
    end
  end

  namespace :email do
    desc 'Check contacts, credential encryption, SMTP authentication, and MX/SPF/DKIM/DMARC before release'
    task check: :environment do
      puts JSON.pretty_generate(Acelerachat::EmailDomainPreflight.new.call)
    end

    desc 'Send one controlled transactional-email smoke after the non-mutating preflight passes'
    task :test, [:recipient] => :environment do |_task, args|
      recipient = Mail::Address.new(args[:recipient].to_s)
      raise ArgumentError, 'A valid recipient is required' if recipient.address.blank? || recipient.domain.blank?

      Acelerachat::EmailDomainPreflight.new.call
      ActionMailer::Base.mail(
        to: recipient.address,
        from: ENV.fetch('MAILER_SENDER_EMAIL'),
        subject: "Teste transacional AceleraChat #{GIT_HASH}",
        body: "O SMTP transacional da AceleraChat entregou este teste controlado.\nSHA: #{GIT_HASH}\n"
      ).deliver_now
      puts JSON.generate(status: 'sent', recipient_domain: recipient.domain, release: GIT_HASH)
    rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
      raise ArgumentError, 'A valid recipient is required'
    end
  end

  namespace :monitoring do
    desc 'Validate Sentry DSNs, environment, release SHA, privacy policy, and sampling'
    task check: :environment do
      puts JSON.pretty_generate(Acelerachat::SentryConfiguration.new.preflight!)
    end

    desc 'Send one controlled Sentry smoke event after the non-mutating preflight passes'
    task test: :environment do
      Acelerachat::SentryConfiguration.new.preflight!
      event = Sentry.capture_message(
        'AceleraChat controlled monitoring smoke',
        level: :warning,
        tags: { smoke: 'monitoring', release: GIT_HASH }
      )
      raise 'Sentry did not accept the controlled smoke event' unless event

      puts JSON.generate(status: 'queued', event_id: event.event_id, release: GIT_HASH)
    end
  end

  namespace :release do
    desc 'Run every non-mutating AceleraChat cutover gate; skip when the public profile is disabled'
    task preflight: :environment do
      unless PublicBrand.profile_name == 'acelerachat'
        puts JSON.generate(status: 'skipped', reason: 'PUBLIC_BRAND_PROFILE is not acelerachat')
        next
      end

      results = {
        brand: Acelerachat::BrandAudit.new.call,
        email: Acelerachat::EmailDomainPreflight.new.call,
        monitoring: Acelerachat::SentryConfiguration.new.preflight!,
        public_content: Acelerachat::PublicContent::SyncService.new(mode: :check).call.to_h
      }
      puts JSON.pretty_generate(results)
    end

    desc 'Synchronize repository-managed public content after additive migrations; skip when the profile is disabled'
    task sync: :environment do
      unless PublicBrand.profile_name == 'acelerachat'
        puts JSON.generate(status: 'skipped', reason: 'PUBLIC_BRAND_PROFILE is not acelerachat')
        next
      end

      result = Acelerachat::PublicContent::SyncService.new(mode: :sync).call
      puts JSON.pretty_generate(mode: result.mode, documents: result.document_count, actions: result.actions)
    end
  end
end
