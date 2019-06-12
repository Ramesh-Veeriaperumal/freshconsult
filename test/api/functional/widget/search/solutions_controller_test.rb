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
        @portal = @account.portals.find_by_product_id(@widget.product_id)
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

        portal_category = PortalSolutionCategory.new
        portal_category.portal = @portal
        portal_category.solution_category_meta = category
        portal_category.save

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
        assert_response 400
        match_json(request_error_pattern(:solution_article_not_enabled, 'solution_article_not_enabled'))
        assert_nil Language.current
      end

      def test_results_without_open_solutions
        Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
        stub_private_search_response([@article]) do
          post :results, construct_params(version: 'widget', term: @article.title, limit: 3)
        end
        assert_response 403
        Account.any_instance.unstub(:features?)
        assert_nil Language.current
      end
    end
  end
end
