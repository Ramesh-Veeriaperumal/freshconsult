require_relative '../../../test_helper'
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')
require Rails.root.join('spec', 'support', 'company_helper.rb')

module Widget
  module Solutions
    class ArticlesControllerTest < ActionController::TestCase
      include HelpWidgetsTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include AttachmentsTestHelper
      include CompanyHelper

      def setup
        super
        before_all
      end

      def before_all
        main_portal = @account.main_portal
        if main_portal.language.nil?
          main_portal.language = 'en'
          main_portal.save
        end
        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'en', 'ar']
        additional.additional_settings[:portal_languages] = ['es', 'en', 'ar']
        additional.save
        @account.features.enable_multilingual.create
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @account.launch :help_widget
        set_widget
        @article = create_articles
        log_out
        controller.class.any_instance.stubs(:api_current_user).returns(nil)
        User.stubs(:current).returns(nil)
      end

      def teardown
        @widget.destroy
        super
        controller.class.any_instance.unstub(:api_current_user)
        User.unstub(:current)
      end

      def set_widget
        @widget = create_widget
        @widget.settings[:components][:solution_articles] = true
        @widget.save
        @request.env['HTTP_X_WIDGET_ID'] = @widget.id
        @client_id = UUIDTools::UUID.timestamp_create.hexdigest
        @request.env['HTTP_X_CLIENT_ID'] = @client_id
      end

      def article_params(category, status = nil, visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        {
          title: 'Test',
          description: 'Test',
          folder_id: create_folder_with_language_reset(visibility: visibility,
                                                       category_id: category.id,
                                                       lang_codes: ['es', 'en'],
                                                       name: Faker::Name.name).id,
          status: status || 2,
          lang_codes: ['es', 'en']
        }
      end

      def create_articles(visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], user = nil)
        @category = create_category_with_language_reset(lang_codes: ['es', 'en'])
        set_category
        params = article_params(@category, 2, visibility)
        article_meta = create_article_with_language_reset(params)
        if visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
          folder_meta = @account.solution_folder_meta.find(params[:folder_id])
          folder_meta.customer_folders.create(customer_id: user.company_id)
        end
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
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
        set_category
        article_meta = create_article(article_params(category, 1))
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def set_category
        help_widget_category = HelpWidgetSolutionCategory.new
        help_widget_category.help_widget = @widget
        help_widget_category.solution_category_meta = @category
        help_widget_category.save
      end

      def solution_category_meta_ids(user = nil)
        @account.solution_article_meta
                .for_help_widget(@widget, user)
                .published.order(hits: :desc).limit(5).pluck(:id)
      end

      def get_suggested_articles(lang_code: @account.main_portal.language, user: nil)
        result = []
        meta_item_ids = solution_category_meta_ids(user)
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
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_help_widget_login
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.rollback :help_widget_login
      end

      def test_show_article_with_x_widget_auth_user_present
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
        User.stubs(:current).returns(nil)
      end

      def test_show_article_with_x_widget_auth_user_absent
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'pdfgdfftom@freshworks.com', timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :show, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_show_article_with_wrong_x_widget_auth
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', timestamp: timestamp }, secret_key + 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :show, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_show_article_without_user_login
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        get :show, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        put :show, controller_params(id: @article.parent_id)
        assert_response 200
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_show_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :show, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_show_article_with_primary_language
        create_widget(language: 'es')
        @article = create_articles
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      end

      def test_show_article_with_language
        get :show, controller_params(id: @article.parent_id, language: 'es')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('es').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'es Test'
        assert_nil Language.current
      end

      def test_show_article_with_invalid_language
        get :show, controller_params(id: @article.parent_id, language: 'essss')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article))
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
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
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
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
        @request.env['HTTP_X_WIDGET_ID'] = 10001
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
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_hit_article_with_wrong_x_widget_auth
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', timestamp: timestamp }, secret_key + 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :hit, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.any_instance.unstub(:agent?)
      end

      def test_hit_article_with_solution_article_disabled
        HelpWidget.any_instance.stubs(:solution_articles_enabled?).returns(false)
        put :hit, controller_params(id: @article.parent_id)
        assert_response 400
      ensure
        HelpWidget.any_instance.unstub(:solution_articles_enabled?)
      end

      def test_hit_article_without_user_visibility
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :hit, controller_params(id: @article.parent_id)
        assert_response 404
      end

      def test_hit_article_with_user_visibility
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:multilingual?).returns(false)
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_hit_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_hit_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :hit, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_hit_article_by_agent
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:solutions_agent_metrics_enabled?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        @article.reload
        assert_equal @article.hits, 0
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.stubs(:current).returns(nil)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_hit_article_by_agent_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        timestamp = Time.zone.now.utc.iso8601
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.stubs(:current).returns(nil)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_hit_article_multilingual_enabled
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      end

      def test_thumbs_up_article
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_up_article_with_wrong_x_widget_token
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_up
        User.unstub(:current)
        @account.launch :help_widget_login
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key + 'ds')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_user
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_user_being_agent
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_nil article_vote
        assert_equal @article.thumbs_up, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        agent = add_agent(@account, role: Role.find_by_name('Agent').id)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: agent.name, email: agent.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: agent.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.unstub(:current)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_same_user_many_times
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        article_vote = @article.votes.build(vote: 1, user_id: user.id)
        @article.thumbs_up!
        article_vote.save
        @article.reload
        old_thumbs_up_count = @article.thumbs_up
        old_count = article_vote.vote
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_equal @article.thumbs_up, old_thumbs_up_count
        assert_present article_vote
        assert_equal article_vote.vote, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_logged_in_user_visibility
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_up_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_up_article_multilingual_enabled
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      end

      def test_thumbs_down_article
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_down_article_with_wrong_x_widget_token
        @account.stubs(:multilingual?).returns(false)
        old_count = @article.thumbs_up
        User.unstub(:current)
        @account.launch :help_widget_login
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key + 'ds')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_user
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 0
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_user_being_agent
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_nil article_vote
        assert_equal @article.thumbs_down, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 0
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.unstub(:current)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_same_user_many_times
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        vote_record = @article.votes.build(vote: 0, user_id: user.id)
        @article.thumbs_down!
        vote_record.save
        @article.reload
        old_count = vote_record.vote
        old_thumbs_down = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_equal @article.thumbs_down, old_thumbs_down
        assert_present article_vote
        assert_equal article_vote.vote, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_logged_in_user_visibility
        @account.stubs(:multilingual?).returns(false)
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_down_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        @article.reload
        article_vote = @account.votes.where(voteable_id: @article.id, user_id: user.id).first
        assert_equal @article.thumbs_down, old_count + 1
        assert_equal article_vote.vote, 0
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.launch :help_widget_login
        timestamp = Time.zone.now.utc.iso8601
        User.any_instance.stubs(:agent?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        User.unstub(:agent?)
        @account.unstub(:help_widget_secret)
        @account.rollback :help_widget_login
      end

      def test_thumbs_down_article_multilingual_enabled
        @account.launch(:help_widget_solution_categories)
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      end

      def test_suggested_articles
        @account.stubs(:multilingual?).returns(false)
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_es
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es'))
        result = parse_response(@response.body)
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        assert_equal result.first['title'], 'es Test'
        assert_nil Language.current
      end

      def test_suggested_articles_with_login
        User.unstub(:current)
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        user = add_new_user(@account)
        @widget.help_widget_solution_categories.destroy_all
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es', user: user))
        result = parse_response(@response.body)
        result = parse_response(@response.body)
        logged_user_response = result.find { |x| x['id'] == @article.parent_id }
        assert_not_nil logged_user_response
        assert_equal User.current.id, user.id
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.stubs(:current).returns(nil)
      end

      def test_suggested_articles_with_company_user_login
        User.unstub(:current)
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        @widget.help_widget_solution_categories.destroy_all
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es', user: user))
        result = parse_response(@response.body)
        company_response = result.find { |x| x['id'] == @article.parent_id }
        assert_not_nil company_response
        assert_equal User.current.id, user.id
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.stubs(:current).returns(nil)
      end

      def test_suggested_articles_with_invalid_company_user_login
        User.unstub(:current)
        @account.launch :help_widget_login
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        @widget.help_widget_solution_categories.destroy_all
        @article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        customer1 = create_company
        user1 = add_new_user(@account, customer_id: customer1.id)
        timestamp = Time.zone.now.utc.iso8601
        auth_token = JWT.encode({ name: user1.name, email: user1.email, timestamp: timestamp }, secret_key)
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es', user: user1))
        result = parse_response(@response.body)
        company_response = result.find { |x| x['id'] == @article.parent_id }
        assert_nil company_response
        assert_equal User.current.id, user1.id
      ensure
        @account.rollback :help_widget_login
        @account.unstub(:help_widget_secret)
        User.stubs(:current).returns(nil)
      end

      def test_suggested_articles_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      end

      def test_show_without_help_widget_launch
        @account.rollback(:help_widget)
        get :show, controller_params(id: @article.parent_id)
        assert_response 403
        @account.launch(:help_widget)
        assert_nil Language.current
      end

      def test_show_without_help_widget_feature
        @account.remove_feature(:help_widget)
        get :show, controller_params(id: @article.parent_id)
        assert_response 403
        @account.add_feature(:help_widget)
        assert_nil Language.current
      end

      def test_show_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        solution_category_meta_id = solution_folder_meta.solution_category_meta_id
        help_widget_category_meta_ids = @widget.help_widget_solution_categories.pluck(:solution_category_meta_id)
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(widget_article_show_pattern(@article))
        assert_nil Language.current
      end
    end
  end
end
