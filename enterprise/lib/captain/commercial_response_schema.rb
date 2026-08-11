class Captain::CommercialResponseSchema < RubyLLM::Schema
  CLASSIFICATIONS = %w[cliente lead_morno lead_quente].freeze
  CUSTOMER_INTENTS = %w[unknown prospect customer].freeze
  COMMERCIAL_STAGES = %w[
    greeting
    discovery
    qualification
    solution_fit
    demo_offer
    scheduling
    support
    handoff
  ].freeze

  string :response, description: 'The complete final customer-facing message, authored by the agent'
  string :reasoning, description: "Agent's private reasoning"
  string :classification,
         enum: CLASSIFICATIONS,
         description: 'Required business classification for the latest customer message'
  string :customer_intent,
         enum: CUSTOMER_INTENTS,
         description: 'Whether the contact is still unknown, a prospect, or an existing customer'
  string :commercial_stage,
         enum: COMMERCIAL_STAGES,
         description: 'The current adaptive conversation stage; this is metadata, not a scripted flow'
  string :immediate_objective,
         description: 'One concise private objective for this turn'
  array :captured_profile_fields,
        description: 'Profile fields persisted by capture_contact_profile during this turn',
        max_items: 4,
        of: :string
  array :requested_profile_fields,
        description: 'Profile fields naturally requested in the final response during this turn',
        max_items: 4,
        of: :string
  array :declined_profile_fields,
        description: 'Profile fields the customer explicitly declined to provide during this turn',
        max_items: 4,
        of: :string
  boolean :knowledge_grounded,
          description: 'True only when factual product claims in the response are grounded by FAQ lookup in this run'
end
