class Api::V1::Openjarvis::AgentsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('resources:read')
    inbox = openjarvis_access_scope.inbox!(params[:inbox_id]) if params[:inbox_id].present?
    records = Openjarvis::ResourceResolver.new(openjarvis_access_scope).agents(inbox: inbox)
    render json: {
      data: records.map do |user|
        account_user = Current.account.account_users.find_by(user_id: user.id)
        { id: user.id, name: user.name, email: user.email, role: account_user&.role, inbox_id: inbox&.id }
      end
    }
  end
end
