class Whatsapp::Evolution::ConnectionSyncService
  Result = Data.define(:provisioning, :qr_code)

  def initialize(provisioning:)
    @provisioning = provisioning
    @client = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning)
  end

  def perform
    return connected_result if channel_already_connected?

    fail_expired_provisioning! if provisioning.expired?
    state = extract_state(client.connection_state)
    state == 'open' ? finalize_connection : refresh_qr_code(state)
  rescue Whatsapp::Evolution::ApiClient::Error => e
    provisioning.record_failure!(code: e.code, message: e.message)
    raise
  end

  private

  attr_reader :provisioning, :client

  def channel_already_connected?
    provisioning.whatsapp_channel_id.present? && provisioning.connected?
  end

  def connected_result
    Result.new(provisioning: provisioning, qr_code: nil)
  end

  def extract_state(response)
    response.dig('instance', 'state') || response['state']
  end

  def finalize_connection
    finalize_connected_instance
    Result.new(provisioning: provisioning.reload, qr_code: nil)
  end

  def refresh_qr_code(state)
    provisioning.update!(
      status: state == 'connecting' ? :connecting : :waiting_qr,
      last_seen_at: Time.current
    )
    connect_response = client.connect
    qr_code = connect_response['base64'] || connect_response.dig('qrcode', 'base64')
    Result.new(
      provisioning: provisioning.reload,
      qr_code: Whatsapp::Evolution::QrCode.normalize(qr_code)
    )
  end

  def finalize_connected_instance
    instance = client.fetch_instance || {}
    owner = instance['ownerJid'] || instance['owner'] || instance.dig('instance', 'ownerJid')
    profile_name = instance['profileName'] || instance.dig('instance', 'profileName')
    profile_picture_url = instance['profilePictureUrl'] || instance.dig('instance', 'profilePictureUrl')
    Whatsapp::Evolution::FinalizeProvisioningService.new(
      provisioning: provisioning,
      connected_number: owner,
      profile_name: profile_name,
      profile_picture_url: profile_picture_url
    ).perform
  end

  def fail_expired_provisioning!
    provisioning.record_failure!(code: 'qr_expired', message: 'QR Code provisioning expired')
    raise Whatsapp::Evolution::ApiClient::Error.new(
      'QR Code provisioning expired',
      code: 'qr_expired'
    )
  end
end
