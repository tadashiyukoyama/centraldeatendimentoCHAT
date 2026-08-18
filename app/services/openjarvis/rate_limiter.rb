class Openjarvis::RateLimiter
  Result = Data.define(:allowed?, :limit, :remaining, :retry_after, :reset_at)

  def initialize(hook:, bucket:, now: Time.current, cache: Rails.cache)
    @hook = hook
    @bucket = bucket.to_sym
    @now = now
    @cache = cache
  end

  def check
    state = rate_state
    count = cache.increment(state[:key], 1, expires_in: state[:window] + 5, initial: 0)
    count ||= fallback_increment(state[:key], state[:window])
    Result.new(
      allowed?: count <= state[:limit],
      limit: state[:limit],
      remaining: [state[:limit] - count, 0].max,
      retry_after: [(state[:reset_at] - now).ceil, 1].max,
      reset_at: state[:reset_at]
    )
  end

  private

  attr_reader :hook, :bucket, :now, :cache

  def rate_state
    policy = Openjarvis::Configuration::RATE_LIMITS.fetch(bucket)
    window = policy.fetch(:window).to_i
    number = now.to_i / window
    {
      key: "openjarvis:rate-limit:#{hook.id}:#{bucket}:#{number}",
      window: window,
      limit: policy.fetch(:limit),
      reset_at: Time.at((number + 1) * window).utc
    }
  end

  def fallback_increment(key, window)
    current = cache.read(key).to_i + 1
    cache.write(key, current, expires_in: window + 5)
    current
  end
end
