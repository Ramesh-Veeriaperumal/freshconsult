require_relative '../../../test_helper'
class Ember::Admin::FreddySkillsControllerTest < ActionController::TestCase
  include FreddySkillsHelper

  def test_list_valid_features
    stub_features do
      get :index, controller_params(version: 'private')
      match_json(index_json)
    end
  end

  def test_show_valid_feature
    stub_features do
      get :show, controller_params(version: 'private', name: 'ticket_properties_suggester')
      match_json(show_json)
    end
  end

  def test_show_invalid_feature
    stub_features do
      get :show, controller_params(version: 'private', name: 'invalid_feature')
      assert_response 404
    end
  end

  def test_show_ineligible_feature
    stub_features do
      get :show, controller_params(version: 'private', name: 'detect_thank_you_note')
      assert_response 404
    end
  end

  def test_enable_valid_feature
    stub_features do
      Account.current.revoke_feature(:ticket_properties_suggester)
      put :update, construct_params({ version: 'private', name: 'ticket_properties_suggester' }, enabled: true)
      match_json(show_json(enabled: true))
    end
  end

  def test_disable_valid_feature
    stub_features do
      put :update, construct_params({ version: 'private', name: 'ticket_properties_suggester' }, enabled: false)
      match_json(show_json(enabled: false))
    end
  end

  def test_enable_ineligible_feature
    stub_features do
      put :update, construct_params({ version: 'private', name: 'detect_thank_you_note' }, enabled: true)
      assert_response 404
    end
  end

  def test_enable_invalid_feature
    stub_features do
      put :update, construct_params({ version: 'private', name: 'invalid_feature' }, enabled: true)
      assert_response 404
    end
  end

  def wrap_cname(params)
    { freddy_skill: params }
  end
end
