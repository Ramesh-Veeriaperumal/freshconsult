require_relative '../test_helper'
['scenario_automations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class ScenarioAutomationModelTest < ActiveSupport::TestCase
  include ScenarioAutomationsTestHelper

  def test_scenario_automation_invalid_addnote
    action_value = {
      action_data: [
        { name: 'add_comment', comment: '{{ticket.id added for test' }
      ]
    }
    scenario = create_scn_automation_rule_with_validation(scenario_automation_params.merge(action_value))
    assert_equal scenario.errors.messages, action_add_note: ["Variable '{{' was not properly terminated with regexp: /\\}\\}/ "]
  end

  private

    def create_scn_automation_rule_with_validation(params = {})
      va_rule = FactoryGirl.build(:scn_automation,
                                  name: "created by #{Faker::Name.name}",
                                  description: Faker::Lorem.sentence(2),
                                  action_data: params[:action_data],
                                  account_id: params[:account_id],
                                  rule_type: VAConfig::SCENARIO_AUTOMATION)
      va_rule[:action_data][0] = va_rule[:action_data][0].stringify_keys
      accessible = va_rule.create_accessible(access_type: params[:accessible_attributes][:access_type])
      va_rule.save
      va_rule
    end
end
