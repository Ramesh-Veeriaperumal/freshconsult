require_relative '../../test_helper'
['scenario_automations_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class ScenarioAutomationsControllerTest < ActionController::TestCase
  include ScenarioAutomationsTestHelper

  def wrap_cname(params)
    { scenario_automation: params }
  end

  def test_index
    Account.any_instance.stubs(:enabled_features_list).returns([:scenario_automation])
    2.times do
      create_scn_automation_rule(scenario_automation_params)
    end
    get :index, controller_params(version: 'v2')
    assert_response 200
    match_json(private_api_index_pattern)
    Account.any_instance.unstub(:enabled_features_list)
  end
end
