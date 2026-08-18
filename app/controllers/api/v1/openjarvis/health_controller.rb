class Api::V1::Openjarvis::HealthController < Api::V1::Openjarvis::BaseController
  def show
    diagnostics = Openjarvis::Diagnostics.new(openjarvis_hook).as_json
    render json: diagnostics.slice(:status, :checked_at, :release, :version, :account, :integration).merge(
      inboxes: openjarvis_access_scope.inboxes.order(:id).map do |inbox|
        resolver = Openjarvis::CapabilityResolver.new(inbox: inbox)
        { id: inbox.id, channel_type: inbox.channel_type, connection: resolver.connection }
      end
    )
  end
end
