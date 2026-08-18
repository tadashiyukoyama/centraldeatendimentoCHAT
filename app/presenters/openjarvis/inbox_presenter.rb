class Openjarvis::InboxPresenter
  def initialize(inbox)
    @inbox = inbox
  end

  def as_json
    {
      id: inbox.id,
      name: inbox.name,
      channel_type: inbox.channel_type,
      inbox_type: inbox.inbox_type,
      auto_assignment_enabled: inbox.enable_auto_assignment,
      connection: capability_resolver.connection,
      capabilities: capability_resolver.capabilities,
      created_at: inbox.created_at.iso8601,
      updated_at: inbox.updated_at.iso8601
    }
  end

  private

  attr_reader :inbox

  def capability_resolver
    @capability_resolver ||= Openjarvis::CapabilityResolver.new(inbox: inbox)
  end
end
