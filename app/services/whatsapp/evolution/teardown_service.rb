class Whatsapp::Evolution::TeardownService
  def initialize(channel_or_provisioning)
    @provisioning =
      if channel_or_provisioning.is_a?(Whatsapp::EvolutionProvisioning)
        channel_or_provisioning
      else
        Whatsapp::EvolutionProvisioning.find_by(whatsapp_channel_id: channel_or_provisioning.id)
      end
  end

  def perform
    return true unless provisioning
    return true if provisioning.deleted?

    provisioning.update!(status: :deleting)
    client = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning)
    ignore_missing_instance { client.logout }
    ignore_missing_instance { client.delete_instance }
    provisioning.update!(status: :deleted, whatsapp_channel: nil, last_seen_at: Time.current)
    true
  rescue StandardError => e
    provisioning&.record_failure!(
      code: e.respond_to?(:code) ? e.code : 'teardown_failed',
      message: e.is_a?(Whatsapp::Evolution::ApiClient::Error) ? e.message : 'Evolution teardown failed'
    )
    raise
  end

  private

  attr_reader :provisioning

  def ignore_missing_instance
    yield
  rescue Whatsapp::Evolution::ApiClient::Error => e
    raise unless e.http_status == 404
  end
end
