# frozen_string_literal: true

require_relative '../../../../../api/api_test_helper'
['solutions_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['solutions_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
require Rails.root.join('test', 'models', 'helpers', 'solutions_test_helper.rb')

class Support::Solutions::FoldersControllerFlowTest < ActionDispatch::IntegrationTest
  include SolutionsHelper
  include CoreSolutionsTestHelper
  include ModelsSolutionsTestHelper

  def test_show_route_with_portal_type_facebook
    term = 'test'
    account_wrap do
      get "/support/solutions/folders/#{term}", portal_type: 'facebook'
    end
    assert_response 302
    assert_redirected_to '/support/solutions/folders/test'
  end

  def test_show_folder
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}" # default response is html
      end
      assert_response 200
      assert_template :show
      assert_equal new_folder, assigns[:folder]
      assert_equal new_category, assigns[:category]
      assert_equal new_folder.name, assigns[:page_title]
      assert_equal 'article_list', assigns[:current_page_token]
      assert_equal false, assigns[:facebook_portal]
      assert_equal 'solutions', assigns[:current_tab]
      assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(new_folder))
      assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(new_category, new_folder))
    end
  end

  def test_show_folder_in_json_format
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}", format: 'json'
      end
      expected_response_body = { folder: folder_response_body(new_folder) }
      assert_response 200
      assert_equal new_folder, assigns[:folder]
      assert_equal new_category, assigns[:category]
      assert_equal new_folder.name, assigns[:page_title]
      match_json(expected_response_body)
    end
  end

  def test_show_folder_in_xml_format
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}", format: 'xml'
      end
      assert_response 200
      expected_response_body = { solution_folder: folder_response_body(new_folder) }
      response_body = Hash.from_xml(response.body).deep_symbolize_keys
      response_body[:solution_folder].except!(:created_at, :updated_at)
      expected_response_body[:solution_folder].except!(:created_at, :updated_at)
      assert_equal new_folder, assigns[:folder]
      assert_equal new_category, assigns[:category]
      assert_equal new_folder.name, assigns[:page_title]
      response_body.to_json.must_match_json_expression(expected_response_body)
    end
  end

  def test_show_defaut_folder
    solution_folders_template do
      new_category = create_category
      new_folder = get_default_folder(new_category)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 404
    end
  end

  def test_show_folder_with_wrong_id
    solution_folders_template do
      new_folder_id = @account.solution_folder_meta.length + 1
      account_wrap do
        get "/support/solutions/folders/#{new_folder_id}"
      end
      assert_response 404
    end
  end

  def test_show_folder_invisible_for_current_user
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents], category_id: new_category.id)
      user = add_new_user(@account, active: true)
      set_request_auth_headers(user)
      account_wrap(user) do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 302
      assert_redirected_to '/support/solutions'
      assert_equal I18n.t(:'flash.general.access_denied'), flash[:warning]
    end
  end

  def test_show_folder_for_non_logged_in_user
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users], category_id: new_category.id)
      reset_request_headers
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 302
      assert_redirected_to '/support/login'
      assert_equal request.original_fullpath, session[:return_to]
    end
  end

  def test_show_folder_with_folder_not_visible_to_current_portal
    solution_folders_template do
      new_portal = create_portal
      new_category = create_category(name: "#{Faker::Lorem.sentence(2)} .ok", description: "#{Faker::Lorem.sentence(3)}ok", is_default: false, portal_ids: [new_portal.id])
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 404
    end
  end

  def test_show_folder_with_multilingual_enabled
    solution_folders_template(true) do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:agents], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 302
      assert_redirected_to "/#{@account.language}/support/solutions/folders/#{new_folder.id}"
    end
  end

  def test_show_folder_with_unscoped_fetch
    solution_folders_template(true) do
      new_portal = create_portal
      new_category = create_category(name: "#{Faker::Lorem.sentence(2)} .ok", description: "#{Faker::Lorem.sentence(3)}ok", is_default: false, portal_ids: [new_portal.id])
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "#{@account.language}/support/solutions/folders/#{new_folder.id}"
      end
      language = Language.find_by_code(@account.main_portal.language)
      flash_message = I18n.t('solution.version_not_available.folder', url: controller.send(:default_url), helpdesk_language: @account.language_object, current_language: language)
      assert_response 302
      assert_redirected_to "/#{@account.language}/support/home"
      assert_equal flash_message, flash[:warning]
    end
  end

  def test_show_folder_with_invalid_folder_and_with_multilingual_enabled
    solution_folders_template(true) do
      new_folder_id = @account.solution_folder_meta.length + 1
      account_wrap do
        get "#{@account.language}/support/solutions/folders/#{new_folder_id}"
      end
      assert_response 404
    end
  end

  def test_show_folder_with_suspended_account
    old_subscription_state = @account.subscription.state
    @account.subscription.state = 'suspended'
    @account.subscription.updated_at = 2.days.ago
    @account.subscription.save
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 302
      assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  ensure
    @account.subscription.state = old_subscription_state
    @account.subscription.save
  end

  def test_show_folder_with_deny_inframe_is_set
    AccountAdditionalSettings.any_instance.stubs(:security).returns(deny_iframe_embedding: true)
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 200
      assert_equal response.headers['X-Frame-Options'], 'SAMEORIGIN'
    end
  ensure
    AccountAdditionalSettings.any_instance.unstub(:security)
  end

  def test_show_folder_without_open_solution_feature_without_logged_in_user
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      reset_request_headers
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 302
      assert_redirected_to '/login'
    end
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_show_folder_with_open_solution_feature_without_logged_in_user
    @account.add_feature(:open_solutions)
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      reset_request_headers
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 200
      assert_template :show
    end
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_show_folder_with_open_solution_feature_with_logged_in_user
    @account.add_feature(:open_solutions)
    solution_folders_template do
      new_category = create_category
      new_folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: new_category.id)
      account_wrap do
        get "/support/solutions/folders/#{new_folder.id}"
      end
      assert_response 200
      assert_template :show
    end
  ensure
    @account.revoke_feature(:open_solutions)
  end

  private

    def solution_folders_template(multilingual_flag = false)
      @account.add_feature(:multi_language) if multilingual_flag
      Account.any_instance.stubs(:multilingual?).returns(multilingual_flag)
      yield
    ensure
      Account.any_instance.unstub(:multilingual?)
      @account.remove_feature(:multi_language) if multilingual_flag
    end

    def get_default_folder(category)
      default_folder = @account.solution_folder_meta.where(is_default: true).first
      return create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id, is_default: true) if default_folder.nil?

      default_folder
    end

    def compare_page_meta(folder)
      {
        title: folder.name,
        description: folder.description,
        canonical: "http://#{@account.full_domain}/support/solutions/folders/#{folder.id}",
        image_url: @controller.send(:logo_url, @account.portals.first)
      }
    end

    def old_ui?
      true
    end

    def folder_response_body(folder)
      {
        article_order: folder.article_order,
        created_at: folder.created_at.to_datetime.try(:utc).try(:iso8601),
        id: folder.id,
        is_default: folder.is_default,
        position: folder.position,
        updated_at: folder.updated_at.to_datetime.try(:utc).try(:iso8601),
        visibility: folder.visibility,
        category_id: folder.category_id,
        description: folder.description,
        name: folder.name,
        published_articles: folder.published_articles
      }
    end

    def compare_agent_actions(category, folder)
      [{
        url: "/a/solutions/categories/#{category.id}/folders/#{folder.id}",
        label: I18n.t('portal.preview.view_on_helpdesk'),
        icon: 'preview'
      }]
    end
end
