['automations_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module ScenarioAutomationsTestHelper
  include AutomationsHelper

  def scenario_automation_params
    { 
      :account_id => @account.id,
      :accessible_attributes => {
        :access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_ids => [@agent.id]
      }
    }
  end

  def private_api_index_pattern
    pattern_array = Account.current.scn_automations.map do |scenario|
      {
        id: scenario.id,
        name: scenario.name,
        description: scenario.description,
        actions: scenario.action_data.map { |action| action.slice(:name, :value) },
        private: scenario.visible_to_only_me?
      }
    end
  end
end