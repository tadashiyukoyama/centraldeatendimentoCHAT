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

    label = account_scoped(Label).find_by(title: classification)
    return "Label '#{classification}' not found" unless label

    conversation.update_labels((conversation.label_list - CLASSIFICATIONS) + [classification])
    log_tool_usage('classified_lead', conversation_id: conversation.id, classification: classification)

    "Conversation ##{conversation.display_id} classified as '#{classification}'"
  end
end
