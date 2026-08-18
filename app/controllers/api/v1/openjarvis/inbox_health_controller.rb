class Api::V1::Openjarvis::InboxHealthController < Api::V1::Openjarvis::BaseController
  def show
    require_scope!('inboxes:read')
    inbox = openjarvis_access_scope.inbox!(params[:inbox_id])
    resolver = Openjarvis::CapabilityResolver.new(inbox: inbox)
    render json: {
      data: {
        inbox_id: inbox.id,
        channel_type: inbox.channel_type,
        checked_at: Time.current.iso8601,
        connection: resolver.connection,
        capabilities: resolver.capabilities
      }
    }
  end
end
