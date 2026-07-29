# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze
  PROFILE_QUESTION_FIELDS = %w[none name company_name phone_number email].freeze

  string :response, description: 'The message to send to the user'
  string :reasoning, description: "Agent's thought process"
  string :classification,
         enum: CLASSIFICATIONS,
         description: 'The required business classification for the latest customer message'
  string :profile_question_field,
         enum: PROFILE_QUESTION_FIELDS,
         description: 'A missing contact_profile field selected without fixed order, or none when no profile question is appropriate'
  string :profile_question,
         description: 'One short natural question for profile_question_field, or an empty string when no profile question is appropriate'
end
