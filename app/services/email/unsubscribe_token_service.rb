class Email::UnsubscribeTokenService
  PURPOSE = 'email-campaign-unsubscribe'.freeze

  class << self
    def generate(contact)
      raw_token = verifier.generate(
        { account_id: contact.account_id, contact_id: contact.id },
        purpose: PURPOSE
      )
      Base64.urlsafe_encode64(raw_token, padding: false)
    end

    def contact_for(token)
      raw_token = Base64.urlsafe_decode64(token.to_s)
      payload = verifier.verify(raw_token, purpose: PURPOSE).with_indifferent_access
      Contact.find_by(id: payload[:contact_id], account_id: payload[:account_id])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError
      nil
    end

    private

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
