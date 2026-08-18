class Api::V1::Openjarvis::BackfillController < Api::V1::Openjarvis::BaseController
  def index
    require_scope!('sync:read')
    result = Openjarvis::Backfill.new(
      hook: openjarvis_hook,
      access_scope: openjarvis_access_scope,
      resource_type: params[:resource],
      cursor: params[:cursor],
      limit: limit
    ).perform
    render json: { data: result.data, meta: result.meta }
  end
end
