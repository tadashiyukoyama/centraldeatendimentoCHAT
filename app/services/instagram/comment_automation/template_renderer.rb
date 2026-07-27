class Instagram::CommentAutomation::TemplateRenderer
  class InvalidTemplate < StandardError; end

  def self.validate!(source, allowed_variables:)
    new(source, allowed_variables: allowed_variables).render(
      allowed_variables.index_with { |variable| variable }
    )
    true
  end

  def initialize(source, allowed_variables:)
    @source = source.to_s
    @allowed_variables = allowed_variables.map(&:to_s)
  end

  def render(values = nil, max_length: nil, **keyword_values)
    values ||= keyword_values
    context = @allowed_variables.index_with { |key| values[key] || values[key.to_sym] || '' }
    output = template.render!(
      context,
      strict_variables: true,
      strict_filters: true
    ).squish

    return output if max_length.blank? || output.length <= max_length

    "#{output.first(max_length - 1).rstrip}…"
  rescue Liquid::Error => e
    raise InvalidTemplate, "Invalid reply template: #{e.message}"
  end

  private

  def template
    raise InvalidTemplate, 'Reply templates cannot contain control tags' if @source.include?('{%')

    unknown_variables = @source.scan(/\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)/).flatten.uniq - @allowed_variables
    raise InvalidTemplate, "Unsupported template variables: #{unknown_variables.join(', ')}" if unknown_variables.any?

    @template ||= Liquid::Template.parse(@source, error_mode: :strict)
  rescue Liquid::Error => e
    raise InvalidTemplate, "Invalid reply template: #{e.message}"
  end
end
