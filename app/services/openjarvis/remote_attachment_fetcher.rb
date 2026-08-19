class Openjarvis::RemoteAttachmentFetcher
  MAX_BYTES = 20.megabytes
  ALLOWED_CONTENT_TYPE_PREFIXES = %w[image/ video/ audio/].freeze
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    text/plain text/csv
  ].freeze

  def initialize(url)
    @url = url.to_s.strip
  end

  def fetch!
    validate_url!
    blob = nil
    SafeFetch.fetch(
      url,
      max_bytes: MAX_BYTES,
      allow_private_network: false,
      allowed_content_type_prefixes: ALLOWED_CONTENT_TYPE_PREFIXES,
      allowed_content_types: ALLOWED_CONTENT_TYPES
    ) do |result|
      blob = ActiveStorage::Blob.create_and_upload!(
        io: result.tempfile,
        filename: result.filename,
        content_type: result.content_type
      )
    end
    blob
  rescue SafeFetch::FileTooLargeError
    raise api_error('remote_attachment_too_large', 'Remote attachment exceeds the 20 MB limit')
  rescue SafeFetch::UnsupportedContentTypeError
    raise api_error('remote_attachment_type_not_allowed', 'Remote attachment content type is not allowed')
  rescue SafeFetch::Error
    raise api_error('remote_attachment_unavailable', 'Remote attachment could not be fetched', retryable: true)
  end

  private

  attr_reader :url

  def validate_url!
    uri = URI.parse(url)
    return if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank? && uri.fragment.blank?

    raise api_error('invalid_remote_attachment_url', 'Remote attachment URL must be public HTTPS without credentials or fragment')
  rescue URI::InvalidURIError
    raise api_error('invalid_remote_attachment_url', 'Remote attachment URL is invalid')
  end

  def api_error(code, message, retryable: false)
    Openjarvis::ApiError.new(code, message, status: :unprocessable_entity, retryable: retryable)
  end
end
