require_relative '../../test_helper'
class Ember::ScenarioAutomationsControllerTest < ActionController::TestCase
  include ScenarioAutomationsTestHelper

  def wrap_cname(params)
    { scenario_automation: params }
  end

  def test_index
    10.times do
      create_scn_automation_rule(scenario_automation_params)
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(private_api_index_pattern)
  end
end
