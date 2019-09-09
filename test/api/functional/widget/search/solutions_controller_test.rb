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
        @account.add_feature(:open_solutions)
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

        if @account.help_widget_solution_categories_enabled?
          help_widget_category = HelpWidgetSolutionCategory.new
          help_widget_category.help_widget = @widget
          help_widget_category.solution_category_meta = category
          help_widget_category.save
        else
          portal = @account.portals.find_by_product_id(@widget.product_id)
          portal_category = PortalSolutionCategory.new
          portal_category.portal = portal
          portal_category.solution_category_meta = category
          portal_category.save
        end

        @article = create_article(article_params(category)).primary_article
      end

      def test_results
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_with_invalid_term
        stub_private_search_response([]) do
          post :results, construct_params(version: 'widget', term: 'no results', limit: 3)
        end
        assert_response 200
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
        assert_response 200
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        assert_nil Language.current
      end

      def test_results_without_open_solutions
        @account.remove_feature(:open_solutions)
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.add_feature(:open_solutions)
        assert_nil Language.current
      end

      def test_results_without_help_widget_launch
        @account.rollback(:help_widget)
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.launch(:help_widget)
        assert_nil Language.current
      end

      def test_results_without_help_widget_feature
        @account.remove_feature(:help_widget)
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.add_feature(:help_widget)
        assert_nil Language.current
      end

      def test_widget_category_results
        @account.launch(:help_widget_solution_categories)
        create_article_for_widget
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
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_with_invalid_term
        @account.launch(:help_widget_solution_categories)
        create_article_for_widget
        stub_private_search_response([]) do
          post :results, construct_params(version: 'widget', term: 'no results', limit: 3)
        end
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_equal [].to_json, response.body
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_without_widget_id
        @account.launch(:help_widget_solution_categories)
        create_article_for_widget
        @request.env['HTTP_X_WIDGET_ID'] = nil
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 400
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_with_invalid_widget_id
        @account.launch(:help_widget_solution_categories)
        create_article_for_widget
        @request.env['HTTP_X_WIDGET_ID'] = 100
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 400
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_with_solution_disabled
        @account.launch(:help_widget_solution_categories)
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        create_article_for_widget
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 200
        assert_equal [widget_article_search_pattern(@article)].to_json, response.body
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, ALL_USER_VISIBILITY
        assert_include help_widget_category_meta_ids, solution_category_meta_id
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_without_open_solutions
        @account.launch(:help_widget_solution_categories)
        @account.remove_feature(:open_solutions)
        create_article_for_widget
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.add_feature(:open_solutions)
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_without_help_widget_launch
        @account.launch(:help_widget_solution_categories)
        @account.rollback(:help_widget)
        create_article_for_widget
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.launch(:help_widget)
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end

      def test_widget_category_results_without_help_widget_feature
        @account.launch(:help_widget_solution_categories)
        @account.remove_feature(:help_widget)
        create_article_for_widget
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        @account.add_feature(:help_widget)
        assert_nil Language.current
      ensure
        @account.rollback(:help_widget_solution_categories)
      end
    end
  end
end
