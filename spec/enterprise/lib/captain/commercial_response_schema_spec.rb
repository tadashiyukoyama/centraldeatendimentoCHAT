require 'rails_helper'

RSpec.describe Captain::CommercialResponseSchema do
  it 'serializes every field required by the commercial Agent SDK contract' do
    schema = described_class.new.to_json_schema.fetch(:schema)

    expect(schema.fetch(:properties).keys).to contain_exactly(
      :response,
      :reasoning,
      :classification,
      :customer_intent,
      :commercial_stage,
      :immediate_objective,
      :captured_profile_fields,
      :requested_profile_fields,
      :declined_profile_fields,
      :knowledge_grounded
    )
    expect(schema.fetch(:required)).to match_array(schema.fetch(:properties).keys)
  end
end
