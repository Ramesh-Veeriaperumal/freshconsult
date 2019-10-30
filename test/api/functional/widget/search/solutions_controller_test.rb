require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')

module Widget
  module Search
    class SolutionsControllerTest < ActionController::TestCase
      include SolutionsHelper
      include SolutionBuilderHelper
      include SearchTestHelper
      include HelpWidgetsTestHelper

      ALL_USER_VISIBILITY = 1

      def setup
        super
        before_all
      end

      def before_all
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @account.launch :help_widget
        set_widget
        create_article_for_widget
      end

      def set_widget
        @widget = HelpWidget.last || create_widget
        @widget.settings[:components][:solution_articles] = true
        @widget.save
        @request.env['HTTP_X_WIDGET_ID'] = @widget.id
        @client_id = UUIDTools::UUID.timestamp_create.hexdigest
        @request.env['HTTP_X_CLIENT_ID'] = @client_id
      end

      def article_params(category)
        {
          title: 'Widget Search Test',
          description: 'Widget Search Test',
          folder_id: create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id).id
        }
      end

      def widget_article_search_pattern(article)
        {
          id: article.parent_id,
          title: article.title,
          modified_at: article.modified_at.try(:utc),
          language_id: article.language_id
        }
      end

      def create_article_for_widget
        category = create_category
        help_widget_category = HelpWidgetSolutionCategory.new
        help_widget_category.help_widget = @widget
        help_widget_category.solution_category_meta = category
        help_widget_category.save
        @article = create_article(article_params(category)).primary_article
      end

      def test_results
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_help_widget_login
        @account.launch :help_widget_login
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      ensure
        @account.rollback :help_widget_login
      end

      def test_results_with_x_widget_auth_user_present
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_results_with_x_widget_auth_user_absent
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praajifflongbottom@freshworks.com', timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 404
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_results_with_wrong_x_widget_auth
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praajingbottom@freshworks.com', timestamp: timestamp }, secret_key + 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 401
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_results_widget_authentication
        @account.launch :help_widget_login
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_with_invalid_term
        stub_private_search_response([]) do
          post :results, construct_params(version: 'widget', term: 'no results', limit: 3)
        end
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [].to_json, response.body
        assert_nil Language.current
      end

      def test_results_without_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = nil
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 400
        assert_nil Language.current
      end

      def test_results_with_invalid_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = 100
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 400
      end

      def test_results_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_include help_widget_category_meta_ids, solution_category_meta_id
        assert_nil Language.current
      end
    end
  end
end
