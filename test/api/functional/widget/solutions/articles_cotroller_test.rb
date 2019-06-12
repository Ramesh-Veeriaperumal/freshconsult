require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')

module Widget
  module Solutions
    class ArticlesControllerTest < ActionController::TestCase
      include HelpWidgetsTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include AttachmentsTestHelper

      def setup
        super
        before_all
        set_widget
      end

      def before_all
        additional = @account.account_additional_settings
        additional.supported_languages = ['es']
        additional.save
        @account.features.enable_multilingual.create
        @account.add_feature(:open_solutions)
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @account.launch :help_widget
        set_widget
        create_articles
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

      def article_params(category, status = nil)
        {
          title: 'Test',
          description: 'Test',
          folder_id: create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id).id,
          status: status || 2
        }
      end

      def create_articles
        @category = create_category
        set_portal_category(@category)
        @article = create_article(article_params(@category)).current_article
      end

      def get_article_for_main_portal
        create_article(article_params(create_category)).current_article
      end

      def get_article_without_publish
        category = create_category
        set_portal_category(category)
        create_article(article_params(category, 1)).current_article
      end

      def set_portal_category(category)
        portal_category = PortalSolutionCategory.new
        portal_category.portal = @portal
        portal_category.solution_category_meta = category
        portal_category.save
      end

      def get_suggested_articles
        result = []
        meta_item_ids = @account.solution_article_meta.for_portal(@portal).published.order(hits: :desc, thumbs_up: :desc).limit(5).pluck(:id)
        articles = @account.solution_articles.where(parent_id: meta_item_ids, language_id: Language.find_by_code('en').id)
        articles.each do |art|
          result << widget_article_search_pattern(art)
        end
        result
      end

      def test_show_article
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article))
        assert_nil Language.current
      end

      def test_show_article_with_attachments
        attachments = create_attachment
        att_article = create_article(article_params(@category)).current_article
        att_article.attachments = [attachments]
        att_article.save
        get :show, controller_params(id: att_article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(att_article))
        assert_nil Language.current
      end

      def test_show_article_without_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = nil
        get :show, controller_params(id: @article.parent_id)
        assert_response 400
        assert_nil Language.current
      end

      def test_show_article_with_wrong_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = 100
        get :show, controller_params(id: @article.parent_id)
        assert_response 400
        assert_nil Language.current
      end

      def test_show_article_without_portal
        get :show, controller_params(id: get_article_for_main_portal.parent_id)
        assert_response 404
      end

      def test_show_article_without_publish
        get :show, controller_params(id: get_article_without_publish.parent_id)
        assert_response 404
      end

      def test_hit_article
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert @article.hits == 1
        assert_nil Language.current
      end

      def test_thumbs_up_article
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert @article.thumbs_up == old_count + 1
        assert_nil Language.current
      end

      def test_thumbs_down_article
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert @article.thumbs_down == old_count + 1
        assert_nil Language.current
      end

      def test_suggested_articles
        get :suggested_articles, controller_params
        assert_response 200
        match_json(get_suggested_articles)
        assert_nil Language.current
      end

      def test_suggested_articles_without_open_solutions
        Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
        get :suggested_articles, controller_params
        assert_response 403
        Account.any_instance.unstub(:features?)
        assert_nil Language.current
      end

      def test_suggested_articles_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :suggested_articles, controller_params
        assert_response 400
        match_json(request_error_pattern(:solution_article_not_enabled, 'solution_article_not_enabled'))
        assert_nil Language.current
      end

      def test_show_without_open_solutions
        Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 403
        Account.any_instance.unstub(:features?)
        assert_nil Language.current
      end

      def test_show_without_feature
        Account.any_instance.stubs(:help_widget_enabled?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 403
        Account.any_instance.unstub(:help_widget_enabled?)
        assert_nil Language.current
      end

      def test_show_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :show, controller_params(id: @article.parent_id)
        assert_response 400
        match_json(request_error_pattern(:solution_article_not_enabled, 'solution_article_not_enabled'))
        assert_nil Language.current
      end
    end
  end
end
