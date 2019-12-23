require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')

module Widget
  module Search
    class SolutionsControllerTest < ActionController::TestCase
      include SolutionsHelper
      include SolutionBuilderHelper
      include SearchTestHelper
      include HelpWidgetsTestHelper
      include UsersHelper

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
        @article = create_article_for_widget
      end

      def teardown
        @widget.destroy
        super
      end

      def set_widget
        @widget = create_widget
        @widget.settings[:components][:solution_articles] = true
        @widget.save
        @request.env['HTTP_X_WIDGET_ID'] = @widget.id
        @client_id = UUIDTools::UUID.timestamp_create.hexdigest
        @request.env['HTTP_X_CLIENT_ID'] = @client_id
      end

      def article_params(category, visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        {
          title: 'Widget Search Test',
          description: 'Widget Search Test',
          folder_id: create_folder(visibility: visibility, category_id: category.id).id
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

      def create_article_category
        category = create_category
        help_widget_category = HelpWidgetSolutionCategory.new
        help_widget_category.help_widget = @widget
        help_widget_category.solution_category_meta = category
        help_widget_category.save
        category
      end

      def create_article_for_widget(visibility = nil, user = nil)
        article_param = article_params(create_article_category, visibility)
        if visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
          folder_meta = @account.solution_folder_meta.find(article_param[:folder_id])
          folder_meta.customer_folders.create(customer_id: user.customer_id)
        end
        create_article(article_param).primary_article
      end

      def test_results
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_with_login
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        logged_user_article = create_article_for_widget(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        stub_private_search_response([logged_user_article]) do
          post :results, construct_params(version: 'widget', term: logged_user_article.title)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(logged_user_article)].to_json, response.body
        assert_nil Language.current
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
      ensure
        user.destroy
      end

      def test_results_with_login_company_user
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        company_user_article = create_article_for_widget(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        stub_private_search_response([company_user_article]) do
          post :results, construct_params(version: 'widget', term: company_user_article.title)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(company_user_article)].to_json, response.body
        assert_nil Language.current
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
      end

      def test_results_help_widget_login
        @account.launch :help_widget_login
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title)
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
          post :results, construct_params(version: 'widget', term: @article.title)
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
          post :results, construct_params(version: 'widget', term: @article.title)
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
          post :results, construct_params(version: 'widget', term: @article.title)
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
          post :results, construct_params(version: 'widget', term: @article.title)
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
          post :results, construct_params(version: 'widget', term: 'no results')
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
          post :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 400
        assert_nil Language.current
      end

      def test_results_with_invalid_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = 10001
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 400
      end

      def test_results_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_include help_widget_category_meta_ids, solution_category_meta_id
        assert_nil Language.current
      end

      # Tests for GET API
      def test_results_get
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_with_login_get
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        logged_user_article = create_article_for_widget(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        stub_private_search_response([logged_user_article]) do
          get :results, construct_params(version: 'widget', term: logged_user_article.title)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(logged_user_article)].to_json, response.body
        assert_nil Language.current
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
      ensure
        user.destroy
      end

      def test_results_with_login_company_user_get
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        company_user_article = create_article_for_widget(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        stub_private_search_response([company_user_article]) do
          get :results, construct_params(version: 'widget', term: company_user_article.title)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(company_user_article)].to_json, response.body
        assert_nil Language.current
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
      end

      def test_results_help_widget_login_get
        @account.launch :help_widget_login
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
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

      def test_results_with_x_widget_auth_user_present_get
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
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

      def test_results_with_x_widget_auth_user_absent_get
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praajifflongbottom@freshworks.com', timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 404
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_results_with_wrong_x_widget_auth_get
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praajingbottom@freshworks.com', timestamp: timestamp }, secret_key + 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 401
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_results_widget_authentication_get
        @account.launch :help_widget_login
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_with_invalid_term_get
        stub_private_search_response([]) do
          get :results, construct_params(version: 'widget', term: 'no results')
        end
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [].to_json, response.body
        assert_nil Language.current
      end

      def test_results_without_widget_id_get
        @request.env['HTTP_X_WIDGET_ID'] = nil
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 400
        assert_nil Language.current
      end

      def test_results_with_invalid_widget_id_get
        @request.env['HTTP_X_WIDGET_ID'] = 10001
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_response 400
      end

      def test_results_with_solution_disabled_get
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title)
        end
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_include help_widget_category_meta_ids, solution_category_meta_id
        assert_nil Language.current
      end

      def test_results_with_page_and_per_page_get
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title, page: 1, per_page: 5)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_invalid_page_get
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title, page: 11)
        end
        assert_response 400
        match_json([bad_request_error_pattern('page', :limit_invalid, max_value: Widget::Search::SolutionConstants::MAX_PAGE)])
      end

      def test_invalid_per_page_get
        stub_private_search_response([@article]) do
          get :results, construct_params(version: 'widget', term: @article.title, per_page: 31)
        end
        assert_response 400
        match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: Widget::Search::SolutionConstants::MAX_PER_PAGE)])
      end
    end
  end
end
