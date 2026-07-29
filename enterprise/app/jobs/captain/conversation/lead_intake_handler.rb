module Captain::Conversation::LeadIntakeHandler
  private

  def process_lead_intake
    handled = false
    @conversation.with_lock do
      @lead_intake_service = nil
      step = lead_intake_service.next_step
      if step
        process_lead_intake_response(step)
        handled = true
      else
        handled = lead_intake_service.awaiting_answer
      end
    end
    handled
  end

  def process_lead_intake_response(step)
    @response = {
      'response' => step.response,
      'agent_name' => @assistant.name
    }
    message = create_messages
    lead_intake_service.mark_question_asked!(step, message)
    capture_assistant_session(result_message: message, credits_consumed: 0.0)
  end

  def lead_intake_service
    @lead_intake_service ||= Captain::Conversation::LeadIntakeService.new(
      conversation: @conversation,
      assistant: @assistant
    )
  end
end
