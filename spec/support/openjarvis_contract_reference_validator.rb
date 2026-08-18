class OpenjarvisContractReferenceValidator
  def initialize(allowed_root:)
    @allowed_root = allowed_root
  end

  def validate!(node, base_dir)
    validate_reference!(node['$ref'], base_dir) if node.is_a?(Hash) && node['$ref']&.start_with?('.')
    children(node).each { |child| validate!(child, base_dir) }
  end

  private

  attr_reader :allowed_root

  def children(node)
    return node.values if node.is_a?(Hash)
    return node if node.is_a?(Array)

    []
  end

  def validate_reference!(reference, base_dir)
    file_name, pointer = reference.split('#', 2)
    target = base_dir.join(file_name).cleanpath
    raise "Reference escapes integration docs: #{reference}" unless target.to_s.start_with?(allowed_root.to_s)
    raise "Missing OpenAPI reference: #{target}" unless target.exist?

    resolved = resolve_pointer(load_yaml(target), pointer)
    validate!(resolved, target.dirname)
  end

  def resolve_pointer(document, pointer)
    pointer.to_s.delete_prefix('/').split('/').reject(&:blank?).reduce(document) do |value, segment|
      value.fetch(segment.gsub('~1', '/').gsub('~0', '~'))
    end
  end

  def load_yaml(path)
    YAML.safe_load(path.read, aliases: true)
  end
end
