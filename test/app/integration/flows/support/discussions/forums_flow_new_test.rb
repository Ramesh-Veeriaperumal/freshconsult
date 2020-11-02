# frozen_string_literal: true

require_relative '../../../../../../test/api/api_test_helper'
['forums_test_helper.rb', 'users_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
class Support::Discussions::ForumsFlowTest < ActionDispatch::IntegrationTest
  include CoreForumsTestHelper
  include CoreUsersTestHelper

  # ------------------ show ------------------------ #

  def test_show_forum_with_forum_access
    @account.add_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    account_wrap do
      get "/support/discussions/forums/#{new_forum.id}"
    end
    assert_response 200
    assert_equal new_forum, assigns[:forum]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(new_forum))
  end

  def test_when_a_particular_forum_is_not_found
    @account.add_feature(:forums)
    forum_id = @account.forums.length + 1
    account_wrap do
      get "/support/discussions/forums/#{forum_id}"
    end
    assert_response 404
  end

  def test_when_a_particular_forum_is_not_visible_to_user
    @account.add_feature(:forums)
    user = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    new_category = create_test_category
    new_forum = create_test_forum(new_category, 1, 4)
    account_wrap do
      get "/support/discussions/forums/#{new_forum.id}"
    end
    assert_response 302
    assert_redirected_to '/support/login'
    assert_equal @request.original_fullpath, session[:return_to]
  end

  def test_show_forum_without_forum_access
    @account.remove_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    account_wrap do
      get "/support/discussions/forums/#{new_forum.id}"
    end
    assert_response 404
  end

  def test_show_forum_with_open_forum_disabled_portal_scope
    @account.add_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    user = add_new_user(Account.current, active: true)
    @account.disable_setting(:open_forums)
    reset_request_headers
    account_wrap(user) do
      get "/support/discussions/forums/#{new_forum.id}"
    end
    assert_response 302
    assert_redirected_to '/login'
  ensure
    @account.enable_setting(:open_forums)
  end

  def test_show_forum_with_hide_portal_forums_enabled_and_current_user_non_agent
    @account.add_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    @account.enable_setting(:hide_portal_forums) unless @account.hide_portal_forums_enabled?
    user = add_new_user(Account.current, active: true)
    set_request_auth_headers(user)
    account_wrap(user) do
      get "/support/discussions/forums/#{new_forum.id}"
    end
    assert_response 302
    assert_redirected_to '/support/home'
  ensure
    @account.disable_setting(:hide_portal_forums)
  end

  # ------------------ toggle_monitor ------------------------ #

  def test_toggle_monitor_with_new_monitorship
    @account.add_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    account_wrap do
      put "/support/discussions/forums/#{new_forum.id}/toggle_monitor"
    end
    assert_response 200
    assert new_forum.monitorships.first.active
  end

  def test_toggle_monitor_with_existing_monitorship
    @account.add_feature(:forums)
    new_category = create_test_category
    new_forum = create_test_forum(new_category)
    current_portal = @account.portals.first
    monitorship = new_forum.monitorships.where(user_id: @account.id).first_or_initialize
    monitorship.portal_id = current_portal.id
    monitorship.save
    account_wrap do
      put "/support/discussions/forums/#{new_forum.id}/toggle_monitor"
    end
    assert_response 200
    assert_equal monitorship, assigns[:monitorship]
    assert_equal current_portal.id, new_forum.monitorships.first.portal_id
    refute new_forum.monitorships.first.active
  end

  private

    def compare_page_meta(forum)
      {
        title: forum.name,
        description: forum.description,
        canonical: "http://#{@account.full_domain}/support/discussions/forums/#{forum.id}",
        image_url: @controller.send(:logo_url, Portal.first)
      }
    end

    def old_ui?
      true
    end
end
