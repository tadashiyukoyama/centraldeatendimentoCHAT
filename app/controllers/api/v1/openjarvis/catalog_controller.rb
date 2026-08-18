class Api::V1::Openjarvis::CatalogController < Api::V1::Openjarvis::BaseController
  def index
    render json: Openjarvis::Catalog.as_json.merge(granted_scopes: openjarvis_hook.openjarvis_configuration.scopes)
  end
end
