class Openjarvis::CapabilityDefinition
  KEYS = %w[
    connection.inspect conversations.read conversations.search conversations.create
    messages.read messages.search messages.send messages.reply messages.reaction
    messages.mark_read_internal messages.mark_read_provider messages.media_read
    messages.media_send messages.delivery_status email.search email.unread email.threads
    email.reply email.recipients email.attachments_read email.attachments_send email.archive email.trash
  ].freeze

  CHANNEL_TYPES = %w[
    Channel::Api Channel::Email Channel::FacebookPage Channel::Instagram Channel::Line
    Channel::Sms Channel::Telegram Channel::Tiktok Channel::TwilioSms Channel::TwitterProfile
    Channel::WebWidget Channel::Whatsapp
  ].freeze

  READ_CAPABILITIES = %w[
    connection.inspect conversations.read conversations.search messages.read messages.search
  ].freeze
  CREATABLE_CHANNELS = %w[Channel::Api Channel::Email Channel::Sms Channel::TwilioSms Channel::WebWidget Channel::Whatsapp].freeze
  REPLY_CHANNELS = %w[Channel::Email Channel::WebWidget Channel::Api].freeze
  EMAIL_CAPABILITIES = %w[email.search email.unread email.threads email.reply email.recipients email.attachments_read].freeze
  RESOLVERS = READ_CAPABILITIES.index_with { :read_capability }.merge(
    'conversations.create' => :create_capability,
    'messages.send' => :send_capability,
    'messages.mark_read_internal' => :read_capability,
    'messages.media_read' => :metadata_capability,
    'messages.delivery_status' => :metadata_capability,
    'messages.reply' => :reply_capability
  ).freeze

  ENDPOINTS = {
    'connection.inspect' => '/api/v1/openjarvis/inboxes/{inbox_id}/health',
    'conversations.read' => '/api/v1/openjarvis/conversations/{conversation_id}',
    'conversations.search' => '/api/v1/openjarvis/conversations',
    'conversations.create' => '/api/v1/openjarvis/conversations',
    'messages.read' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'messages.search' => '/api/v1/openjarvis/messages',
    'messages.send' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'messages.reply' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'messages.mark_read_internal' => '/api/v1/openjarvis/conversations/{conversation_id}/read',
    'messages.delivery_status' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'messages.media_read' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'email.search' => '/api/v1/openjarvis/messages',
    'email.unread' => '/api/v1/openjarvis/messages?unread=true',
    'email.threads' => '/api/v1/openjarvis/conversations',
    'email.reply' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'email.recipients' => '/api/v1/openjarvis/conversations/{conversation_id}/messages',
    'email.attachments_read' => '/api/v1/openjarvis/conversations/{conversation_id}/messages'
  }.freeze

  UNSUPPORTED_REASONS = {
    'messages.reaction' => 'No provider reaction mutation is implemented by the AceleraChat channel adapter',
    'messages.mark_read_provider' => 'AceleraChat can mark its conversation read but does not send provider read receipts through this API',
    'messages.media_send' => 'Binary upload and outbound attachment creation are not exposed by this integration'
  }.freeze

  def initialize(channel_type)
    @channel_type = channel_type
  end

  def resolve(key)
    return email(key) if key.start_with?('email.')

    send(RESOLVERS.fetch(key, :unsupported_capability), key)
  end

  private

  attr_reader :channel_type

  def read_capability(_key)
    supported('acelerachat')
  end

  def metadata_capability(_key)
    supported('acelerachat_metadata')
  end

  def create_capability(_key)
    return supported('acelerachat') if CREATABLE_CHANNELS.include?(channel_type)

    unsupported('Conversation creation is not implemented for this channel')
  end

  def send_capability(_key)
    return supported('acelerachat') if CHANNEL_TYPES.include?(channel_type)

    unsupported('Message send is not implemented for this channel')
  end

  def reply_capability(_key)
    return supported('acelerachat_thread') if REPLY_CHANNELS.include?(channel_type)

    unsupported('The current channel adapter does not execute provider-native contextual replies')
  end

  def unsupported_capability(key)
    unsupported(UNSUPPORTED_REASONS.fetch(key, 'Capability is not implemented for this channel'))
  end

  def email(key)
    return [false, 'not_applicable', 'This inbox is not an email channel'] unless channel_type == 'Channel::Email'
    return supported('acelerachat') if EMAIL_CAPABILITIES.include?(key)
    return unsupported('OpenJarvis binary upload is not part of the AceleraChat integration contract') if key == 'email.attachments_send'

    unsupported('Provider mailbox archive and trash are outside AceleraChat customer-service scope')
  end

  def supported(mode)
    [true, mode, nil]
  end

  def unsupported(reason)
    [false, 'not_supported', reason]
  end
end
