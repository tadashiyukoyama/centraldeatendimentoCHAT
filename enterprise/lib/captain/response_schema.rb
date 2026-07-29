# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema
class Captain::ResponseSchema < RubyLLM::Schema
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze
  string :response, description: 'The complete, final message to send to the user without runtime additions or rewrites'
  string :reasoning, description: "Agent's thought process"
  string :classification,
         enum: CLASSIFICATIONS,
         description: 'The required business classification for the latest customer message'
end
