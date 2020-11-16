# frozen_string_literal: true

require_relative '../../../../../../test/api/api_test_helper'
['solutions_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class Support::Solutions::ArticlesControllerFlowTest < ActionDispatch::IntegrationTest
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper

  # ------------------------- show --------------------------------- #

  def test_show_with_json_success_with_draft_preview_false
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}", format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_show_with_json_success_with_draft_preview_true
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview", format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_show_with_json_success_with_active_attachments
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    cloud_file = article.cloud_files.build(url: 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0', application_id: 20, filename: 'Getting Started.pdf')
    cloud_file.save
    create_draft(article: article)
    article.draft.meta[:deleted_attachments] ||= {}
    deleted_cloud_file = article.draft.meta[:deleted_attachments].key?(:cloud_files) ? article.draft.meta[:deleted_attachments][:cloud_files] : []
    deleted_cloud_file << article.cloud_files.first.id
    article.draft.meta[:deleted_attachments][:cloud_files] = deleted_cloud_file
    article.draft.save
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview", format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
    assert assigns[:article][:current_cloud_files].blank?, 'Expected current_cloud_files to be blank'
  end

  def test_show_success_in_html_format_with_draft_preview_false
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_show_success_in_html_format_with_draft_preview_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_show_success_in_html_format_with_active_attachments
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    cloud_file = article.cloud_files.build(url: 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0', application_id: 20, filename: 'Getting Started.pdf')
    cloud_file.save
    create_draft(article: article)
    article.draft.meta[:deleted_attachments] ||= {}
    deleted_cloud_file = article.draft.meta[:deleted_attachments].key?(:cloud_files) ? article.draft.meta[:deleted_attachments][:cloud_files] : []
    deleted_cloud_file << article.cloud_files.first.id
    article.draft.meta[:deleted_attachments][:cloud_files] = deleted_cloud_file
    article.draft.save
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
    assert assigns[:article][:current_cloud_files].blank?, 'Expected current_cloud_files to be blank'
  end

  def test_show_with_no_parent
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    article.solution_folder_meta.solution_category_meta.delete
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  end

  def test_show_with_no_solution_article_meta
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    article.solution_article_meta.delete
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  end

  def test_show_with_multilingual_false
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:multilingual?).returns(false)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_show_with_article_not_visible
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
    old_visibility = article.solution_folder_meta.visibility
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: 3)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_equal I18n.t(:'flash.general.access_denied'), flash[:warning]
    assert_redirected_to '/support/solutions'
  ensure
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: old_visibility)
    User.any_instance.unstub(:privilege?)
  end

  def test_show_with_article_not_visible_and_not_logged_in
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    old_visibility = article.solution_folder_meta.visibility
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: 2)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
    assert_equal request.original_fullpath, session[:return_to]
  ensure
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: old_visibility)
  end

  def test_show_redirect_to_support_for_facebook_portal
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}", portal_type: 'facebook'
    end
    assert_response 302
    assert_template nil
    assert_redirected_to "/support/solutions/articles/#{article.id}"
  end

  def test_show_draft_preview_login_filter
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
    assert_equal request.original_fullpath, session[:return_to]
  end

  def test_show_without_current_user_and_multilingual_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    Account.any_instance.stubs(:multilingual?).returns(true)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_home_path
    assert flash[:warning].include?('This article is not available in English')
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_show_with_portal_multilingual_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Portal.any_instance.stubs(:multilingual?).returns(true)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to "/#{@account.language}/support/solutions/articles/#{article.id}"
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  def test_show_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_show_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_show_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_show_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_show_preview_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_show_preview_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_show_preview_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_show_preview_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/preview"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    Account.any_instance.unstub(:features?)
  end

  # ------------------------- support_show --------------------------------- #

  def test_support_show_with_json_success_with_draft_preview_false
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_support_show_with_json_success_with_draft_preview_true
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview', format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_support_show_with_json_success_with_active_attachments
    @folder = setup_articles
    article = Account.current.solution_articles.find(@folder.solution_articles.first)
    cloud_file = article.cloud_files.build(url: 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0', application_id: 20, filename: 'Getting Started.pdf')
    cloud_file.save
    create_draft(article: article)
    article.draft.meta[:deleted_attachments] ||= {}
    deleted_cloud_file = article.draft.meta[:deleted_attachments].key?(:cloud_files) ? article.draft.meta[:deleted_attachments][:cloud_files] : []
    deleted_cloud_file << article.cloud_files.first.id
    article.draft.meta[:deleted_attachments][:cloud_files] = deleted_cloud_file
    article.draft.save
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview', format: 'json'
    end
    assert_response 200
    assert_template nil
    match_json(article_response_body(article))
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
    assert assigns[:article][:current_cloud_files].blank?, 'Expected current_cloud_files to be blank'
  end

  def test_support_show_success_in_html_format_with_draft_preview_false
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_support_show_success_in_html_format_with_draft_preview_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, true, false, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  end

  def test_support_show_success_in_html_format_with_active_attachments
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    cloud_file = article.cloud_files.build(url: 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0', application_id: 20, filename: 'Getting Started.pdf')
    cloud_file.save
    create_draft(article: article)
    article.draft.meta[:deleted_attachments] ||= {}
    deleted_cloud_file = article.draft.meta[:deleted_attachments].key?(:cloud_files) ? article.draft.meta[:deleted_attachments][:cloud_files] : []
    deleted_cloud_file << article.cloud_files.first.id
    article.draft.meta[:deleted_attachments][:cloud_files] = deleted_cloud_file
    article.draft.save
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, true, false, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
    assert assigns[:article][:current_cloud_files].blank?, 'Expected current_cloud_files to be blank'
  end

  def test_support_show_with_no_parent
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    article.solution_folder_meta.solution_category_meta.delete
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  end

  def test_support_show_with_no_solution_article_meta
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    article.solution_article_meta.delete
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  end

  def test_support_show_with_multilingual_false
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:multilingual?).returns(false)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_support_show_with_article_not_visible
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
    old_visibility = article.solution_folder_meta.visibility
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: 3)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_equal I18n.t(:'flash.general.access_denied'), flash[:warning]
    assert_redirected_to '/support/solutions'
  ensure
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: old_visibility)
    User.any_instance.unstub(:privilege?)
  end

  def test_support_show_with_article_not_visible_and_not_logged_in
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    old_visibility = article.solution_folder_meta.visibility
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: 2)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
    assert_equal request.original_fullpath, session[:return_to]
  ensure
    Account.current.solution_folder_meta.update(article.solution_folder_meta.id, visibility: old_visibility)
  end

  def test_support_show_redirect_to_support_for_facebook_portal
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", portal_type: 'facebook'
    end
    assert_response 302
    assert_template nil
    assert_redirected_to "/support/solutions/articles/#{article.id}"
  end

  def test_support_show_draft_preview_login_filter
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
    assert_equal request.original_fullpath, session[:return_to]
  end

  def test_support_show_without_current_user_and_multilingual_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    Account.any_instance.stubs(:multilingual?).returns(true)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_home_path
    assert flash[:warning].include?('This article is not available in English')
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_support_show_with_portal_multilingual_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Portal.any_instance.stubs(:multilingual?).returns(true)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to "/#{@account.language}/support/articles/#{article.id}"
  ensure
    Portal.any_instance.unstub(:multilingual?)
  end

  def test_support_show_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_support_show_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_support_show_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_support_show_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}"
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, false, true, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_support_show_preview_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_support_show_preview_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, true, false, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_support_show_preview_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_login_path
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_support_show_preview_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/articles/#{article.id}", status: 'preview'
    end
    assert_response 200
    assert_template :show
    assert_equal article.solution_article_meta, assigns[:article]
    assert_equal article.solution_article_meta, assigns[:solution_item]
    assert_equal article.id, assigns[:current_object][:current_object_id]
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(article, true, false, true))
    assigns[:agent_actions].to_json.must_match_json_expression(compare_agent_actions(article))
  ensure
    Account.any_instance.unstub(:features?)
  end

  # ------------------------- hit --------------------------------- #

  def test_hit_without_current_user
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 404
    assert_template nil
  end

  def test_hit_without_current_portal
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Portal.stubs(:current).returns(false)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal @account.main_portal, assigns[:portal]
    assert_equal article, assigns[:article].current_article
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Portal.unstub(:current)
  end

  def test_hit_with_solutions_agent_metrics_disabled
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal article, assigns[:article].current_article
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  end

  def test_hit_with_solutions_agent_metrics_enabled
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal article, assigns[:article].current_article
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled)
  end

  def test_hit_with_solutions_agent_metrics_disabled_and_agent_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    User.any_instance.stubs(:agent?).returns(true)
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(false)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled)
    User.any_instance.unstub(:agent?)
  end

  def test_hit_without_current_user_and_draft_preview_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit", status: 'preview'
    end
    assert_response 404
    assert_template nil
  end

  def test_hit_with_multilingual_true_and_current_is_primary_true
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:multilingual?).returns(true)
    User.any_instance.stubs(:agent?).returns(false)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:multilingual?)
    User.any_instance.unstub(:agent?)
  end

  def test_hit_multilingual_true_and_current_is_primary_false
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:multilingual?).returns(true)
    User.any_instance.stubs(:agent?).returns(false)
    Language.any_instance.stubs(:present?).returns(false)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to support_home_path
    assert flash[:warning].include?('This article is not available in English')
  ensure
    Account.any_instance.unstub(:multilingual?)
    User.any_instance.unstub(:agent?)
    Language.any_instance.unstub(:present?)
  end

  def test_hit_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 404
    assert_template nil
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_hit_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_hit_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 404
    assert_template nil
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_hit_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      get "/support/solutions/articles/#{article.id}/hit"
    end
    assert_response 200
    assert_template nil
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:features?)
  end

  # ------------------------- create_ticket --------------------------------- #

  def test_create_ticket_without_current_user
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
  end

  def test_create_ticket_success
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 200
    assert_template nil
    assert_equal "Article Feedback - #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).subject
    assert_equal "Feedback for:  #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).description
    assert_equal article.id, Account.current.tickets.find_by_id(assigns[:ticket].id).article_ticket.article_id
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
  end

  def test_create_ticket_failure
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    ticket_params = { helpdesk_ticket: { email: @agent.email } }
    Account.current.tickets.any_instance.stubs(:save_ticket).returns(false)
    Account.current.tickets.any_instance.stubs(:present?).returns(false)
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket", ticket_params
    end
    assert_response 200
    assert_template :feedback_form
    assert_not_equal I18n.t('solution.articles.article_not_useful'), response.body
  ensure
    Account.current.tickets.any_instance.unstub(:save_ticket)
    Account.current.tickets.any_instance.unstub(:present?)
  end

  def test_create_with_open_solutions_feature_without_login_for_restricted_helpdesk
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    ticket_params = { helpdesk_ticket: { email: 'invalidmail' } }
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket", ticket_params
    end
    assert_response 200
    assert_template nil
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
  ensure
    @account.revoke_feature(:open_solutions)
    Account.any_instance.unstub(:restricted_helpdesk?)
  end

  def test_create_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 200
    assert_template :feedback_form
    assert_not_equal I18n.t('solution.articles.article_not_useful'), response.body
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_create_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 200
    assert_template nil
    assert_equal "Article Feedback - #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).subject
    assert_equal "Feedback for:  #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).description
    assert_equal article.id, Account.current.tickets.find_by_id(assigns[:ticket].id).article_ticket.article_id
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_create_ticket_watcher_enabled
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:add_watcher_enabled?).returns(true)
    description = Faker::Lorem.paragraph
    random_message = rand(1..4)
    ticket_params = { helpdesk_ticket: { email: Faker::Internet.email }, helpdesk_ticket_description: description, message: [random_message] }
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket", ticket_params
    end
    assert_response 200
    assert_template nil
    assert_equal "Article Feedback - #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).subject
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? "Feedback for:  #{article.title}"
    assert_equal article.id, Account.current.tickets.find_by_id(assigns[:ticket].id).article_ticket.article_id
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? I18n.t("solution.feedback_message_#{random_message}")
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? description
    assert_equal article.user.id, Account.current.tickets.find_by_id(assigns[:ticket].id).subscriptions.first.user_id
  ensure
    Account.any_instance.unstub(:add_watcher_enabled?)
  end

  def test_create_ticket_watcher_disabled
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Account.any_instance.stubs(:add_watcher_enabled?).returns(false)
    description = Faker::Lorem.paragraph
    random_message = rand(1..4)
    ticket_params = { helpdesk_ticket: { email: @agent.email }, helpdesk_ticket_description: description, message: [random_message] }
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket", ticket_params
    end
    assert_response 200
    assert_template nil
    assert_equal "Article Feedback - #{article.title}", Account.current.tickets.find_by_id(assigns[:ticket].id).subject
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? "Feedback for:  #{article.title}"
    assert_equal article.id, Account.current.tickets.find_by_id(assigns[:ticket].id).article_ticket.article_id
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? I18n.t("solution.feedback_message_#{random_message}")
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).description.include? description
    assert Account.current.tickets.find_by_id(assigns[:ticket].id).subscriptions.blank?, 'Expected ticket to have no subscriptions'
  ensure
    Account.any_instance.unstub(:add_watcher_enabled?)
  end

  def test_create_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
    assert_equal I18n.t(:'flash.general.need_login'), flash[:notice]
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_create_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    account_wrap do
      post "/support/solutions/articles/#{article.id}/create_ticket"
    end
    assert_response 200
    assert_template nil
    assert_equal I18n.t('solution.articles.article_not_useful'), response.body
  ensure
    Account.any_instance.unstub(:features?)
  end

  # ------------------------- thumbs_up --------------------------------- #

  def test_thumbs_up_when_user_has_already_upvoted
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    new_vote = Vote.new(vote: true)
    new_vote.user_id = @agent.id
    old_thumbs_up = article.thumbs_up
    new_vote.save
    article.solution_article_meta.votes << new_vote
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    assert_template nil
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_equal I18n.t('solution.articles.article_useful'), response.body
    assert_equal new_vote, assigns[:vote]
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
  end

  def test_thumbs_up_with_vote_as_new_record
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    assert_template nil
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up + 1
    assert_equal I18n.t('solution.articles.article_useful'), response.body
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
  end

  def test_thumbs_up_without_current_user
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
  end

  def test_thumbs_up_without_current_portal
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Portal.stubs(:current).returns(false)
    old_thumbs_up = article.thumbs_up
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_template nil
    assert_equal @account.main_portal, assigns[:portal]
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Portal.unstub(:current)
  end

  def test_thumbs_up_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    reset_request_headers
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up + 1
    assert_template nil
    assert_equal I18n.t('solution.articles.article_useful'), response.body
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_thumbs_up_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_template nil
    assert_equal I18n.t('solution.articles.article_useful'), response.body
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_thumbs_up_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_thumbs_up_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_up"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_template nil
    assert_equal I18n.t('solution.articles.article_useful'), response.body
  ensure
    Account.any_instance.unstub(:features?)
  end

  # ------------------------- thumbs_down --------------------------------- #

  def test_thumbs_down_when_user_has_already_voted
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    new_vote = Vote.new(vote: true)
    new_vote.user_id = @agent.id
    new_vote.save
    article.solution_article_meta.votes << new_vote
    old_thumbs_up = article.thumbs_up
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    assert_template :_feedback_form
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_equal new_vote, assigns[:vote]
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  end

  def test_thumbs_down_with_vote_as_new_record
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    assert_template :feedback_form
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
  end

  def test_thumbs_down_without_current_user
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
  end

  def test_thumbs_down_without_current_portal
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    Portal.stubs(:current).returns(false)
    old_thumbs_down = article.thumbs_down
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_down, old_thumbs_down
    article.reload
    assert_template :_feedback_form
    assert_equal @account.main_portal, assigns[:portal]
    assert_equal old_thumbs_down, article.thumbs_down
    assert_equal Solution::Constants::INTERACTION_SOURCE[:portal], assigns[:article].current_article.interaction_source_type
    assert_equal @account.main_portal.id, assigns[:article].current_article.interaction_source_id
  ensure
    Portal.unstub(:current)
  end

  def test_thumbs_down_with_open_solutions_feature_without_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    old_thumbs_down = article.thumbs_down
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_down, old_thumbs_down + 1
    assert_template :feedback_form
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_thumbs_down_with_open_solutions_feature_with_login
    @account.add_feature(:open_solutions)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_up = article.thumbs_up
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_up, old_thumbs_up
    assert_template :feedback_form
  ensure
    @account.revoke_feature(:open_solutions)
  end

  def test_thumbs_down_without_open_solutions_feature_without_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    reset_request_headers
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 302
    assert_template nil
    assert_redirected_to '/login'
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_thumbs_down_without_open_solutions_feature_with_login
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    folder = setup_articles
    article = Account.current.solution_articles.find(folder.solution_articles.first)
    old_thumbs_down = article.thumbs_down
    account_wrap do
      put "/support/solutions/articles/#{article.id}/thumbs_down"
    end
    assert_response 200
    article.reload
    assert_equal article.thumbs_down, old_thumbs_down
    assert_template :feedback_form
  ensure
    Account.any_instance.unstub(:features?)
  end

  private

    def setup_articles
      category_meta = create_category
      folder = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
      populate_articles(folder)
      folder
    end

    def compare_page_meta(article, has_preview = true, is_solution = true, append_title = false)
      res_hash = {}
      if has_preview == false
        res_hash.merge!(
          description: article.article_description,
          keywords: article.article_keywords
        )
        if append_title
          if is_solution
            res_hash.merge!(canonical: "http://#{@account.full_domain}/support/solutions/articles/#{article.id}-" + article.title.parameterize)
          else
            res_hash.merge!(canonical: "http://#{@account.full_domain}/support/articles/#{article.id}-" + article.title.parameterize)
          end
        elsif is_solution
          res_hash.merge!(canonical: "https://#{@account.full_domain}/support/solutions/articles/#{article.id}")
        else
          res_hash.merge!(canonical: "https://#{@account.full_domain}/support/articles/#{article.id}")
        end
      end
      res_hash.merge!(
        title: article.name,
        short_description: article.desc_un_html.truncate(250),
        image_url: @controller.send(:logo_url, @account.portals.first),
        author: article.user.name
      )
      if has_preview == true
        if append_title
          if is_solution
            res_hash.merge!(canonical: "https://#{@account.full_domain}/support/solutions/articles/#{article.id}")
          else
            res_hash.merge!(canonical: "https://#{@account.full_domain}/support/articles/#{article.id}")
          end
        elsif is_solution
          res_hash.merge!(canonical: "https://#{@account.full_domain}/support/solutions/articles/#{article.id}/preview")
        else
          res_hash.merge!(canonical: "https://#{@account.full_domain}/support/articles/#{article.id}/preview")
        end
      end
      res_hash
    end

    def compare_agent_actions(article)
      res_hash = {
        url: "/a/solutions/articles/#{article.id}/edit",
        label: I18n.t('portal.preview.edit_article'),
        icon: 'edit'
      }, {
        url: "/a/solutions/articles/#{article.id}",
        label: I18n.t('portal.preview.view_on_helpdesk'),
        icon: 'preview'
      }
    end

    def article_response_body(article)
      {
        article: {
          art_type: 1,
          created_at: String,
          current_child_thumbs_down: article.thumbs_down,
          current_child_thumbs_up: article.thumbs_up,
          desc_un_html: article.desc_un_html.truncate(250),
          description: article.description,
          folder_id: @folder.id,
          hits: article.hits,
          id: article.id,
          modified_at: String,
          modified_by: article.modified_by,
          position: 1,
          seo_data: {},
          status: article.status,
          thumbs_down: article.thumbs_down,
          thumbs_up: article.thumbs_up,
          title: article.title,
          updated_at: String,
          user_id: article.user_id,
          tags: [],
          folder: {
            article_order: @folder.article_order,
            category_id: @folder.category_id,
            created_at: String,
            description: @folder.description,
            id: @folder.id,
            is_default: @folder.is_default,
            name: @folder.name,
            position: @folder.position,
            updated_at: String,
            visibility: @folder.visibility,
            customer_folders: @folder.published_articles
          }
        }
      }
    end

    def old_ui?
      true
    end
end
