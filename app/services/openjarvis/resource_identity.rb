class Openjarvis::ResourceIdentity
  def initialize(resource, sequence: nil)
    @resource = resource
    @sequence = sequence
  end

  def as_json
    {
      type: resource.class.base_class.name,
      id: public_id,
      internal_id: resource.id,
      version: version,
      sequence: sequence.to_i
    }
  end

  def version
    "#{resource.updated_at.utc.iso8601(6)}:#{resource.id}"
  end

  private

  attr_reader :resource, :sequence

  def public_id
    resource.is_a?(Conversation) ? resource.display_id : resource.id
  end
end
