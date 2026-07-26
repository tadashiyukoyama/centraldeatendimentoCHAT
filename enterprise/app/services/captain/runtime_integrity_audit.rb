class Captain::RuntimeIntegrityAudit
  def initialize(scope: Captain::Assistant.all)
    @scope = scope
  end

  def perform
    assistants = @scope.order(:account_id, :id).map { |assistant| audit_assistant(assistant) }
    {
      assistants: assistants,
      errors: assistants.sum { |assistant| assistant[:errors].length }
    }
  end

  private

  def audit_assistant(assistant)
    {
      account_id: assistant.account_id,
      assistant_id: assistant.id,
      assistant_name: assistant.name,
      errors: Captain::TextIntegrity.errors(strings_for(assistant))
    }
  end

  def strings_for(assistant)
    {
      name: assistant.name,
      description: assistant.description,
      config: assistant.config,
      response_guidelines: assistant.response_guidelines,
      guardrails: assistant.guardrails
    }
  end
end
