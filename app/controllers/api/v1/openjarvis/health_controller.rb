class Api::V1::Openjarvis::HealthController < Api::V1::Openjarvis::BaseController
  def show
    diagnostics = Openjarvis::Diagnostics.new(openjarvis_hook).as_json
    render json: diagnostics.slice(:status, :checked_at, :release, :version, :account, :integration)
  end
end
