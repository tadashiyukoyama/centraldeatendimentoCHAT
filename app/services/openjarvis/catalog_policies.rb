class Openjarvis::CatalogPolicies
  ERROR_DEFINITIONS = {
    invalid_credentials: [401, false, 'not_applied'], insufficient_scope: [403, false, 'not_applied'],
    resource_not_found: [404, false, 'not_applied'], contact_not_found: [404, false, 'not_applied'],
    conversation_not_found: [404, false, 'not_applied'], inbox_not_found: [404, false, 'not_applied'],
    openapi_component_not_found: [404, false, 'not_applied'], invalid_cursor: [400, false, 'not_applied'],
    cursor_mismatch: [400, false, 'not_applied'], missing_parameter: [400, false, 'not_applied'],
    invalid_contact_type: [400, false, 'not_applied'], invalid_status: [400, false, 'not_applied'],
    invalid_priority: [400, false, 'not_applied'], invalid_updated_after: [400, false, 'not_applied'],
    invalid_snoozed_until: [400, false, 'not_applied'], invalid_backfill_resource: [400, false, 'not_applied'],
    source_id_not_accepted: [400, false, 'not_applied'], message_content_required: [400, false, 'not_applied'],
    invalid_idempotency_key: [400, false, 'not_applied'], idempotency_conflict: [409, false, 'not_applied'],
    contact_conflict: [409, false, 'not_applied'], request_in_progress: [409, true, 'unknown'],
    assignee_not_authorized: [403, false, 'not_applied'], team_not_authorized: [403, false, 'not_applied'],
    validation_failed: [422, false, 'not_applied'], contact_inbox_missing: [422, false, 'not_applied'],
    contact_routing_attribute_missing: [422, false, 'not_applied'], label_not_found: [422, false, 'not_applied'],
    reply_target_not_found: [422, false, 'not_applied'], capability_not_supported: [422, false, 'not_applied'],
    rate_limited: [429, true, 'not_applied'], integration_unavailable: [503, true, 'not_applied'],
    internal_error: [500, true, 'unknown']
  }.freeze

  def self.authentication
    {
      type: 'bearer', header: 'Authorization',
      rotation_grace_seconds: Openjarvis::Configuration::CREDENTIAL_GRACE_PERIOD.to_i,
      simultaneous_credentials: 2
    }
  end

  def self.idempotency
    {
      required_for: %w[POST PATCH], header: 'Idempotency-Key', minimum_length: 8,
      replay_header: 'Idempotency-Replayed', retention_seconds: Openjarvis::Configuration::IDEMPOTENCY_RETENTION.to_i
    }
  end

  def self.rate_limits
    Openjarvis::Configuration::RATE_LIMITS.transform_values do |policy|
      { limit: policy[:limit], window_seconds: policy[:window].to_i, retry_after_header: true }
    end
  end

  def self.retention
    {
      idempotency_seconds: Openjarvis::Configuration::IDEMPOTENCY_RETENTION.to_i,
      webhook_delivery_metadata_seconds: Openjarvis::Configuration::DELIVERY_RETENTION.to_i,
      webhook_payload_persisted: false
    }
  end

  def self.webhook_delivery
    {
      semantic: 'at_least_once', duplicates_possible: true, global_ordering: false,
      per_resource_sequence: true, retry_attempts: 5,
      temporary_failures: ['transport', 408, 409, 425, 429, '5xx'],
      permanent_failures: ['other_4xx'], reconciliation_endpoint: '/api/v1/openjarvis/backfill'
    }
  end

  def self.error_taxonomy
    ERROR_DEFINITIONS.transform_values do |status, retryable, result_state|
      { status: status, retryable: retryable, result_state: result_state }
    end
  end
end
