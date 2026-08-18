class Openjarvis::CapabilityResolver
  CAPABILITY_KEYS = Openjarvis::CapabilityDefinition::KEYS
  CHANNEL_TYPES = Openjarvis::CapabilityDefinition::CHANNEL_TYPES

  def self.channel_matrix
    CHANNEL_TYPES.index_with { |channel_type| new(channel_type: channel_type).capabilities }
  end

  def initialize(inbox: nil, channel_type: nil)
    @inbox = inbox
    @channel_type = channel_type || inbox&.channel_type
  end

  def as_json
    {
      channel_type: channel_type,
      provider: provider,
      connection: connection,
      capabilities: capabilities
    }
  end

  def capabilities
    @capabilities ||= CAPABILITY_KEYS.index_with { |key| capability(key) }
  end

  def supported?(key)
    capabilities.fetch(key.to_s).fetch(:supported)
  end

  def connection
    return static_connection unless inbox

    case channel_type
    when 'Channel::Whatsapp' then whatsapp_connection
    when 'Channel::Email' then email_connection
    when 'Channel::Instagram', 'Channel::FacebookPage' then authorization_connection
    when 'Channel::WebWidget' then web_widget_connection
    else generic_connection
    end
  end

  private

  attr_reader :inbox, :channel_type

  def capability(key)
    supported, mode, reason = Openjarvis::CapabilityDefinition.new(channel_type).resolve(key)
    {
      supported: supported,
      mode: mode,
      endpoint: endpoint_for(key),
      reason: supported ? nil : reason
    }.compact
  end

  def endpoint_for(key)
    Openjarvis::CapabilityDefinition::ENDPOINTS[key]
  end

  def static_connection
    { state: 'inbox_required', connected: false, source: 'channel_matrix' }
  end

  def whatsapp_connection
    channel = inbox.channel
    return evolution_connection(channel) if channel.provider == 'evolution'

    configured = channel.provider_config.present? && !reauthorization_required?(channel)
    {
      state: configured ? 'configured_not_probed' : 'authorization_required',
      connected: false,
      operational: configured,
      source: 'whatsapp_provider_configuration',
      provider: channel.provider
    }
  end

  def evolution_connection(channel)
    provisioning = channel.evolution_provisioning
    state = provisioning&.status || 'not_provisioned'
    {
      state: state,
      connected: state == 'connected',
      operational: state == 'connected',
      source: 'whatsapp_evolution_provisioning',
      provider: 'evolution',
      last_seen_at: provisioning&.last_seen_at&.iso8601,
      error_code: provisioning&.last_error_code
    }.compact
  end

  def email_connection
    channel = inbox.channel
    inbound = channel.imap_enabled
    outbound = channel.smtp_enabled || channel.google? || channel.microsoft?
    {
      state: inbound || outbound ? 'configured_not_probed' : 'not_configured',
      connected: false,
      operational: inbound || outbound,
      source: 'email_channel_configuration',
      inbound_configured: inbound,
      outbound_configured: outbound,
      provider: channel.provider.presence || 'imap_smtp'
    }
  end

  def authorization_connection
    configured = !reauthorization_required?(inbox.channel)
    {
      state: configured ? 'configured_not_probed' : 'authorization_required',
      connected: false,
      operational: configured,
      source: 'channel_authorization_state'
    }
  end

  def web_widget_connection
    configured = inbox.channel.website_token.present?
    {
      state: configured ? 'active' : 'not_configured',
      connected: configured,
      operational: configured,
      source: 'web_widget_configuration'
    }
  end

  def generic_connection
    { state: 'configured_not_probed', connected: false, operational: true, source: 'inbox_configuration' }
  end

  def reauthorization_required?(channel)
    channel.respond_to?(:reauthorization_required?) && channel.reauthorization_required?
  end

  def provider
    return unless inbox
    return inbox.channel.provider if inbox.channel.respond_to?(:provider)

    inbox.inbox_type
  end
end
