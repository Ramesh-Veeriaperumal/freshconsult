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

  def test_agent_article_suggest_feature
    Account.current.add_feature(:agent_articles_suggest_eligible)
    sync_bot_stub = stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
    put :update, construct_params({ version: 'private', name: 'agent_articles_suggest' }, enabled: true)
    match_json(show_json({ enabled: true }, 'agent_articles_suggest'))
    assert Account.current.agent_articles_suggest_enabled?
  ensure
    Account.current.revoke_feature(:agent_articles_suggest_eligible)
    Account.current.revoke_feature(:agent_articles_suggest)
    remove_request_stub(sync_bot_stub)
  end

  def test_detect_thank_you_note_feature_enable
    Account.current.add_feature(:detect_thank_you_note_eligible)
    sync_bot_stub = stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
    put :update, construct_params({ version: 'private', name: 'detect_thank_you_note' }, enabled: true)
    match_json(show_json({ enabled: true }, 'detect_thank_you_note'))
    assert Account.current.detect_thank_you_note_enabled?
  ensure
    Account.current.revoke_feature(:detect_thank_you_note_eligible)
    Account.current.revoke_feature(:detect_thank_you_note)
    remove_request_stub(sync_bot_stub)
  end

  def test_detect_thank_you_note_feature_disable
    Account.current.add_feature(:detect_thank_you_note_eligible)
    sync_bot_stub = stub_request(:put, %r{^#{FreddySkillsConfig[:system42][:onboard_url]}.*?$}).to_return(status: 200)
    put :update, construct_params({ version: 'private', name: 'detect_thank_you_note' }, enabled: false)
    match_json(show_json({ enabled: false }, 'detect_thank_you_note'))
    refute Account.current.detect_thank_you_note_enabled?
  ensure
    Account.current.revoke_feature(:detect_thank_you_note_eligible)
    Account.current.revoke_feature(:detect_thank_you_note)
    remove_request_stub(sync_bot_stub)
  end

  def wrap_cname(params)
    { freddy_skill: params }
  end
end
