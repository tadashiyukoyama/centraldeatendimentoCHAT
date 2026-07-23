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
    return true if provisioning.reload.deleted?

    return true unless provisioning.mark_deleting!

    delete_remote_instance
    provisioning.mark_deleted!
    true
  rescue StandardError => e
    record_teardown_failure(e)
    raise
  end

  private

  attr_reader :provisioning

  def delete_remote_instance
    client = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning)
    ignore_missing_instance { client.logout }
    ignore_missing_instance { client.delete_instance }
  end

  def record_teardown_failure(error)
    provisioning&.record_teardown_failure!(
      code: error.respond_to?(:code) ? error.code : 'teardown_failed',
      message: error.is_a?(Whatsapp::Evolution::ApiClient::Error) ? error.message : 'Evolution teardown failed'
    )
  end

  def ignore_missing_instance
    yield
  rescue Whatsapp::Evolution::ApiClient::Error => e
    raise unless e.http_status == 404
  end
end
