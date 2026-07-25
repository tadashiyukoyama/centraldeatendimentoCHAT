# frozen_string_literal: true

require 'uri'

class AceleraControl::UrlPolicy
  FORBIDDEN_HOST_SUFFIXES = %w[
    chatwoot.com
    chatwoot.help
    chwt.app
  ].freeze

  def self.call(value)
    return if value.blank?

    uri = URI.parse(value.to_s.strip)
    return unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
    return if forbidden_host?(uri.host)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def self.forbidden_host?(host)
    normalized_host = host.to_s.downcase.delete_suffix('.')
    FORBIDDEN_HOST_SUFFIXES.any? do |suffix|
      normalized_host == suffix || normalized_host.end_with?(".#{suffix}")
    end
  end

  private_class_method :forbidden_host?
end
