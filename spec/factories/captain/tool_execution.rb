FactoryBot.define do
  factory :captain_tool_execution, class: 'Captain::ToolExecution' do
    association :account
    assistant { association(:captain_assistant, account: account) }
    tool_name { 'Captain::Tools::ExampleTool' }
    status { :succeeded }
    started_at { Time.current }
    finished_at { Time.current }
  end
end
