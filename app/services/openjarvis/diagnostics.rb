class Openjarvis::Diagnostics
  def initialize(hook)
    @hook = hook
  end

  def as_json
    checks = { postgres: postgres_check, redis: redis_check, sidekiq: sidekiq_check }
    {
      status: checks.values.all? { |check| check[:status] == 'ok' } ? 'ok' : 'degraded',
      checked_at: Time.current.iso8601,
      release: defined?(GIT_HASH) ? GIT_HASH : nil,
      version: Chatwoot.config[:version],
      account: { id: hook.account_id, name: hook.account.name },
      integration: integration_summary,
      checks: checks
    }
  end

  private

  attr_reader :hook

  def timed_check
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    value = yield
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
    { status: 'ok', latency_ms: elapsed }.merge(value || {})
  rescue StandardError => e
    { status: 'failing', error: e.class.name }
  end

  def postgres_check
    timed_check do
      raise ActiveRecord::ConnectionNotEstablished unless ActiveRecord::Base.connection.active?

      { migrations: ActiveRecord::Base.connection.migration_context.needs_migration? ? 'pending' : 'current' }
    end
  end

  def redis_check
    timed_check do
      redis = Redis.new(Redis::Config.app)
      raise 'Redis ping failed' unless redis.ping == 'PONG'

      {}
    end
  end

  def sidekiq_check
    timed_check do
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      {
        processes: stats.processes_size,
        enqueued: stats.enqueued,
        scheduled: stats.scheduled_size,
        retries: stats.retry_size,
        dead: stats.dead_size
      }
    end
  end

  def integration_summary
    {
      status: hook.status,
      webhooks_enabled: hook.openjarvis_configuration.webhooks_enabled?,
      allowed_inbox_count: hook.openjarvis_configuration.effective_inbox_count,
      service_user_id: hook.openjarvis_configuration.service_user_id,
      pending_deliveries: hook.openjarvis_webhook_deliveries.where(status: [:queued, :delivering]).count,
      failed_deliveries: hook.openjarvis_webhook_deliveries.failed.where('created_at >= ?', 24.hours.ago).count
    }
  end
end
