# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :text
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
class Captain::Assistant < ApplicationRecord
  DESCRIPTION_LENGTH_LIMIT = 500
  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new.freeze

  include Avatarable
  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :documents, class_name: 'Captain::Document', dependent: :destroy_async
  has_many :responses, class_name: 'Captain::AssistantResponse', dependent: :destroy_async
  has_many :faq_suggestions, class_name: 'Captain::FaqSuggestion', dependent: :destroy_async
  has_many :captain_inboxes,
           class_name: 'CaptainInbox',
           foreign_key: :captain_assistant_id,
           dependent: :destroy_async
  has_many :inboxes,
           through: :captain_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :copilot_threads, dependent: :destroy_async
  has_many :scenarios, class_name: 'Captain::Scenario', dependent: :destroy_async
  has_many :agent_sessions, class_name: 'Captain::AgentSession', dependent: :destroy_async
  has_many :tool_executions, class_name: 'Captain::ToolExecution', dependent: :destroy_async
  has_many :appointments, class_name: 'Captain::Appointment', dependent: :restrict_with_error
  has_many :payment_notices, class_name: 'Captain::PaymentNotice', dependent: :restrict_with_error

  store_accessor :config,
                 :temperature,
                 :feature_faq,
                 :feature_memory,
                 :feature_contact_attributes,
                 :feature_demo_scheduling,
                 :feature_payment_notices,
                 :product_name,
                 :demo_assignee_email

  validates :name, presence: true
  validates :description, presence: true, length: { maximum: DESCRIPTION_LENGTH_LIMIT }
  validates :account_id, presence: true
  validate :validate_text_integrity

  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def available_name
    name
  end

  def available_agent_tools
    tools = self.class.built_in_agent_tools.dup

    custom_tools = account.captain_custom_tools.enabled.map(&:to_tool_metadata)
    tools.concat(custom_tools)

    tools
  end

  def available_tool_ids
    available_agent_tools.pluck(:id)
  end

  def push_event_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  private

  def validate_text_integrity
    values = {
      name: name,
      description: description,
      config: config,
      response_guidelines: response_guidelines,
      guardrails: guardrails
    }
    Captain::TextIntegrity.errors(values).each { |error| errors.add(:base, error) }
  end

  def agent_name
    name.parameterize(separator: '_')
  end

  def agent_tools
    tools = build_tools(%w[faq_lookup classify_lead add_private_note handoff])
    tools.concat(operational_tools)
    tools.concat(account.captain_custom_tools.enabled.map { |custom_tool| custom_tool.tool(self) })
    tools
  end

  def operational_tools
    names = []
    names << 'capture_contact_profile' if feature_enabled?(:feature_contact_attributes)
    names << 'schedule_demo' if feature_enabled?(:feature_demo_scheduling)
    names.push('record_payment_notice', 'lookup_payment_status') if feature_enabled?(:feature_payment_notices)
    build_tools(names)
  end

  def build_tools(names)
    names.map { |tool_name| self.class.resolve_tool_class(tool_name).new(self) }
  end

  def feature_enabled?(feature)
    BOOLEAN_TYPE.cast(config[feature.to_s])
  end

  def prompt_context
    {
      name: name,
      system_name: PublicBrand.value('ASSISTANT_PUBLIC_NAME', 'Captain'),
      description: description,
      product_name: config['product_name'] || 'this product',
      feature_contact_profile: feature_enabled?(:feature_contact_attributes),
      feature_demo_scheduling: feature_enabled?(:feature_demo_scheduling),
      feature_payment_notices: feature_enabled?(:feature_payment_notices),
      scenarios: scenarios.enabled.map do |scenario|
        {
          title: scenario.title,
          key: scenario.handoff_key,
          description: scenario.description
        }
      end,
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def default_avatar_url
    asset_path = PublicBrand.value('ASSISTANT_ASSET_BASE_URL', '/assets/images/dashboard/captain')
    "#{ENV.fetch('FRONTEND_URL', nil)}#{asset_path}/logo.svg"
  end
end
