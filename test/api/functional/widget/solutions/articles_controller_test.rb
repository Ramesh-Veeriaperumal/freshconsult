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
        @article.try(:destroy)
        @widget.try(:destroy)
        super
        controller.class.any_instance.unstub(:api_current_user)
        User.unstub(:current)
        unset_login_support
      end

      def set_widget(options = {})
        @widget = create_widget(options)
        @widget.settings[:components][:solution_articles] = true
        @widget.save
        @request.env['HTTP_X_WIDGET_ID'] = @widget.id
        @client_id = UUIDTools::UUID.timestamp_create.hexdigest
        @request.env['HTTP_X_CLIENT_ID'] = @client_id
      end

      def article_params(category: @category, status: nil, title: 'Test',
                         visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
        {
          title: title,
          description: title,
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
        params = article_params(status: 2, visibility: visibility)
        article_meta = create_article_with_language_reset(params)
        if visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
          folder_meta = @account.solution_folder_meta.find(params[:folder_id])
          folder_meta.customer_folders.create(customer_id: user.company_id)
        end
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def create_article_for_suggested_article
        @category = create_category_with_language_reset(lang_codes: ['es', 'en'])
        set_category
        5.times do |value|
          value += 1
          params = article_params(status: 2, title: "Hit #{100 * value}")
          article = create_article_with_language_reset(params).current_article
          new_article = Solution::ArticleMeta.find_by_id(article.parent_id)
          new_article.hits = 100 * value
          article.hits = new_article.hits
          article.save!
          new_article.save!
        end
      end

      def get_article_for_main_portal
        article_meta = create_article(article_params(category: create_category))
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def main_portal_language_id
        Language.find_by_code(@account.main_portal.language).id
      end

      def get_article_without_publish
        @category = create_category
        set_category
        article_meta = create_article(article_params(category: @category, status: 1))
        @account.solution_articles.where(parent_id: article_meta.id, language_id: main_portal_language_id).first
      end

      def set_category
        @help_widget_category = HelpWidgetSolutionCategory.new
        @help_widget_category.help_widget = @widget
        @help_widget_category.solution_category_meta = @category
        @help_widget_category.save
      end

      def portal
        if @widget.product_id
          Account.current.portals.where(product_id: @widget_product_id).first
        else
          Account.current.main_portal_from_cache
        end
      end

      def create_portal_association
        portal_solution_category = portal.portal_solution_categories.new
        portal_solution_category.solution_category_meta_id = @help_widget_category.solution_category_meta_id
        portal_solution_category.save
      end

      def remove_portal_assoication
        portal.portal_solution_categories.destroy
      end

      def relavant_article(user = nil, ids = nil)
        relavant_article = @account.solution_article_meta
                                   .for_help_widget(@widget, user)
                                   .published
        ids.present? ? relavant_article.where(id: ids) : relavant_article.order('solution_article_meta.hits desc').limit(5)
      end

      def get_suggested_articles(lang_code: @account.main_portal.language, user: nil, meta_item_ids: nil, order: false)
        result = []
        current_lang = Language.current
        Language.find_by_code(lang_code).make_current
        articles = relavant_article(user, meta_item_ids)
        articles = articles.where(id: meta_item_ids) if meta_item_ids.present?
        articles.sort_by { |e| meta_item_ids.index(e.id) } if order && meta_item_ids.present?
        articles.each do |art|
          result << widget_article_search_pattern(art.current_article)
        end
        current_lang.nil? ? Language.reset_current : current_lang.make_current
        result
      end

      def test_show_article
        @account.stubs(:multilingual?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_product_portal_association
        @account.stubs(:multilingual?).returns(false)
        create_portal_association
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        remove_portal_assoication
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_main_portal_association
        @account.stubs(:multilingual?).returns(false)
        set_widget(product_id: nil)
        set_category
        create_portal_association
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        remove_portal_assoication
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_product_without_portal
        @account.stubs(:multilingual?).returns(false)
        Account.current.products.find_by_id(@widget.product_id).portal.destroy
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_help_widget_login
        @account.stubs(:multilingual?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_user_login_expired
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc - 4.hours).to_i }, secret_key + 'opo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @account.stubs(:multilingual?).returns(false)
        get :show, controller_params(id: @article.parent_id)
        assert_response 401
        match_json('description' => 'Validation failed',
                   'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
      end

      def test_show_article_with_x_widget_auth_user_present
        User.unstub(:current)
        @account.stubs(:multilingual?).returns(false)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        get :show, controller_params(id: @article.parent_id)
        assert_response 200
        match_json(widget_article_show_pattern(@article, @widget))
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
      end

      def test_show_article_with_x_widget_auth_user_absent
        @account.stubs(:multilingual?).returns(false)
        set_user_login_headers(name: 'Padmashri', email: 'pdfgdfftom@freshworks.com')
        get :show, controller_params(id: @article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
      end

      def test_show_article_with_wrong_x_widget_auth
        @account.stubs(:multilingual?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc + 15.minutes).to_i }, 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :show, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:help_widget_secret)
      end

      def test_show_article_without_user_login
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        get :show, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        solution_article.destroy
      end

      def test_show_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        put :show, controller_params(id: solution_article.parent_id)
        assert_response 200
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_show_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :show, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_show_article_with_primary_language
        widget = create_widget(language: 'es')
        solution_article = create_articles
        get :show, controller_params(id: solution_article.parent_id)
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: solution_article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = solution_article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'en Test'
        assert_nil Language.current
      ensure
        widget.destroy
        solution_article.destroy
      end

      def test_show_article_with_language
        get :show, controller_params(id: @article.parent_id, language: 'es')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('es').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        result = parse_response(@response.body)
        assert_equal result['title'], 'es Test'
        assert_nil Language.current
      end

      def test_show_article_with_invalid_language
        get :show, controller_params(id: @article.parent_id, language: 'essss')
        assert_response 200
        ar_article = @account.solution_articles.where(parent_id: @article.parent_id, language_id: Language.find_by_code('en').id).first
        match_json(widget_article_show_pattern(ar_article, @widget))
        solution_folder_meta = @article.parent.solution_folder_meta
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
        att_article = create_article(article_params).current_article
        att_article.attachments = [attachments]
        att_article.save
        get :show, controller_params(id: att_article.parent_id)
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(widget_article_show_pattern(att_article, @widget))
        assert_nil Language.current
      ensure
        attachments.destroy
        att_article.destroy
      end

      def test_show_article_without_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = nil
        get :show, controller_params(id: @article.parent_id)
        assert_response 400
        assert_nil Language.current
      end

      def test_show_article_with_wrong_widget_id
        @request.env['HTTP_X_WIDGET_ID'] = 10_001
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.hits, 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_hit_article_with_user_login_expired
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc - 4.hours).to_i }, secret_key + 'opo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @account.stubs(:multilingual?).returns(false)
        put :hit, controller_params(id: @article.parent_id)
        assert_response 401
        match_json('description' => 'Validation failed',
                   'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
      end

      def test_hit_article_with_wrong_x_widget_auth
        @account.stubs(:multilingual?).returns(false)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc + 1.hour).to_i }, secret_key + 'oyo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        get :hit, controller_params(id: @article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
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
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        solution_article.destroy
      end

      def test_hit_article_with_user_visibility
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        @account.stubs(:multilingual?).returns(false)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_folder_meta = solution_article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        solution_article.reload
        assert_equal solution_article.hits, 1
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_hit_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        assert_equal solution_article.hits, 1
        assert_nil Language.current
        assert_equal User.current.id, user.id
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        company.destroy
        solution_article.destroy
      end

      def test_hit_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        company_user.destroy
        company.destroy
        solution_article.destroy
      end

      def test_hit_article_by_agent
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.stubs(:solutions_agent_metrics_enabled?).returns(false)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        set_user_login_headers(name: user.name, email: user.email)
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_folder_meta = solution_article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        solution_article.reload
        assert_equal solution_article.hits, 0
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_hit_article_by_agent_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        put :hit, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_folder_meta = solution_article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
        solution_article.reload
        assert_equal solution_article.hits, 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_hit_article_multilingual_enabled
        put :hit, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_thumbs_up_articlet_with_user_login_expired
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc - 4.hours).to_i }, secret_key + 'opo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @account.stubs(:multilingual?).returns(false)
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 401
        match_json('description' => 'Validation failed',
                   'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
      end

      def test_thumbs_up_article_with_wrong_x_widget_token
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, exp: (Time.now.utc + 1.hour).to_i }, secret_key + 'ds')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        @account.unstub(:help_widget_secret)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_user
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        old_count = solution_article.thumbs_up
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal solution_article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_user_being_agent
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        set_user_login_headers(name: user.name, email: user.email)
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_nil article_vote
        assert_equal solution_article.thumbs_up, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        agent = add_agent(@account, role: Role.find_by_name('Agent').id)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        set_user_login_headers(name: agent.name, email: agent.email)
        old_count = solution_article.thumbs_up
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: agent.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal solution_article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.unstub(:current)
        agent.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_same_user_many_times
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        article_vote = solution_article.votes.build(vote: 1, user_id: user.id)
        solution_article.thumbs_up!
        article_vote.save
        solution_article.reload
        old_thumbs_up_count = solution_article.thumbs_up
        old_count = article_vote.vote
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_equal solution_article.thumbs_up, old_thumbs_up_count
        assert_present article_vote
        assert_equal article_vote.vote, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_logged_in_user_visibility
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        solution_article.destroy
      end

      def test_thumbs_up_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        old_count = solution_article.thumbs_up
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 1
        assert_equal solution_article.thumbs_up, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        company.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :thumbs_up, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        company_user.destroy
        company.destroy
        solution_article.destroy
      end

      def test_thumbs_up_article_multilingual_enabled
        old_count = @article.thumbs_up
        put :thumbs_up, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        @article.reload
        assert_equal @article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_create_attachment_with_user_login_expired
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        auth_token = JWT.encode({ name: 'Padmashri', email: 'praaji.longbottom@freshworks.com', exp: (Time.now.utc - 4.hours).to_i }, secret_key + 'opo')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        @account.stubs(:multilingual?).returns(false)
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 401
        match_json('description' => 'Validation failed',
                   'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
      end

      def test_thumbs_down_article_with_wrong_x_widget_token
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        secret_key = SecureRandom.hex
        @account.stubs(:help_widget_secret).returns(secret_key)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        auth_token = JWT.encode({ name: user.name, email: user.email, exp: (Time.now.utc + 1.hour).to_i }, secret_key + 'ds')
        @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 401
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        @account.unstub(:help_widget_secret)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_down_article_with_user
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        old_count = solution_article.thumbs_down
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 0
        assert_equal solution_article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_down_article_with_user_being_agent
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        set_user_login_headers(name: user.name, email: user.email)
        old_count = solution_article.thumbs_down
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_nil article_vote
        assert_equal solution_article.thumbs_down, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_down_article_with_solutions_agent_metrics_enabled
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        @account.stubs(:solutions_agent_metrics_enabled?).returns(true)
        user = add_agent(@account, role: Role.find_by_name('Agent').id)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        old_count = solution_article.thumbs_down
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_present article_vote
        assert_equal article_vote.vote, 0
        assert_equal solution_article.thumbs_down, old_count + 1
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        @account.unstub(:solutions_agent_metrics_enabled?)
        User.unstub(:current)
        solution_article.destroy
      end

      def test_thumbs_down_article_with_same_user_many_times
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        User.unstub(:current)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        vote_record = solution_article.votes.build(vote: 0, user_id: user.id)
        solution_article.thumbs_down!
        vote_record.save
        solution_article.reload
        old_count = vote_record.vote
        old_thumbs_down = solution_article.thumbs_down
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 204
        solution_article.reload
        article_vote = @account.votes.where(voteable_id: solution_article.id, user_id: user.id).first
        assert_equal solution_article.thumbs_down, old_thumbs_down
        assert_present article_vote
        assert_equal article_vote.vote, old_count
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_thumbs_down_article_with_logged_in_user_visibility
        @account.stubs(:multilingual?).returns(false)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        solution_article.destroy
      end

      def test_thumbs_down_article_with_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        user = add_new_user(@account, customer_id: company.id)
        set_user_login_headers(name: user.name, email: user.email)
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
        user.destroy
        company.destroy
      end

      def test_thumbs_down_article_with_invalid_company_user_visibility
        @account.stubs(:multilingual?).returns(false)
        User.unstub(:current)
        company = create_company
        company_user = add_new_user(@account, customer_id: company.id)
        user = add_new_user(@account)
        set_user_login_headers(name: user.name, email: user.email)
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], company_user)
        put :thumbs_down, controller_params(id: solution_article.parent_id)
        assert_response 404
      ensure
        @account.unstub(:multilingual?)
        User.stubs(:current).returns(nil)
        company_user.destroy
        user.destroy
        company.destroy
        solution_article.destroy
      end

      def test_thumbs_down_article_multilingual_enabled
        old_count = @article.thumbs_down
        put :thumbs_down, controller_params(id: @article.parent_id)
        assert_response 204
        solution_folder_meta = @article.parent.solution_folder_meta
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      ensure
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_with_suggested_article_rules
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        create_articles
        id = suggested_article_ids.first
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [id]))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'testrefundmoney'
        get :suggested_articles, controller_params
        assert_response 200
        article_meta_ids = @widget.help_widget_suggested_article_rules.first.filter[:value]
        match_json(get_suggested_articles(meta_item_ids: article_meta_ids))
        assert_nil Language.current
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_with_invalid_article_meta
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        article_meta_id = @account.solution_article_meta.last.id + 200
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [article_meta_id]))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'testrefundmoney'
        get :suggested_articles, controller_params
        assert_response 200
        match_json([])
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_without_category_association
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        @controller.stubs(:rule_based_articles).returns([])
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [1, 2]))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'testrefundmoney'
        get :suggested_articles, controller_params
        assert_response 200
        match_json([])
      ensure
        @controller.unstub(:rule_based_articles)
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_with_no_rule_match
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        id = suggested_article_ids.first
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [id]))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'nomatch'
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_with_evaluates_on_invalid
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        id = suggested_article_ids.first
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [id], evaluate_on: 2))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'nomatch'
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_with_filter_value_empty
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        @account.stubs(:multilingual?).returns(false)
        param = suggested_article_rule
        param[:filter][:value] = []
        create_widget_suggested_article_rules(param)
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'test'
        get :suggested_articles, controller_params
        assert_response 200
        match_json([])
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
        @account.unstub(:multilingual?)
      end

      def test_suggested_articles_without_feature
        @account.stubs(:multilingual?).returns(false)
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        assert_equal result.first['title'], 'es Test'
        assert_nil Language.current
      end

      def test_suggested_articles_es_with_rules
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        id = suggested_article_ids.first
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: [id]))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'testrefundmoney'
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        article_meta_ids = @widget.help_widget_suggested_article_rules.first.filter[:value]
        match_json(get_suggested_articles(lang_code: 'es', meta_item_ids: article_meta_ids))
        result = parse_response(@response.body)
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        assert_equal result.first['title'], 'es Test'
        assert_nil Language.current
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
      end

      def test_suggested_articles_order_with_rules
        @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
        create_article_for_suggested_article
        ids = suggested_article_ids.sort { |a, b| b <=> a }
        create_widget_suggested_article_rules(suggested_article_rule(filter_value: ids))
        @request.env['HTTP_X_WIDGET_REFERRER'] = 'testrefundmoney'
        get :suggested_articles, controller_params(language: 'en')
        assert_response 200
        article_meta_ids = @widget.help_widget_suggested_article_rules.first.filter[:value]
        match_json(get_suggested_articles(meta_item_ids: article_meta_ids, order: true))
        assert_nil Language.current
      ensure
        @account.unstub(:help_widget_article_customisation_enabled?)
      end

      def test_suggested_articles_order
        create_article_for_suggested_article
        get :suggested_articles, controller_params(language: 'en')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'en'))
        result = parse_response(@response.body)
        assert_equal result.first['title'], 'en Hit 500'
        assert_equal result.last['title'], 'en Hit 100'
        assert_nil Language.current
      end

      def test_suggested_articles_with_login
        User.unstub(:current)
        user = add_new_user(@account)
        @widget.help_widget_solution_categories.destroy_all
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:logged_users])
        set_user_login_headers(name: user.name, email: user.email)
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es', user: user))
        result = parse_response(@response.body)
        result = parse_response(@response.body)
        logged_user_response = result.find { |x| x['id'] == solution_article.parent_id }
        assert_not_nil logged_user_response
        assert_equal User.current.id, user.id
      ensure
        User.stubs(:current).returns(nil)
        user.destroy
        solution_article.destroy
      end

      def test_suggested_articles_with_company_user_login
        User.unstub(:current)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        set_user_login_headers(name: user.name, email: user.email)
        @widget.help_widget_solution_categories.destroy_all
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json(get_suggested_articles(lang_code: 'es', user: user))
        result = parse_response(@response.body)
        company_response = result.find { |x| x['id'] == solution_article.parent_id }
        assert_not_nil company_response
        assert_equal User.current.id, user.id
      ensure
        user.destroy
        customer.destroy
        User.stubs(:current).returns(nil)
        solution_article.destroy
      end

      def test_suggested_articles_with_invalid_company_user_login
        User.unstub(:current)
        customer = create_company
        user = add_new_user(@account, customer_id: customer.id)
        @widget.help_widget_solution_categories.destroy_all
        solution_article = create_articles(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users], user)
        customer1 = create_company
        user1 = add_new_user(@account, customer_id: customer1.id)
        set_user_login_headers(name: user1.name, email: user1.email)
        get :suggested_articles, controller_params(language: 'es')
        assert_response 200
        match_json([])
      ensure
        User.stubs(:current).returns(nil)
        user.destroy
        user1.destroy
        customer1.destroy
        customer.destroy
        solution_article.destroy
      end

      def test_suggested_articles_with_solution_disabled
        @widget.settings[:components][:solution_articles] = false
        @widget.save
        get :suggested_articles, controller_params
        assert_response 200
        solution_folder_meta = @article.parent.solution_folder_meta
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(get_suggested_articles)
        assert_nil Language.current
      end

      def test_show_without_help_widget_feature
        @account.revoke_feature(:help_widget)
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
        assert_equal solution_folder_meta.visibility, Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone]
        match_json(widget_article_show_pattern(@article, @widget))
        assert_nil Language.current
      end
    end
  end
end
