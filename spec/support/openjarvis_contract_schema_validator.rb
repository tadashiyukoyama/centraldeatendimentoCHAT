require 'json_schemer'

class OpenjarvisContractSchemaValidator
  def initialize(path: Rails.root.join('docs/integrations/openjarvis-openapi/schemas.yaml'))
    @schemas = YAML.safe_load(path.read, aliases: true)
  end

  def errors(schema_name, value)
    document = schemas.merge('$ref' => "#/#{schema_name}")
    JSONSchemer.schema(document).validate(value).to_a
  end

  private

  attr_reader :schemas
end
