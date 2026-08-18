class Api::V1::Openjarvis::OpenapiController < Api::V1::Openjarvis::BaseController
  COMPONENT_ROOT = Rails.root.join('docs/integrations/openjarvis-openapi').freeze
  COMPONENT_READERS = {
    'examples.yaml' => -> { File.read(COMPONENT_ROOT.join('examples.yaml')) },
    'parameters.yaml' => -> { File.read(COMPONENT_ROOT.join('parameters.yaml')) },
    'paths.yaml' => -> { File.read(COMPONENT_ROOT.join('paths.yaml')) },
    'responses.yaml' => -> { File.read(COMPONENT_ROOT.join('responses.yaml')) },
    'schemas.yaml' => -> { File.read(COMPONENT_ROOT.join('schemas.yaml')) },
    'webhook-examples.yaml' => -> { File.read(COMPONENT_ROOT.join('webhook-examples.yaml')) },
    'webhooks.yaml' => -> { File.read(COMPONENT_ROOT.join('webhooks.yaml')) }
  }.freeze

  def show
    render plain: File.read(Rails.root.join('docs/integrations/openjarvis-openapi.yaml')), content_type: 'application/yaml'
  end

  def component
    content = component_content(params[:path].to_s)
    raise Openjarvis::ApiError.new('openapi_component_not_found', 'OpenAPI component was not found', status: :not_found) if content.nil?

    render plain: content, content_type: 'application/yaml'
  end

  private

  def component_content(name)
    COMPONENT_READERS[name]&.call
  end
end
