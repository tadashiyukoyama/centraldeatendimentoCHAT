require_relative '../acelerachat'

class Acelerachat::SentryEventScrubber
  FILTERED = '[Filtered]'.freeze
  MAX_DEPTH = 5
  SENSITIVE_KEY_PATTERN =
    /authorization|cookie|token|secret|password|passwd|api[-_]?key|access[-_]?key|csrf|session/i
  URL_KEY_PATTERN = /\A(?:url|uri|request_url|referer|referrer)\z/i
  BEARER_PATTERN = %r{\bBearer\s+[A-Za-z0-9._~+/-]+=*}i
  EMAIL_PATTERN = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
  PHONE_OR_DOCUMENT_PATTERN = /(?<!\w)\+?\d[\d\s().-]{7,}\d(?!\w)/

  class << self
    def scrub_event(event)
      scrub_top_level_fields(event)
      scrub_structured_fields(event)
      scrub_exception(event.exception) if event.respond_to?(:exception)
      scrub_breadcrumbs(event.breadcrumbs)
      event
    end

    def scrub_top_level_fields(event)
      event.user = {}
      event.message = sanitize_string(event.message)
      event.transaction = strip_url_details(event.transaction)
      event.request = sanitize_request(event.request) if event.respond_to?(:request) && event.respond_to?(:request=)
    end

    def scrub_structured_fields(event)
      event.tags = sanitize(event.tags)
      event.contexts = sanitize(event.contexts)
      event.extra = sanitize(event.extra)
    end

    def scrub_breadcrumb(breadcrumb)
      return breadcrumb unless breadcrumb

      breadcrumb.message = sanitize_string(breadcrumb.message)
      breadcrumb.data = sanitize(breadcrumb.data)
      breadcrumb
    end

    def sanitize(value, depth = 0)
      return FILTERED if depth > MAX_DEPTH
      return sanitize_string(value) if value.is_a?(String)
      return value.map { |item| sanitize(item, depth + 1) } if value.is_a?(Array)
      return value unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, item), result|
        result[key] = sanitized_hash_value(key, item, depth)
      end
    end

    def sanitize_string(value)
      return value unless value.is_a?(String)

      value
        .gsub(BEARER_PATTERN, "Bearer #{FILTERED}")
        .gsub(EMAIL_PATTERN, FILTERED)
        .gsub(PHONE_OR_DOCUMENT_PATTERN, FILTERED)
    end

    def sanitize_request(request)
      sanitized = sanitize(request)
      return sanitized unless sanitized.is_a?(Hash)

      %i[data cookies query_string].each do |key|
        sanitized.delete(key)
        sanitized.delete(key.to_s)
      end
      sanitized
    end

    private

    def sanitized_hash_value(key, value, depth)
      return FILTERED if key.to_s.match?(SENSITIVE_KEY_PATTERN)
      return strip_url_details(value) if key.to_s.match?(URL_KEY_PATTERN)

      sanitize(value, depth + 1)
    end

    def strip_url_details(value)
      return sanitize(value) unless value.is_a?(String)

      sanitize_string(value.split(/[?#]/, 2).first)
    end

    def scrub_exception(exception)
      entries = exception&.values
      return unless entries

      entries.each { |entry| entry.value = sanitize_string(entry.value) }
    end

    def scrub_breadcrumbs(breadcrumbs)
      return unless breadcrumbs.respond_to?(:each)

      breadcrumbs.each { |breadcrumb| scrub_breadcrumb(breadcrumb) }
    end
  end
end
