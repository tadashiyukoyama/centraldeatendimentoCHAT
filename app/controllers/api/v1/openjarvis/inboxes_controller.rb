class Api::V1::Openjarvis::InboxesController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('inboxes:read')
    records = openjarvis_access_scope.inboxes.order(:name)
    render json: { data: records.map { |inbox| Openjarvis::InboxPresenter.new(inbox).as_json } }
  end
end
