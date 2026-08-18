class Openjarvis::Catalog
  BASE_SHA = '128d00a1743e198eb370f55fbaf7bffe7a2b01f1'.freeze

  def self.as_json
    {
      name: 'AceleraChat OpenJarvis API',
      version: Openjarvis::Configuration::CONTRACT_VERSION,
      schema_version: Openjarvis::Configuration::SCHEMA_VERSION,
      implementation_base_sha: BASE_SHA,
      implementation_release: defined?(GIT_HASH) ? GIT_HASH : nil,
      openapi: '/api/v1/openjarvis/openapi',
      authentication: Openjarvis::CatalogPolicies.authentication,
      idempotency: Openjarvis::CatalogPolicies.idempotency,
      rate_limits: Openjarvis::CatalogPolicies.rate_limits,
      retention: Openjarvis::CatalogPolicies.retention,
      scopes: Openjarvis::Configuration::SCOPES,
      webhook_subscriptions: Openjarvis::Configuration::SUBSCRIPTIONS,
      webhook_delivery: Openjarvis::CatalogPolicies.webhook_delivery,
      channel_capabilities: Openjarvis::CapabilityResolver.channel_matrix,
      errors: Openjarvis::CatalogPolicies.error_taxonomy,
      operations: operations,
      endpoints: operations.map { |item| item.slice(:method, :path, :scope, :description) }
    }.compact
  end

  def self.operations
    Openjarvis::CatalogOperations.all
  end
end
