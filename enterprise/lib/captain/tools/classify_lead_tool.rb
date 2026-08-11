class Captain::Tools::ClassifyLeadTool < Captain::Tools::BasePublicTool
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze

  description 'Classify a conversation as customer, warm lead, or hot lead'
  param :classification,
        type: 'string',
        desc: 'One of: cliente, lead_morno, lead_quente'

  def perform(tool_context, classification:)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    classification = classification.to_s.strip.downcase
    return "Invalid classification. Use one of: #{CLASSIFICATIONS.join(', ')}" unless CLASSIFICATIONS.include?(classification)

    with_tool_audit(
      tool_context,
      request_summary: { classification: classification }
    ) do
      effective_classification = Captain::Conversation::LeadClassificationService.new(conversation: conversation).perform(
        classification: classification
      )
      log_tool_usage(
        'classified_lead',
        conversation_id: conversation.id,
        requested_classification: classification,
        effective_classification: effective_classification
      )

      "Conversation ##{conversation.display_id} classified as '#{effective_classification}'"
    end
  end
end
