class Api::V1::Openjarvis::TeamsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('resources:read')
    records = Openjarvis::ResourceResolver.new(openjarvis_access_scope).teams
    render json: { data: records.map { |team| team.slice(:id, :name, :description, :allow_auto_assign) } }
  end
end
