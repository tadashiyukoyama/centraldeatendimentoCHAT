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
    desc 'Check required first-party mailboxes and MX/SPF/DKIM/DMARC before release'
    task check: :environment do
      puts JSON.pretty_generate(Acelerachat::EmailDomainPreflight.new.call)
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
