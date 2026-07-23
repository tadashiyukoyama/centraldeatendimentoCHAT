class Whatsapp::Evolution::ProvisioningService
  Result = Data.define(:provisioning, :qr_code)

  def initialize(account:, inbox_name:)
    @account = account
    @inbox_name = inbox_name.to_s.strip
  end

  def perform
    validate!
    provisioning = account.whatsapp_evolution_provisionings.create!(provisioning_attributes)
    remote_cleanup_needed = true

    response = Whatsapp::Evolution::ApiClient.new(provisioning: provisioning).create_instance
    advance_to_waiting_for_qr!(provisioning)
    Result.new(
      provisioning: provisioning,
      qr_code: Whatsapp::Evolution::QrCode.normalize(response.dig('qrcode', 'base64'))
    )
  rescue StandardError => e
    record_failure_safely(provisioning, e)
    compensate_remote_instance(provisioning) if remote_cleanup_needed
    raise
  end

  private

  attr_reader :account, :inbox_name

  def validate!
    Whatsapp::Evolution::Configuration.validate!
    if inbox_name.blank?
      invalid_provisioning = account.whatsapp_evolution_provisionings.new(inbox_name: inbox_name)
      raise ActiveRecord::RecordInvalid, invalid_provisioning
    end
    raise ArgumentError, 'Inbox name is too long' if inbox_name.length > 100
  end

  def provisioning_attributes
    public_id = SecureRandom.urlsafe_base64(24)
    {
      public_id: public_id,
      inbox_name: inbox_name,
      instance_name: "cw-a#{account.id}-#{SecureRandom.hex(8)}",
      instance_token: SecureRandom.hex(32),
      webhook_secret: SecureRandom.hex(32),
      status: :provisioning,
      expires_at: 15.minutes.from_now
    }
  end

  def advance_to_waiting_for_qr!(provisioning)
    provisioning.mark_waiting_for_qr!
  end

  def record_failure_safely(provisioning, error)
    return unless provisioning

    provisioning.record_failure!(code: error_code(error), message: safe_error_message(error))
  rescue StandardError => e
    Rails.logger.error(
      "[EVOLUTION] Failure persistence failed provisioning_id=#{provisioning.id} " \
      "account_id=#{provisioning.account_id} error_class=#{e.class.name}"
    )
  end

  def compensate_remote_instance(provisioning)
    Whatsapp::Evolution::ApiClient.new(provisioning: provisioning).delete_instance
  rescue StandardError
    Rails.logger.error(
      "[EVOLUTION] Remote compensation failed provisioning_id=#{provisioning.id} account_id=#{provisioning.account_id}"
    )
  end

  def error_code(error)
    error.respond_to?(:code) ? error.code : 'provisioning_failed'
  end

  def safe_error_message(error)
    return error.message if error.is_a?(Whatsapp::Evolution::Configuration::ConfigurationError)
    return error.message if error.is_a?(Whatsapp::Evolution::ApiClient::Error)

    'Evolution provisioning failed'
  end
end
