require_relative '../../../api/api_test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class UsersFlowTest < ActionDispatch::IntegrationTest
  include UsersHelper

  def test_index
    account_wrap do
      get '/users'
    end
    assert_response 302
    assert_redirected_to '/contacts'
  end

  def test_new
    account_wrap do
      get '/users/new'
    end
    assert_response 302
    assert_redirected_to '/contacts/new'
  end

  def test_edit
    user = add_new_user(@account)
    account_wrap do
      get "/users/#{user.id}/edit"
    end
    assert_response 302
    assert_redirected_to "/contacts/#{user.id}/edit"
  end

  def test_create
    user_params = {
      user: {
        name: Faker::Name.name,
        email: Faker::Internet.email,
        active: 1
      }
    }
    account_wrap do
      post '/users', user_params
    end
    assert_response 302
    assert_redirected_to '/users'
    assert_equal user_params[:user][:email], User.last.email
  end

  def test_block_agent
    agent = add_agent(@account)
    account_wrap do
      put "/users/#{agent.id}/block"
    end
    assert_response 200
    refute agent.reload.deleted?
    assert_equal "Following contact(s) (#{agent.name}) have been blocked", flash[:notice]
  end

  def test_block_customer
    user = add_new_user(@account)
    account_wrap do
      put "/users/#{user.id}/block"
    end
    assert_response 200
    assert user.reload.deleted?
    assert_equal "Following contact(s) (#{user.name}) have been blocked", flash[:notice]
  end

  def test_show_agent
    agent = add_agent(@account)
    account_wrap do
      get "/users/#{agent.id}"
    end
    assert_response 302
    assert_redirected_to "/a/contacts/#{agent.id}"
  end

  def test_show_customer
    user = add_new_user(@account)
    account_wrap do
      get "/users/#{user.id}"
    end
    assert_response 302
    assert_redirected_to "/a/contacts/#{user.id}"
  end

  def test_profile_image
    file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'image33kb.jpg'))
    user = add_new_user(@account)
    user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
    user.save
    account_wrap do
      get "/users/#{user.id}/profile_image"
    end
    assert_response 302
    assert_include response.location, user.avatar.content_file_name
  end

  def test_profile_image_no_blank_no_image
    user = add_new_user(@account)
    account_wrap do
      get "/users/#{user.id}/profile_image_no_blank"
    end
    assert_response 200
    assert_equal 'noimage', response.body
  end

  def test_profile_image_no_blank_avatar_present
    user = add_new_user(@account)
    file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'image33kb.jpg'))
    user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
    user.save
    account_wrap do
      get "/users/#{user.id}/profile_image_no_blank"
    end
    assert_response 302
    assert_include response.location, user.avatar.content_file_name
  end

  def test_profile_image_no_blank_with_user_social
    user = add_new_user_with_fb_id(@account)
    account_wrap do
      get "/users/#{user.id}/profile_image_no_blank"
    end
    assert_response 302
    assert_equal response.location, user.facebook_avatar(user.fb_profile_id)
  end

  def test_delete_avatar
    file = fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'image33kb.jpg'))
    user = add_new_user(@account)
    user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
    user.save
    account_wrap do
      delete "/users/#{user.id}/delete_avatar"
    end
    assert_response 200
    assert_nil user.reload.avatar
  end

  def test_assume_identity_allowed_for_user
    user = add_new_user(@account)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/'
    assert_equal User.current.id, session['original_user']
    assert_equal user.id, session['assumed_user']
  end

  def test_assume_identity_with_user_deleted
    user = add_new_user(@account, deleted: 1)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 404
  end

  def test_assume_identity_with_user_having_admin_privilege
    user = add_new_user(@account)
    User.any_instance.stubs(:privilege?).returns(true)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    refute_equal user.id, session['assumed_user']
    assert_equal 'You are not allowed to assume this user.', flash[:notice]
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_assume_identity_with_user_having_secure_fields_privilege
    user = add_new_user(@account)
    User.any_instance.stubs(:privilege?).returns(true)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    refute_equal user.id, session['assumed_user']
    assert_equal 'You are not allowed to assume this user.', flash[:notice]
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_assume_identity_with_same_user
    account_wrap do
      get "/users/#{@agent.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    refute_equal User.current.id, session['assumed_user']
    assert_equal 'You are not allowed to assume this user.', flash[:notice]
  end

  def test_assume_identity_without_assume_identity_feature
    user = add_new_user(@account)
    Account.any_instance.stubs(:assume_identity_enabled?).returns(false)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    refute_equal user.id, session['assumed_user']
    assert_equal 'You are not allowed to assume this user.', flash[:notice]
  ensure
    Account.any_instance.unstub(:assume_identity_enabled?)
  end

  def test_assume_identity_with_euc_hide_agent_metrics_enabled
    user = add_new_user(@account)
    Account.any_instance.stubs(:euc_hide_agent_metrics_enabled?).returns(true)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
    end
    assert_response 302
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    Account.any_instance.unstub(:euc_hide_agent_metrics_enabled?)
  end

  def test_assumable_agents
    Agent.any_instance.stubs(:can_assume?).returns(true)
    add_agent(@account)
    account_wrap do
      get '/users/assumable_agents'
    end
    assert_response 406
  ensure
    Agent.any_instance.unstub(:can_assume?)
  end

  def test_revert_identity
    user = add_new_user(@account)
    account_wrap do
      get "/users/#{user.id}/assume_identity"
      get '/users/revert_identity'
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    assert 'You have reverted your identity back to you.', flash[:notice]
  end

  def test_revert_identity_with_original_user_absent
    controller.session[:original_user] = nil
    account_wrap do
      get '/users/revert_identity'
    end
    assert_response 302
    assert_redirected_to "http://#{@account.full_domain}/"
    assert "Sorry, we couldn't find your original user.", flash[:error]
  end

  def test_enable_falcon
    Account.any_instance.stubs(:falcon_ui_enabled?).returns(true)
    account_wrap do
      post '/enable_falcon', {}, 'HTTP_REFERER' => 'http://foo.com'
    end
    assert_response 302
    assert 'true', response.cookies['falcon_enabled']
  ensure
    Account.any_instance.unstub(:falcon_ui_enabled?)
  end

  def test_enable_falcon_for_all_has_access_to_enable_falcon
    account_wrap do
      post '/enable_falcon_for_all'
    end
    assert_response 403
  end

  def test_disable_old_helpdesk
    account_wrap do
      post '/disable_old_helpdesk'
    end
    assert_response 204
    assert Account.current.disable_old_ui_enabled?
  end

  def test_accept_gdpr_compliance
    user = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    account_wrap do
      put '/users/accept_gdpr_compliance'
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    assert_equal false, user.reload.preferences[:agent_preferences][:gdpr_acceptance]
  end

  def test_enable_undo_send
    user = add_new_user(@account, active: true)
    user.toggle_undo_send(false)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:undo_send_enabled?).returns(true)
    account_wrap do
      post '/enable_undo_send'
    end
    assert_response 204
    assert user.reload.enabled_undo_send?
  ensure
    Account.any_instance.unstub(:undo_send_enabled?)
  end

  def test_enable_undo_send_with_undo_send_already_enabled
    user = add_new_user(@account, active: true)
    user.toggle_undo_send(true)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:undo_send_enabled?).returns(true)
    account_wrap do
      post '/enable_undo_send'
    end
    assert_response 204
    assert user.reload.enabled_undo_send?
  ensure
    Account.any_instance.unstub(:undo_send_enabled?)
  end

  def test_disable_undo_send
    user = add_new_user(@account, active: true)
    user.toggle_undo_send(true)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:undo_send_enabled?).returns(true)
    user.preferences = { agent_preferences: { undo_send: true } }
    user.save
    account_wrap do
      post '/disable_undo_send'
    end
    assert_response 204
    refute user.reload.enabled_undo_send?
  ensure
    Account.any_instance.unstub(:undo_send_enabled?)
  end

  def test_disable_undo_send_with_undo_send_already_disabled
    user = add_new_user(@account, active: true)
    user.toggle_undo_send(false)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:undo_send_enabled?).returns(true)
    account_wrap do
      post '/disable_undo_send'
    end
    assert_response 204
    refute user.reload.enabled_undo_send?
  ensure
    Account.any_instance.unstub(:undo_send_enabled?)
  end

  def test_change_focus_mode_to_false
    user = add_agent(@account, active: true)
    set_request_auth_headers(user)
    account_wrap do
      post '/change_focus_mode', value: '0'
    end
    assert_response 204
    refute user.agent.reload.focus_mode
  end

  def test_change_focus_mode_to_true
    user = add_agent(@account, active: true)
    set_request_auth_headers(user)
    account_wrap do
      post '/change_focus_mode', value: '1'
    end
    assert_response 204
    assert user.agent.reload.focus_mode
  end

  def test_change_focus_mode_with_non_boolean_value
    user = add_agent(@account, active: true)
    set_request_auth_headers(user)
    account_wrap do
      post '/change_focus_mode', value: 'a'
    end
    assert_response 204
    refute user.agent.reload.focus_mode
  end

  def test_set_conversation_preference
    user = add_agent(@account, active: true)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:reverse_notes_enabled?).returns(true)
    account_wrap do
      put '/set_notes_order', oldest_on_top: true
    end
    assert_response 204
    assert user.reload.old_notes_first?
  ensure
    Account.any_instance.unstub(:reverse_notes_enabled?)
  end

  def test_set_conversation_preference_with_reverse_notes_not_enabled
    Account.any_instance.stubs(:reverse_notes_enabled?).returns(false)
    account_wrap do
      put '/set_notes_order', oldest_on_top: true
    end
    assert_response 401
  ensure
    Account.any_instance.unstub(:reverse_notes_enabled?)
  end

  def test_set_conversation_preference_with_user_as_customer
    user = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    User.any_instance.stubs(:customer?).returns(true)
    account_wrap do
      put '/set_notes_order', oldest_on_top: true
    end
    assert_response 401
  ensure
    User.any_instance.unstub(:customer?)
  end

  private

    def old_ui?
      true
    end
end
