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
        additional.supported_languages = ['es', 'en', 'ar']
        additional.additional_settings[:portal_languages] = ['es', 'en', 'ar']
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
        log_out
        controller.class.any_instance.stubs(:api_current_user).returns(nil)
        User.stubs(:current).returns(nil)
      end

      def teardown
        super
        controller.class.any_instance.unstub(:api_current_user)
        User.unstub(:current)
      end

      def set_widget
        @widget = HelpWidget.active.first || create_widget
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
          folder_id: create_folder_with_language_reset(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone],
                                                       category_id: category.id,
                                                       lang_codes: ['es', 'en'],
                                                       name: Faker::Name.name).id,
          status: status || 2,
          lang_codes: ['es', 'en']
        }
      end

      def create_articles
        @category = create_category_with_language_reset(lang_codes: ['es', 'en'])
        set_portal_category(@category)
        article_meta = create_article_with_language_reset(article_params(@category))
        @article = @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def get_article_for_main_portal
        article_meta = create_article(article_params(create_category))
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def main_portal_language_id
        Language.find_by_code(@account.main_portal.language).id
      end

      def get_article_without_publish
        category = create_category
        set_portal_category(category)
        article_meta = create_article(article_params(category, 1))
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def set_portal_category(category)
        portal_category = PortalSolutionCategory.new
        portal_category.portal = @portal
        portal_category.solution_category_meta = category
        portal_category.save
      end

      def get_suggested_articles(lang_code = @account.main_portal.language)
        result = []
        meta_item_ids = @account.solution_article_meta.for_portal(@portal).published.order(hits: :desc, thumbs_up: :desc).limit(5).pluck(:id)
        articles = @account.solution_articles.where(parent_id: meta_item_ids, language_id: Language.find_by_code(lang_code).id)
        articles.each do |art|
          result << widget_article_search_pattern(art)
        end
        result
      end

      def test_show_article
        @account.stubs(:multilingual?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article))
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_primary_language
        create_widget(language: 'es')
        set_widget
        create_articles
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      end

      def test_show_article_with_language
        get :show, controller_params(id: @article.parent_id, language: 'es')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('es').id).first
        match_json(widget_article_show_pattern(ar_article))
        result = parse_response(@response.body)
        assert_equal result['title'], 'es Test'
        assert_nil Language.current
      end

      def test_show_article_with_invalid_language
        get :show, controller_params(id: @article.parent_id, language: 'essss')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      end

      def test_show_article_without_language_version
        get :show, controller_params(id: @article.parent_id, language: 'ar')
        assert_response 404
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
        @account.stubs(:multilingual?).returns(false)
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_hit_article_multilingual_enabled
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      end

      def test_thumbs_up_article
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_up_article_multilingual_enabled
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      end

      def test_thumbs_down_article
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_down_article_multilingual_enabled
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      end

      def test_suggested_articles
        @account.stubs(:multilingual?).returns(false)
        get :suggested_articles, controller_params
        assert_response 200
        match_json(get_suggested_articles)
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_es
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles('es'))
        result = parse_response(@response.body)
        assert_equal result.first['title'], 'es Test'
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
        assert_response 200
        match_json(get_suggested_articles)
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
        Account.any_instance.stubs(:all_launched_features).returns([])
        get :show, controller_params(id: @article.parent_id)
        assert_response 403
        Account.any_instance.unstub(:all_launched_features)
        assert_nil Language.current
      end

      def test_show_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article))
        assert_nil Language.current
      end
    end
  end
end
