class Openjarvis::IntegrationTestPayload
  def initialize(hook:, account:)
    @hook = hook
    @account = account
  end

  def as_json
    {
      schema_version: Openjarvis::Configuration::SCHEMA_VERSION,
      event_id: SecureRandom.uuid,
      event: 'integration.test',
      occurred_at: Time.current.utc.iso8601(6),
      resource: integration_identity,
      data: { account_id: account.id, release: defined?(GIT_HASH) ? GIT_HASH : nil }
    }
  end

  private

  attr_reader :hook, :account

  def integration_identity
    {
      type: 'Integration', id: hook.id, internal_id: hook.id,
      version: "#{hook.updated_at.utc.iso8601(6)}:#{hook.id}", sequence: 0
    }
  end
end
