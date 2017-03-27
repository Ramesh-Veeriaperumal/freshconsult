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
end