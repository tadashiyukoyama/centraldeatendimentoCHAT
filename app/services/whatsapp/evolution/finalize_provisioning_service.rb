class Whatsapp::Evolution::FinalizeProvisioningService
  def initialize(provisioning:, connected_number:, profile_name: nil, profile_picture_url: nil)
    @provisioning = provisioning
    @connected_number = normalize_number(connected_number)
    @profile_name = profile_name.to_s.first(255).presence
    @profile_picture_url = valid_profile_picture_url(profile_picture_url)
  end

  def perform
    provisioning.with_lock do
      next provisioning.inbox if provisioning.deleting? || provisioning.deleted?

      if provisioning.whatsapp_channel_id.present?
        provisioning.update!(connected_attributes)
        next provisioning.inbox
      end

      ActiveRecord::Base.transaction do
        provisioning.update!(connected_attributes)
        channel = create_channel!
        inbox = create_inbox!(channel)
        provisioning.update!(whatsapp_channel: channel)
        inbox
      end
    end
  end

  private

  attr_reader :provisioning, :connected_number, :profile_name, :profile_picture_url

  def connected_attributes
    {
      status: :connected,
      connected_number: connected_number,
      profile_name: profile_name,
      profile_picture_url: profile_picture_url,
      last_error_code: nil,
      last_error_message: nil,
      last_seen_at: Time.current
    }
  end

  def create_channel!
    channel = Channel::Whatsapp.new(
      account: provisioning.account,
      phone_number: connected_number,
      provider: 'evolution',
      provider_config: { 'evolution_provisioning_id' => provisioning.id }
    )
    channel.evolution_provisioning_validation_id = provisioning.id
    channel.save!
    channel
  end

  def create_inbox!(channel)
    provisioning.account.inboxes.create!(
      name: provisioning.inbox_name,
      channel: channel
    )
  end

  def normalize_number(value)
    digits = value.to_s.split('@').first.to_s.gsub(/\D/, '')
    raise ArgumentError, 'Connected WhatsApp number is invalid' unless digits.match?(/\A\d{6,15}\z/)

    "+#{digits}"
  end

  def valid_profile_picture_url(value)
    return if value.blank?

    uri = URI.parse(value)
    uri.to_s if uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    nil
  end
end
