class Api::V1::Openjarvis::LabelsController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('resources:read')
    records = Openjarvis::ResourceResolver.new(openjarvis_access_scope).labels
    render json: { data: records.map { |label| label.slice(:id, :title, :description, :color, :show_on_sidebar) } }
  end
end
