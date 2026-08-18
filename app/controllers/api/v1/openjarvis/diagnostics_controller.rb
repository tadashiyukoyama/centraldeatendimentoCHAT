class Api::V1::Openjarvis::DiagnosticsController < Api::V1::Openjarvis::BaseController
  def show
    require_scope!('diagnostics:read')
    render json: Openjarvis::Diagnostics.new(openjarvis_hook).as_json
  end
end
